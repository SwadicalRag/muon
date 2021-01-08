
import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:muon/controllers/muonnote.dart";
import "package:muon/controllers/muonproject.dart";
import "package:muon/controllers/muonvoice.dart";
import "package:muon/logic/japanese.dart";
import "package:muon/pianoroll.dart";
import "package:muon/serializable/settings.dart";
import "package:file_selector_platform_interface/file_selector_platform_interface.dart";
import 'package:muon/widgets/dialogs/firsttimesetup.dart';
import 'package:muon/widgets/dialogs/welcome.dart';
import 'package:muon/widgets/overlay/appbar.dart';
import 'package:muon/widgets/overlay/sidebar.dart';
import "package:path/path.dart" as p;

final currentProject = MuonProjectController.defaultProject();

class MuonEditor extends StatefulWidget {
  MuonEditor() : super();

  /// Shows the welcome screen via [showDialog]
  static void showWelcomeScreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext subContext) {
        return MuonWelcomeDialog();
      },
    );
  }

  /// Shows the first time setup screen via [showDialog]
  static void performFirstTimeSetup(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext subContext) {
        return MuonFirstTimeSetupDialog();
      },
    );
  }

  /// Opens a file selector dialog and prompts the user to open
  /// a project.json file
  static Future openProject(BuildContext context) {
    return FileSelectorPlatform.instance.openFile(
      confirmButtonText: "Open Project",
      acceptedTypeGroups: [XTypeGroup(
        label: "Muon Project Files",
        extensions: ["json"],
      )],
    )
    .then((value) {
      if(value != null) {
        final proj = MuonProjectController.loadFromFile(value.path);
        currentProject.updateWith(proj);

        return true;
      }
    })
    .catchError((err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).errorColor,
          content: new Text("internal error: " + err.toString()),
          duration: new Duration(seconds: 10),
        )
      );
    }); // oh wow i am so naughty
  }

  /// Opens a file selector dialog and prompts the user to create
  /// a project.json file
  static Future createNewProject() {
    return FileSelectorPlatform.instance.getSavePath(
      confirmButtonText: "Create Project",
      acceptedTypeGroups: [XTypeGroup(
        label: "Muon Project Files",
        extensions: ["json"],
      )],
      suggestedName: "project",
    )
    .then((value) {
      if(value != null) {
        currentProject.updateWith(MuonProjectController.defaultProject());
        currentProject.projectDir = p.dirname(value);
        currentProject.projectFileName = p.basename(value);
        if(!currentProject.projectFileName.endsWith(".json")) {
          currentProject.projectFileName += ".json";
        }
        currentProject.save();

        return true;
      }
    })
    .catchError((err) {print("internal error: " + err.toString());}); // oh wow i am so naughty
  }

  /// Compiles all voices, and then plays audio from the playhead's
  /// current position
  /// 
  /// Will show snackbars on errors
  /// 
  static Future<void> playAudio(BuildContext context) async {
    if(currentProject.internalStatus != "idle") {return;}

    final playPos = Duration(
      milliseconds: currentProject.getLabelMillisecondOffset() + 
        (
          1000 * 
          (
            currentProject.playheadTime / 
            (currentProject.bpm / 60)
          )
        ).floor()
      );

    List<Future<void>> compileRes = [];
    currentProject.internalStatus = "compiling";
    for(final voice in currentProject.voices) {
      compileRes.add(_compileVoiceInternal(voice));
    }
    await Future.wait(compileRes);
    currentProject.internalStatus = "idle";

    List<Future<bool>> voiceRes = [];
    for(final voice in currentProject.voices) {
      voiceRes.add(_playVoiceInternal(voice,playPos, 1 / currentProject.voices.length));
    }

    final voiceRes2 = await Future.wait(voiceRes);

    var errorShown = false;
    for(final res in voiceRes2) {
      if(!res) {
        if(!errorShown) {
          errorShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Theme.of(context).errorColor,
              content: new Text("Unable to play audio!"),
              duration: new Duration(seconds: 5),
            )
          );
        }
      }
      else {
        currentProject.internalStatus = "playing";
      }
    }
  }

  static Future<void> _compileVoiceInternal(MuonVoiceController voice) async {
    if(voice.audioPlayer != null) {
      await voice.audioPlayer.unload();
    }
    
    await voice.makeLabels();
    await voice.runNeutrino();
    await voice.vocodeWORLD();
  }

  /// Compiles all voices with NSF
  /// 
  /// Will show snackbars on progress
  /// 
  static Future<void> compileVoiceInternalNSF(BuildContext context) async {
    currentProject.internalStatus = "compiling_nsf";
    int voiceID = 0;
    for(final voice in currentProject.voices) {
      voiceID++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: new Text("Compiling voice " + voiceID.toString() + " with NSF..."),
          duration: new Duration(seconds: 2),
        )
      );
      await voice.vocodeNSF();
    }
    currentProject.internalStatus = "idle";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: new Text("NSF complete!"),
        duration: new Duration(seconds: 2),
      )
    );
  }

  static Future<bool> _playVoiceInternal(MuonVoiceController voice,Duration playPos,double volume) async {
    if(voice.audioPlayer != null) {
      await voice.audioPlayer.unload();
    }

    final audioPlayer = await voice.getAudioPlayer(playPos);

    audioPlayer.setVolume(volume);
    await audioPlayer.setPosition(playPos);
    final suc = await audioPlayer.play();

    if(suc) {
      return true;
    }
    else {
      return false;
    }
  }

  /// Stops any currently playing audio, if there is any.
  /// Otherwise, brings the playhead to the start of the project.
  static Future<void> stopAudio() async {
    for(final voice in currentProject.voices) {
      if(voice.audioPlayer != null) {
        voice.audioPlayer.unload();
      }
    }
    if(currentProject.internalStatus == "playing") {
      currentProject.internalStatus = "idle";
    }
    else {
      currentProject.playheadTime = 0;
    }
  }

  @override
  _MuonEditorState createState() => _MuonEditorState();
}

