
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:muon/controllers/muonnote.dart';
import 'package:muon/controllers/muonproject.dart';
import 'package:muon/logic/japanese.dart';
import 'package:muon/main.dart';
import 'package:muon/pianoroll.dart';

final currentProject = MuonProjectController.defaultProject();

class MuonEditor extends StatefulWidget {
  MuonEditor() : super();

  @override
  _MuonEditorState createState() => _MuonEditorState();
}

class _MuonEditorState extends State<MuonEditor> {
  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Muon Editor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: "Play",
            onPressed: () {
              
            },
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: "Stop",
            onPressed: () {
              
            },
          ),
          SizedBox(width: 40,),
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: "Calculate phoneme labels",
            onPressed: () {
              
            },
          ),
          IconButton(
            icon: const Icon(Icons.music_note),
            tooltip: "Calculate neutrino data",
            onPressed: () {
              
            },
          ),
          IconButton(
            icon: const Icon(Icons.computer),
            tooltip: "Render with NSF",
            onPressed: () {
              
            },
          ),
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
              
            },
          ),
          IconButton(
            icon: const Icon(Icons.create),
            tooltip: "New project",
            onPressed: () {
              currentProject.updateWith(MuonProjectController.defaultProject());
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
            child: Obx(() => PianoRoll(
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
                              pianoRoll.state.setState(() {});
                            },
                          ),
                        ),
                      ],
                      elevation: 8.0,
                    );
                  }
                  else {
                    var note = MuonNoteController();
                    var pitch = pianoRoll.painter.getPitchAtCursor(mousePos.y);
                    note.octave.value = pitch.octave;
                    note.note.value = pitch.note;
                    note.startAtTime.value = (pianoRoll.painter.getBeatNumAtCursor(mousePos.x) * currentProject.timeUnitsPerBeat.value).floor();
                    note.duration.value = 1;
                    currentProject.voices[0].addNote(note);
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
                final deltaBeats = pianoRoll.painter.screenPixelsToBeats(mousePos.x - mouseFirstPos.x) + fpDeltaBeats / currentProject.currentSubdivision.value;
                final deltaSegments = deltaBeats * currentProject.currentSubdivision.value;
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
              },
              (pianoRoll,mouseEvent,mouseRect) {
                // final mousePos = Point(mouseEvent.localPosition.dx,mouseEvent.localPosition.dy);

                // onSelect
                if(!RawKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.shiftLeft)) {
                  currentProject.selectedNotes.forEach((note,isActive) => currentProject.selectedNotes[note] = false);
                }

                var notes = pianoRoll.painter.getNotesTouchingRect(mouseRect);

                for(final note in notes) {
                  currentProject.selectedNotes[note] = true;
                }
              },
            ))
          ),
          Container(
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
