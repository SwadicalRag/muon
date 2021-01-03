
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:muon/controllers/muonnote.dart';
import 'package:muon/controllers/muonproject.dart';
import 'package:muon/controllers/muonvoice.dart';
import 'package:muon/logic/japanese.dart';
import 'package:muon/logic/musicxml.dart';
import 'package:muon/main.dart';
import 'package:muon/pianoroll.dart';
import 'package:muon/serializable/settings.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:path/path.dart' as p;

final currentProject = MuonProjectController.defaultProject();

List<String> getAllVoiceModels() {
  final List<String> items = [];

  final modelsDir = Directory(getRawProgramPath("model"));
  final modelsDirFiles = modelsDir.listSync();

  for(final modelsDirFile in modelsDirFiles) {
    if(modelsDirFile is Directory) {
      final modelName = p.relative(modelsDirFile.path,from: modelsDir.path);
      items.add(modelName);
    }
  }

  items.sort();

  return items;
}

class MuonEditor extends StatefulWidget {
  MuonEditor() : super();

  @override
  _MuonEditorState createState() => _MuonEditorState();
}

class _MuonEditorState extends State<MuonEditor> {
  bool _firstTimeSetupDone = false;

  void _welcomeScreen() {
    Timer(Duration(milliseconds: 1),() {
      showDialog<void>(
        context: context,
        barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) {
          return Scaffold(
            body: AlertDialog(
              title: Center(child: Text("Welcome to Muon!")),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    RaisedButton(
                      child: Text("Create New Project"),
                      onPressed: () {
                        _createNewProject();
                      }
                    ),
                    SizedBox(height: 10),
                    RaisedButton(
                      child: Text("Open Project"),
                      onPressed: () {
                        _openProject(context);
                      }
                    )
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("About"),
                  onPressed: () {
                    showAboutDialog(
                      context: context,
                      applicationVersion: "0.0.1",
                      applicationName: "Muon",
                      applicationLegalese: "copyright (c) swadical 2021",
                    );
                  },
                ),
                OutlineButton(
                  child: Text("Quit"),
                  onPressed: () {
                    exit(0);
                  },
                ),
              ],
            ),
          );
        },
      );
    });
  }

  void _openProject(BuildContext context) {
    FileSelectorPlatform.instance.openFile(
      confirmButtonText: "Open Project",
      acceptedTypeGroups: [XTypeGroup(
        label: "Muon Project Files",
        extensions: ['json'],
      )],
    )
    .then((value) {
      if(value != null) {
        final proj = MuonProjectController.loadFromFile(value.path);
        currentProject.updateWith(proj);
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

  void _createNewProject() {
    FileSelectorPlatform.instance.getSavePath(
      confirmButtonText: "Create Project",
      acceptedTypeGroups: [XTypeGroup(
        label: "Muon Project Files",
        extensions: ['json'],
      )],
      suggestedName: "project",
    )
    .then((value) {
      if(value != null) {
        currentProject.updateWith(MuonProjectController.defaultProject());
        currentProject.projectDir.value = p.dirname(value);
        currentProject.projectFileName.value = p.basename(value);
        if(!currentProject.projectFileName.value.endsWith(".json")) {
          currentProject.projectFileName.value += ".json";
        }
        currentProject.save();
      }
    })
    .catchError((err) {print("internal error: " + err.toString());}); // oh wow i am so naughty
  }

  Future<void> _playAudio() async {
    if(currentProject.internalStatus.value != "idle") {return;}

    final playPos = Duration(
      milliseconds: currentProject.getLabelMillisecondOffset() + 
        (
          1000 * 
          (
            currentProject.playheadTime.value / 
            (currentProject.bpm.value / 60)
          )
        ).floor()
      );

    List<Future<void>> compileRes = [];
    currentProject.internalStatus.value = "compiling";
    for(final voice in currentProject.voices) {
      compileRes.add(_compileVoiceInternal(voice));
    }
    await Future.wait(compileRes);
    currentProject.internalStatus.value = "idle";

    List<Future<bool>> voiceRes = [];
    for(final voice in currentProject.voices) {
      voiceRes.add(_playVoiceInternal(voice,playPos, 1 / currentProject.voices.length));
    }

    currentProject.internalPlayTime = DateTime.now().millisecondsSinceEpoch;
    final voiceRes2 = await Future.wait(voiceRes);

    var errorShown = false;
    for(final res in voiceRes2) {
      if(!res) {
        if(!errorShown) {
          errorShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Theme.of(context).errorColor,
              content: new Text('Unable to play audio!'),
              duration: new Duration(seconds: 5),
            )
          );
        }
      }
      else {
        currentProject.internalStatus.value = "playing";
      }
    }
  }

  Future<void> _compileVoiceInternal(MuonVoiceController voice) async {
    if(voice.audioPlayer != null) {
      await voice.audioPlayer.unload();
    }
    
    await voice.makeLabels();
    await voice.runNeutrino();
    await voice.vocodeWORLD();
  }

  Future<void> _compileVoiceInternalNSF() async {
    currentProject.internalStatus.value = "compiling_nsf";
    int voiceID = 0;
    for(final voice in currentProject.voices) {
      voiceID++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: new Text('Compiling voice ' + voiceID.toString() + " with NSF..."),
          duration: new Duration(seconds: 2),
        )
      );
      await voice.vocodeNSF();
    }
    currentProject.internalStatus.value = "idle";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: new Text("NSF complete!"),
        duration: new Duration(seconds: 2),
      )
    );
  }

  Future<bool> _playVoiceInternal(MuonVoiceController voice,Duration playPos,double volume) async {
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

  Future<void> _stopAudio() async {
    for(final voice in currentProject.voices) {
      if(voice.audioPlayer != null) {
        voice.audioPlayer.unload();
      }
    }
    if(currentProject.internalStatus.value == "playing") {
      currentProject.internalStatus.value = "idle";
    }
    else {
      currentProject.playheadTime.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = getMuonSettings();
    
    Timer.periodic(Duration(milliseconds: 500),(Timer t) async {
      if(currentProject.voices.length > currentProject.currentVoiceID.value) {
        MuonVoiceController voice = currentProject.voices[currentProject.currentVoiceID.value];
        if(voice.audioPlayer != null) {
          if(currentProject.internalStatus.value == "playing") {
            dynamic posDur = await voice.audioPlayer.getPosition();
            if(posDur is Duration) {
              int curPos = posDur.inMilliseconds;

              if(curPos >= voice.audioPlayerDuration) {
                currentProject.internalPlayTime = 0;
                currentProject.playheadTime.value = 0;
                currentProject.internalStatus.value = "idle";
              }
              else {
                int voicePos = curPos - currentProject.getLabelMillisecondOffset();
                currentProject.internalPlayTime = DateTime.now().millisecondsSinceEpoch - voicePos;
              }
            }
          }
        }
      }
    });
    
    Timer.periodic(Duration(milliseconds: 1),(Timer t) async {
      if(currentProject.voices.length > currentProject.currentVoiceID.value) {
        MuonVoiceController voice = currentProject.voices[currentProject.currentVoiceID.value];
        if(voice.audioPlayer != null) {
          if(currentProject.internalStatus.value == "playing") {
            int voicePos = DateTime.now().millisecondsSinceEpoch - currentProject.internalPlayTime;
            int curPos = voicePos + currentProject.getLabelMillisecondOffset();

            if(curPos >= voice.audioPlayerDuration) {
              currentProject.playheadTime.value = 0;
              currentProject.internalStatus.value = "idle";
            }
            else {
              currentProject.playheadTime.value = voicePos / 1000 * (currentProject.bpm / 60);
            }
          }
        }
      }
    });

    if((settings.neutrinoDir == "") && !_firstTimeSetupDone) {
      // perform first time setup

      _firstTimeSetupDone = true;

      Timer(Duration(milliseconds: 500),() {
        showDialog<void>(
          context: context,
          barrierDismissible: false, // user must tap button!
          builder: (BuildContext subContext) {
            return Scaffold(
              body: AlertDialog(
                title: Text("Hello and welcome!"),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Text("Before you start using Muon, we need to do some housekeeping!"),
                      SizedBox(height: 15,),
                      RaisedButton(
                        child: Text("Choose Neutrino SDK Folder Location"),
                        onPressed: () {
                          FileSelectorPlatform.instance.getDirectoryPath(
                            confirmButtonText: "Open Neutrino SDK",
                          )
                          .catchError((err) {print("internal file browser error: " + err.toString());}) // oh wow i am so naughty
                          .then((value) {
                            if(value != null) {
                              if(Directory(value).existsSync()) {
                                if(File(value + "/bin/NEUTRINO.exe").existsSync() || File(value + "/bin/NEUTRINO").existsSync()) {
                                  settings.neutrinoDir = value;
                                  settings.save();
                                  return;
                                }
                              }

                              settings.neutrinoDir = "";
                              settings.save();

                              ScaffoldMessenger.of(subContext).hideCurrentSnackBar();
                              ScaffoldMessenger.of(subContext).showSnackBar(
                                SnackBar(backgroundColor: Theme.of(subContext).errorColor,
                                  content: new Text("Error: That doesn't seem like a valid NEUTRINO directory!"),
                                  duration: new Duration(seconds: 5),
                                )
                              );
                            }
                          });
                        },
                      ),
                      SizedBox(height: 15,),
                      SwitchListTile(
                        title: Text("Please burn my eyes"),
                        secondary: Icon(Icons.lightbulb_outline),
                        value: !darkMode.value,
                        onChanged: (value) {
                          darkMode.value = !value;
                        },
                      )
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text("I'm all set!"),
                    onPressed: () {
                      if(settings.neutrinoDir == "") {
                        ScaffoldMessenger.of(subContext).hideCurrentSnackBar();
                        ScaffoldMessenger.of(subContext).showSnackBar(
                          SnackBar(backgroundColor: Theme.of(subContext).errorColor,
                            content: new Text('Error: Please choose a valid directory for the NEUTRINO library!'),
                            duration: new Duration(seconds: 5),
                          )
                        );
                      }
                      else {
                        Navigator.of(subContext, rootNavigator: true).pop();
                        _welcomeScreen();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      });
    }
    else if((settings.neutrinoDir != "") && !_firstTimeSetupDone) {
      _firstTimeSetupDone = true;

      _welcomeScreen();
    }

    final themeData = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Muon Editor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.exposure_plus_1),
            tooltip: "Add subdivision",
            onPressed: () {
              currentProject.setSubdivision(currentProject.currentSubdivision.value + 1);
            },
          ),
          IconButton(
            icon: const Icon(Icons.exposure_minus_1),
            tooltip: "Subtract subdivision",
            onPressed: () {
              currentProject.setSubdivision(max(1,currentProject.currentSubdivision.value - 1));
            },
          ),
          SizedBox(width: 40,),
          Obx(() => IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: "Play",
            color: currentProject.internalStatus.value == "compiling" ? 
              Colors.yellow : 
                currentProject.internalStatus.value == "playing" ?
                  Colors.green :
                  Colors.white,
            onPressed: () {
              _playAudio();
            },
          )),
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: "Stop",
            onPressed: () {
              _stopAudio();
            },
          ),
          SizedBox(width: 40,),
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: "Calculate phoneme labels",
            onPressed: () {
              for(final voice in currentProject.voices) {
                voice.makeLabels();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.music_note),
            tooltip: "Calculate neutrino data",
            onPressed: () {
              for(final voice in currentProject.voices) {
                voice.runNeutrino();
              }
            },
          ),
          Obx(() => IconButton(
            icon: const Icon(Icons.computer),
            color: currentProject.internalStatus.value == "compiling_nsf" ? 
              Colors.yellow : Colors.white,
            tooltip: "Render with NSF",
            onPressed: () {
              _compileVoiceInternalNSF();
            },
          )),
          SizedBox(width: 40,),
          Obx(() => IconButton(
              icon: darkMode.value ? const Icon(Icons.lightbulb) : const Icon(Icons.lightbulb_outline),
              tooltip: darkMode.value ? "Lights on" : "Lights out",
              onPressed: () {
                darkMode.value = !darkMode.value;
              },
            ),
          ),
          SizedBox(width: 40,),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: "Save",
            onPressed: () {
              currentProject.save();
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: "Load",
            onPressed: () {
              _openProject(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.create),
            tooltip: "New project",
            onPressed: () {
              _createNewProject();
            },
          ),
          SizedBox(width: 20,),
        ],
      ),
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
                  var endBeat = (noteAtCursor.startAtTime.value + noteAtCursor.duration.value) / currentProject.timeUnitsPerBeat.value;

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
                    currentProject.playheadTime.value = (pianoRoll.painter.getBeatNumAtCursor(mousePos.x) * currentProject.timeUnitsPerBeat.value).roundToDouble() / currentProject.timeUnitsPerBeat.value;
                  }
                }
                else if(numClicks == 2) {
                  if(noteAtCursor != null) {
                    currentProject.selectedNotes[noteAtCursor] = true;

                    // edit note lyrics
                    final RenderBox overlay = Overlay.of(context).context.findRenderObject();

                    final initialLyricValue = noteAtCursor.lyric.value;
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
                              labelText: 'Lyrics',
                            ),
                            autofocus: true,
                            
                            onChanged: (String text) {
                              final hiraganaList = JapaneseUTF8.alphabetToHiragana(text);

                              noteAtCursor.voice.sortNotesByTime();

                              final curNotePos = noteAtCursor.voice.notes.indexOf(noteAtCursor);
                              for(int i=curNotePos;i < noteAtCursor.voice.notes.length;i++) {
                                if((i - curNotePos) < hiraganaList.length) {
                                  if(!editHistory.containsKey(i)) {
                                    editHistory[i] = noteAtCursor.voice.notes[i].lyric.value;
                                  }
                                  noteAtCursor.voice.notes[i].lyric.value = hiraganaList[i - curNotePos];
                                }
                                else if(editHistory.containsKey(i)) {
                                  noteAtCursor.voice.notes[i].lyric.value = editHistory[i];
                                }
                              }

                              if(hiraganaList.length == 0) {
                                // short cut: just remove the lyrics to the current note
                                if(!editHistory.containsKey(curNotePos)) {
                                  editHistory[curNotePos] = noteAtCursor.lyric.value;
                                }
                                noteAtCursor.lyric.value = "";
                              }

                              // dumb hack to force repaint
                              pianoRoll.state.repaint();
                            },
                          ),
                        ),
                      ],
                      elevation: 8.0,
                    );
                  }
                  else {
                    if(currentProject.voices.length > currentProject.currentVoiceID.value) {
                      MuonVoiceController voice = currentProject.voices[currentProject.currentVoiceID.value];
                      var note = MuonNoteController();
                      var pitch = pianoRoll.painter.getPitchAtCursor(mousePos.y);
                      note.octave.value = pitch.octave;
                      note.note.value = pitch.note;
                      note.startAtTime.value = (pianoRoll.painter.getBeatNumAtCursor(mousePos.x) * currentProject.timeUnitsPerBeat.value).floor();
                      note.duration.value = 1;
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
                var endBeat = (originalFirstNote.startAtTime + originalFirstNote.duration) / currentProject.timeUnitsPerBeat.value;

                var cursorBeatEndDistance = (endBeat - mouseBeats) * pianoRoll.state.xScale * pianoRoll.painter.pixelsPerBeat;

                bool resizeMode = cursorBeatEndDistance < 10;

                final fpDeltaSemiTones = pianoRoll.painter.screenPixelsToSemitones(mouseFirstPos.y) % 1;
                final deltaSemiTones = (pianoRoll.painter.screenPixelsToSemitones(mousePos.y - mouseFirstPos.y) + fpDeltaSemiTones).floor();

                final fpDeltaBeats = (pianoRoll.painter.getBeatNumAtCursor(mouseFirstPos.x) % 1);
                final deltaBeats = pianoRoll.painter.screenPixelsToBeats(mousePos.x - mouseFirstPos.x) + fpDeltaBeats / currentProject.timeUnitsPerBeat.value;
                final deltaSegments = deltaBeats * currentProject.timeUnitsPerBeat.value;
                final deltaSegmentsFixed = deltaSegments.floor();

                for(final selectedNote in currentProject.selectedNotes.keys) {
                  if(currentProject.selectedNotes[selectedNote]) {
                    if(originalNoteData[selectedNote] != null) {
                      if(resizeMode) {
                        selectedNote.duration.value = max(1,originalNoteData[selectedNote].duration + deltaSegmentsFixed);
                      }
                      else {
                        selectedNote.startAtTime.value = max(0,originalNoteData[selectedNote].startAtTime + deltaSegmentsFixed);
                        selectedNote.note.value = originalNoteData[selectedNote].note;
                        selectedNote.octave.value = originalNoteData[selectedNote].octave;
                        selectedNote.addSemitones(deltaSemiTones.floor());
                      }
                    }
                  }
                }

                currentProject.playheadTime.value = note.startAtTime.value / currentProject.timeUnitsPerBeat.value;
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
                  earliestTime = min(earliestTime,note.startAtTime.value / currentProject.timeUnitsPerBeat.value);
                }

                if(earliestTime.isFinite) {
                  currentProject.playheadTime.value = earliestTime;
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

                    // dumb hack to force repaint
                    pianoRoll.state.repaint();
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
                        earliestTime = min(earliestTime,selectedNote.startAtTime.value);

                        if(cut) {
                          selectedNote.voice.notes.remove(selectedNote);
                        }
                      }
                    }

                    for(final note in currentProject.copiedNotes) {
                      note.startAtTime -= earliestTime;
                    }

                    // dumb hack to force repaint
                    pianoRoll.state.repaint();
                  }
                  else if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyV)) {
                    // paste

                    for(int idx = 0;idx < currentProject.copiedNotes.length;idx++) {
                      final note = currentProject.copiedNotes[idx];
                      final voice = currentProject.copiedNotesVoices[idx];
                      final cNote = MuonNoteController.fromSerializable(note);
                      cNote.startAtTime.value = cNote.startAtTime.value + (currentProject.playheadTime.value * currentProject.timeUnitsPerBeat.value).floor();
                      if(keyEvent.isShiftPressed) {
                        if(currentProject.currentVoiceID.value < currentProject.voices.length) {
                          currentProject.voices[currentProject.currentVoiceID.value].addNote(cNote);
                        }
                      }
                      else {
                        voice.addNote(cNote);
                      }
                    }

                    // dumb hack to force repaint
                    pianoRoll.state.repaint();
                  }
                  else if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyS)) {
                    currentProject.save();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: new Text('Saved project!'),
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

                  // dumb hack to force repaint
                  pianoRoll.state.repaint();
                }
                else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
                  int moveBy = keyEvent.isShiftPressed ? 12 : 1;

                  for(final selectedNote in currentProject.selectedNotes.keys) {
                    if(currentProject.selectedNotes[selectedNote]) {
                      selectedNote.addSemitones(moveBy);
                    }
                  }

                  // dumb hack to force repaint
                  pianoRoll.state.repaint();
                }
                else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
                  int moveBy = keyEvent.isShiftPressed ? -12 : -1;

                  for(final selectedNote in currentProject.selectedNotes.keys) {
                    if(currentProject.selectedNotes[selectedNote]) {
                      selectedNote.addSemitones(moveBy);
                    }
                  }

                  // dumb hack to force repaint
                  pianoRoll.state.repaint();
                }
                else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
                  int moveBy = keyEvent.isShiftPressed ? currentProject.timeUnitsPerBeat.value : 1;

                  for(final selectedNote in currentProject.selectedNotes.keys) {
                    if(currentProject.selectedNotes[selectedNote]) {
                      selectedNote.startAtTime.value = selectedNote.startAtTime.value + moveBy;
                    }
                  }

                  // dumb hack to force repaint
                  pianoRoll.state.repaint();
                }
                else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
                  int moveBy = keyEvent.isShiftPressed ? -currentProject.timeUnitsPerBeat.value : -1;

                  for(final selectedNote in currentProject.selectedNotes.keys) {
                    if(currentProject.selectedNotes[selectedNote]) {
                      selectedNote.startAtTime.value = max(0,selectedNote.startAtTime.value + moveBy);
                    }
                  }

                  // dumb hack to force repaint
                  pianoRoll.state.repaint();
                }
                else if(keyEvent.isKeyPressed(LogicalKeyboardKey.space)) {
                  if(currentProject.internalStatus.value == "playing") {
                    _stopAudio();
                  }
                  else {
                    _playAudio();
                  }
                }
              },
            )
          ),
          Container(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  child: Column(
                    children: [
                      SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: Text("Project Settings",style: TextStyle(fontSize: 26),)
                      ),
                      SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: Obx(() => Text(currentProject.bpm.value.toString() + " BPM",style: TextStyle(fontSize: 16),))
                      ),
                      Obx(() => Slider(
                        value: currentProject.bpm.value,
                        min: 40,
                        max: 240,
                        divisions: 200,
                        label: currentProject.bpm.value.toString() + " bpm",
                        onChanged: (double value) {
                          currentProject.bpm.value = value.floorToDouble();
                        },
                      )),
                      SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: Obx(() => Text(currentProject.beatsPerMeasure.value.toString() + " Beats per Measure",style: TextStyle(fontSize: 16),))
                      ),
                      Obx(() => Slider(
                        value: currentProject.beatsPerMeasure.value.toDouble(),
                        min: 1,
                        max: 32,
                        divisions: 32,
                        label: currentProject.beatsPerMeasure.value.toString() + " beats",
                        onChanged: (double value) {
                          currentProject.beatsPerMeasure.value = value.round();
                        },
                      )),
                      SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: Obx(() => Text("Beat Value of 1 / " + currentProject.beatValue.value.toString(),style: TextStyle(fontSize: 16),))
                      ),
                      Obx(() => Slider(
                        value: log(currentProject.beatValue.value) / log(2),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: "1 / " + currentProject.beatValue.value.toString(),
                        onChanged: (double value) {
                          currentProject.beatValue.value = pow(2,value.round());
                        },
                      )),
                    ],
                  )
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    child: Column(
                      verticalDirection: VerticalDirection.up,
                      children: [
                        Expanded(
                          child: Scrollbar(
                            child: Obx(() => ListView.builder(
                              itemCount: currentProject.voices.length,
                              itemBuilder: (context, index) {
                                final voice = currentProject.voices[index];
                                return Container(
                                  height: 40,
                                  margin: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
                                  padding: EdgeInsets.only(left: 15),
                                  child: Row(
                                    children: [
                                      Container(
                                        margin: EdgeInsets.only(right: 10),
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: voice.color,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(0.7),
                                              blurRadius: 2,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Obx(() => Text(
                                          "Voice " + (currentProject.voices.indexOf(voice) + 1).toString() + " (" + voice.modelName.value + ")",
                                        ))
                                      ),
                                      Expanded(
                                        child: Container(),
                                      ),
                                      Obx(() => IconButton(
                                        icon: const Icon(Icons.center_focus_strong),
                                        disabledColor: Colors.green.withOpacity(0.9),
                                        tooltip: "Select voice",
                                        onPressed: currentProject.currentVoiceID.value == currentProject.voices.indexOf(voice) ? null : () {
                                          currentProject.currentVoiceID.value = currentProject.voices.indexOf(voice);
                                        },
                                      )),
                                      PopupMenuButton(
                                        icon: const Icon(Icons.speaker_notes),
                                        tooltip: "Change voice model",
                                        onSelected: (String result) {
                                          voice.modelName.value = result;
                                        },
                                        itemBuilder: (BuildContext context) {
                                          final List<PopupMenuItem<String>> items = [];

                                          final models = getAllVoiceModels();

                                          for(final modelName in models) {
                                            items.add(
                                              PopupMenuItem(
                                                value: modelName,
                                                child: Text(modelName),
                                              ),
                                            );
                                          }

                                          return items;
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        tooltip: "Delete voice",
                                        onPressed: () {
                                          currentProject.voices.remove(voice);
                                        },
                                      ),
                                    ],
                                  ),
                                  decoration: BoxDecoration(
                                    color: themeData.buttonColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 1,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  ),
                                );
                              },
                            )),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 5),
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Text("Voices",style: TextStyle(fontSize: 26),)
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Transform.translate(
                                  offset: Offset(-5,0),
                                  child: IconButton(
                                    icon: const Icon(Icons.add),
                                    tooltip: "Add voice",
                                    onPressed: () {
                                      final newVoice = MuonVoiceController();
                                      newVoice.project = currentProject;
                                      currentProject.voices.add(newVoice);
                                    },
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Transform.translate(
                                  offset: Offset(-35,0),
                                  child: IconButton(
                                    icon: const Icon(Icons.code),
                                    tooltip: "Import voice from MusicXML",
                                    onPressed: () {
                                      Timer(Duration(milliseconds: 50),() {
                                        FileSelectorPlatform.instance.openFile(
                                          confirmButtonText: "Open MusicXML File",
                                        )
                                        .catchError((err) {print("internal file browser error: " + err.toString());}) // oh wow i am so naughty
                                        .then((value) {
                                          if(value != null) {
                                            MusicXML musicXML = parseFile(value.path);
                                            currentProject.importVoiceFromMusicXML(musicXML, true);
                                          }
                                        });
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Transform.translate(
                                  offset: Offset(-65,0),
                                  child: IconButton(
                                    icon: const Icon(Icons.queue_music),
                                    tooltip: "Import voice from MIDI",
                                    onPressed: () {
                                      Timer(Duration(milliseconds: 50),() {
                                        FileSelectorPlatform.instance.openFile(
                                          confirmButtonText: "Open MIDI File",
                                        )
                                        .catchError((err) {print("internal file browser error: " + err.toString());}) // oh wow i am so naughty
                                        .then((value) {
                                          if(value != null) {
                                            currentProject.importVoiceFromMIDIFile(value.path, true);
                                          }
                                        });
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          decoration: BoxDecoration(
                            color: themeData.scaffoldBackgroundColor,
                            boxShadow: [
                              BoxShadow(
                                offset: Offset(0,5),
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 3,
                                spreadRadius: 1,
                              ),
                            ]
                          ),
                        ),
                      ],
                    ),
                    decoration: BoxDecoration(
                      color: themeData.scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 1,
                          spreadRadius: 1,
                        ),
                      ]
                    ),
                  ),
                ),
              ],
            ),
            width: 400,
            decoration: BoxDecoration(
              color: themeData.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 7,
                  spreadRadius: 1,
                ),
              ]
            ),
          ),
        ]
      ),
    );
  }
}