class _MuonEditorState extends State<MuonEditor> {
  static bool _firstTimeRunning = true;

  void _onFirstRun(BuildContext context) {
    final settings = getMuonSettings();

    if(settings.neutrinoDir != "") {
      // We have already performed first time set-up!

      Timer(Duration(milliseconds: 1),() {
        MuonEditor.showWelcomeScreen(context);
      });
    }
    else {
      // no neutrino library, so let's perform first time set-up!

      Timer(Duration(milliseconds: 1),() {
        MuonEditor.performFirstTimeSetup(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    currentProject.setupPlaybackTimers();

    if(_firstTimeRunning) {
      _firstTimeRunning = false;
      _onFirstRun(context);
    }

    return Scaffold(
      appBar: MuonAppBar(),
      // drawer: Drawer(
      //   child: ListView(
      //     children: [
      //       DrawerHeader(
      //         child: Text("Options"),
      //       )
      //     ],
      //   )
      // ),
      body: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: PianoRoll(
              currentProject,
              currentProject.selectedNotes,
              (pianoRoll,mouseEvent) {
                final mousePos = Point(mouseEvent.localPosition.dx,mouseEvent.localPosition.dy);
                final noteAtCursor = pianoRoll.painter.getNoteAtScreenPos(mousePos);
                
                if(noteAtCursor != null) {
                  var mouseBeats = pianoRoll.painter.getBeatNumAtCursor(mousePos.x);
                  var endBeat = (noteAtCursor.startAtTime + noteAtCursor.duration) / currentProject.timeUnitsPerBeat;

                  var cursorBeatEndDistance = (endBeat - mouseBeats) * pianoRoll.state.xScale * pianoRoll.painter.pixelsPerBeat;

                  if(cursorBeatEndDistance < 10) {
                    pianoRoll.state.setCursor(SystemMouseCursors.resizeLeftRight);
                  }
                  else {
                    pianoRoll.state.setCursor(SystemMouseCursors.click);
                  }
                }
                else {
                  pianoRoll.state.setCursor(MouseCursor.defer);
                }
              },
              (pianoRoll,mouseEvent,numClicks) {
                final mousePos = Point(mouseEvent.localPosition.dx,mouseEvent.localPosition.dy);
                // onClick
                final noteAtCursor = pianoRoll.painter.getNoteAtScreenPos(mousePos);

                if(!RawKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.shiftLeft)) {
                  currentProject.selectedNotes.forEach((note,isActive) {currentProject.selectedNotes[note] = false;});
                }

                if(numClicks == 1) {
                  if(noteAtCursor != null) {
                    if(currentProject.selectedNotes[noteAtCursor] == null) {
                      currentProject.selectedNotes[noteAtCursor] = false;
                    }
                    currentProject.selectedNotes[noteAtCursor] = !currentProject.selectedNotes[noteAtCursor];
                  }
                  else {
                    currentProject.playheadTime = (pianoRoll.painter.getBeatNumAtCursor(mousePos.x) * currentProject.timeUnitsPerBeat).roundToDouble() / currentProject.timeUnitsPerBeat;
                  }
                }
                else if(numClicks == 2) {
                  if(noteAtCursor != null) {
                    currentProject.selectedNotes[noteAtCursor] = true;

                    // edit note lyrics
                    final RenderBox overlay = Overlay.of(context).context.findRenderObject();

                    final initialLyricValue = noteAtCursor.lyric;
                    final textController = TextEditingController(text: initialLyricValue);
                    textController.selection = TextSelection(baseOffset: 0, extentOffset: initialLyricValue.length);

                    final editHistory = Map<int,String>();

                    showMenu(
                      context: context,
                      position: RelativeRect.fromRect(
                          mouseEvent.position & Size(40, 40), // smaller rect, the touch area
                          Offset.zero & overlay.size // Bigger rect, the entire screen
                        ),
                      items: [
                        PopupMenuItem(
                          child: TextField(
                            controller: textController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: "Lyrics",
                            ),
                            autofocus: true,
                            
                            onChanged: (String text) {
                              final hiraganaList = JapaneseUTF8.alphabetToHiragana(text);

                              noteAtCursor.voice.sortNotesByTime();

                              final curNotePos = noteAtCursor.voice.notes.indexOf(noteAtCursor);
                              for(int i=curNotePos;i < noteAtCursor.voice.notes.length;i++) {
                                if((i - curNotePos) < hiraganaList.length) {
                                  if(!editHistory.containsKey(i)) {
                                    editHistory[i] = noteAtCursor.voice.notes[i].lyric;
                                  }
                                  noteAtCursor.voice.notes[i].lyric = hiraganaList[i - curNotePos];
                                }
                                else if(editHistory.containsKey(i)) {
                                  noteAtCursor.voice.notes[i].lyric = editHistory[i];
                                }
                              }

                              if(hiraganaList.length == 0) {
                                // short cut: just remove the lyrics to the current note
                                if(!editHistory.containsKey(curNotePos)) {
                                  editHistory[curNotePos] = noteAtCursor.lyric;
                                }
                                noteAtCursor.lyric = "";
                              }
                            },
                          ),
                        ),
                      ],
                      elevation: 8.0,
                    );
                  }
                  else {
                    if(currentProject.voices.length > currentProject.currentVoiceID) {
                      MuonVoiceController voice = currentProject.voices[currentProject.currentVoiceID];
                      var note = MuonNoteController().ctx();
                      var pitch = pianoRoll.painter.getPitchAtCursor(mousePos.y);
                      note.octave = pitch.octave;
                      note.note = pitch.note;
                      note.startAtTime = (pianoRoll.painter.getBeatNumAtCursor(mousePos.x) * currentProject.timeUnitsPerBeat).floor();
                      note.duration = 1;
                      voice.addNote(note);
                    }
                  }
                }
              },
              (pianoRoll,mouseEvent,mouseFirstPos,note,originalNoteData) {
                final mousePos = Point(mouseEvent.localPosition.dx,mouseEvent.localPosition.dy);
                // onDragNote

                if(!RawKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.shiftLeft)) {
                  if(currentProject.selectedNotes[note] != true) {
                    currentProject.selectedNotes.forEach((note,isActive) {currentProject.selectedNotes[note] = false;});
                  }
                }

                currentProject.selectedNotes[note] = true;
                
                var originalFirstNote = originalNoteData[note];
                var mouseBeats = pianoRoll.painter.getBeatNumAtCursor(mouseFirstPos.x);
                var endBeat = (originalFirstNote.startAtTime + originalFirstNote.duration) / currentProject.timeUnitsPerBeat;

                var cursorBeatEndDistance = (endBeat - mouseBeats) * pianoRoll.state.xScale * pianoRoll.painter.pixelsPerBeat;

                bool resizeMode = cursorBeatEndDistance < 10;

                final fpDeltaSemiTones = pianoRoll.painter.screenPixelsToSemitones(mouseFirstPos.y) % 1;
                final deltaSemiTones = (pianoRoll.painter.screenPixelsToSemitones(mousePos.y - mouseFirstPos.y) + fpDeltaSemiTones).floor();

                final fpDeltaBeats = (pianoRoll.painter.getBeatNumAtCursor(mouseFirstPos.x) % 1);
                final deltaBeats = pianoRoll.painter.screenPixelsToBeats(mousePos.x - mouseFirstPos.x) + fpDeltaBeats / currentProject.timeUnitsPerBeat;
                final deltaSegments = deltaBeats * currentProject.timeUnitsPerBeat;
                final deltaSegmentsFixed = deltaSegments.floor();

                for(final selectedNote in currentProject.selectedNotes.keys) {
                  if(currentProject.selectedNotes[selectedNote]) {
                    if(originalNoteData[selectedNote] != null) {
                      if(resizeMode) {
                        selectedNote.duration = max(1,originalNoteData[selectedNote].duration + deltaSegmentsFixed);
                      }
                      else {
                        selectedNote.startAtTime = max(0,originalNoteData[selectedNote].startAtTime + deltaSegmentsFixed);
                        selectedNote.note = originalNoteData[selectedNote].note;
                        selectedNote.octave = originalNoteData[selectedNote].octave;
                        selectedNote.addSemitones(deltaSemiTones.floor());
                      }
                    }
                  }
                }

                currentProject.playheadTime = note.startAtTime / currentProject.timeUnitsPerBeat;
              },
              (pianoRoll,mouseEvent,mouseRect) {
                // final mousePos = Point(mouseEvent.localPosition.dx,mouseEvent.localPosition.dy);

                // onSelect
                if(!RawKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.shiftLeft)) {
                  currentProject.selectedNotes.forEach((note,isActive) => currentProject.selectedNotes[note] = false);
                }

                var notes = pianoRoll.painter.getNotesTouchingRect(mouseRect);

                double earliestTime = 1 / 0;
                for(final note in notes) {
                  currentProject.selectedNotes[note] = true;
                  earliestTime = min(earliestTime,note.startAtTime / currentProject.timeUnitsPerBeat);
                }

                if(earliestTime.isFinite) {
                  currentProject.playheadTime = earliestTime;
                }
              },
              (pianoRoll,keyEvent) {
                if(keyEvent.isControlPressed) {
                  // control key commands

                  if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyA)) {
                    // select all

                    for(final voice in currentProject.voices) {
                      for(final note in voice.notes) {
                        currentProject.selectedNotes[note] = true;
                      }
                    }
                  }
                  else if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyC) || keyEvent.isKeyPressed(LogicalKeyboardKey.keyX)) {
                    // copy / cut

                    bool cut = keyEvent.isKeyPressed(LogicalKeyboardKey.keyX);
                    currentProject.copiedNotes.clear();
                    currentProject.copiedNotesVoices.clear();

                    int earliestTime = 2147483647; // assuming int32, I cannot be bothered verifying this
                    for(final selectedNote in currentProject.selectedNotes.keys) {
                      if(currentProject.selectedNotes[selectedNote]) {
                        currentProject.copiedNotesVoices.add(selectedNote.voice);
                        currentProject.copiedNotes.add(selectedNote.toSerializable());
                        earliestTime = min(earliestTime,selectedNote.startAtTime);

                        if(cut) {
                          selectedNote.voice.notes.remove(selectedNote);
                        }
                      }
                    }

                    for(final note in currentProject.copiedNotes) {
                      note.startAtTime -= earliestTime;
                    }
                  }
                  else if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyV)) {
                    // paste

                    for(int idx = 0;idx < currentProject.copiedNotes.length;idx++) {
                      final note = currentProject.copiedNotes[idx];
                      final voice = currentProject.copiedNotesVoices[idx];
                      final cNote = MuonNoteController.fromSerializable(note);
                      cNote.startAtTime = cNote.startAtTime + (currentProject.playheadTime * currentProject.timeUnitsPerBeat).floor();
                      if(keyEvent.isShiftPressed) {
                        if(currentProject.currentVoiceID < currentProject.voices.length) {
                          currentProject.voices[currentProject.currentVoiceID].addNote(cNote);
                        }
                      }
                      else {
                        voice.addNote(cNote);
                      }
                    }
                  }
                  else if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyS)) {
                    currentProject.save();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: new Text("Saved project!"),
                        duration: new Duration(seconds: 2),
                      )
                    );
                  }
                }

                if(keyEvent.isKeyPressed(LogicalKeyboardKey.delete)) {
                  for(final selectedNote in currentProject.selectedNotes.keys) {
                    if(currentProject.selectedNotes[selectedNote]) {
                      selectedNote.voice.notes.remove(selectedNote);
                    }
                  }
                }
                else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
                  int moveBy = keyEvent.isShiftPressed ? 12 : 1;

                  for(final selectedNote in currentProject.selectedNotes.keys) {
                    if(currentProject.selectedNotes[selectedNote]) {
                      selectedNote.addSemitones(moveBy);
                    }
                  }
                }
                else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
                  int moveBy = keyEvent.isShiftPressed ? -12 : -1;

                  for(final selectedNote in currentProject.selectedNotes.keys) {
                    if(currentProject.selectedNotes[selectedNote]) {
                      selectedNote.addSemitones(moveBy);
                    }
                  }
                }
                else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
                  int moveBy = keyEvent.isShiftPressed ? currentProject.timeUnitsPerBeat : 1;

                  for(final selectedNote in currentProject.selectedNotes.keys) {
                    if(currentProject.selectedNotes[selectedNote]) {
                      selectedNote.startAtTime = selectedNote.startAtTime + moveBy;
                    }
                  }
                }
                else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
                  int moveBy = keyEvent.isShiftPressed ? -currentProject.timeUnitsPerBeat : -1;

                  for(final selectedNote in currentProject.selectedNotes.keys) {
                    if(currentProject.selectedNotes[selectedNote]) {
                      selectedNote.startAtTime = max(0,selectedNote.startAtTime + moveBy);
                    }
                  }
                }
                else if(keyEvent.isKeyPressed(LogicalKeyboardKey.space)) {
                  if(currentProject.internalStatus == "playing") {
                    MuonEditor.stopAudio();
                  }
                  else {
                    MuonEditor.playAudio(context);
                  }
                }
              },
            )
          ),
          MuonSidebar(),
        ]
      ),
    );
  }
}
