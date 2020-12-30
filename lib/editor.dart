
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:muon/controllers/muonproject.dart';
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
              (pianoRoll,mousePos) {
                final noteAtCursor = pianoRoll.painter.getNoteAtScreenPos(mousePos);
                
                if(noteAtCursor != null) {
                  var mouseBeats = pianoRoll.painter.getAbsoluteTimeAtCursor(mousePos.x);
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
              (pianoRoll,mousePos) {
                // onClick
                final noteAtCursor = pianoRoll.painter.getNoteAtScreenPos(mousePos);

                if(!RawKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.shiftLeft)) {
                  currentProject.selectedNotes.forEach((note,isActive) {currentProject.selectedNotes[note] = false;});
                }

                if(noteAtCursor != null) {
                  if(currentProject.selectedNotes[noteAtCursor] == null) {
                    currentProject.selectedNotes[noteAtCursor] = false;
                  }
                  currentProject.selectedNotes[noteAtCursor] = !currentProject.selectedNotes[noteAtCursor];
                }
              },
              (pianoRoll,mousePos,mouseFirstPos,note,originalNoteData) {
                // onDragNote

                if(!RawKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.shiftLeft)) {
                  if(currentProject.selectedNotes[note] != true) {
                    currentProject.selectedNotes.forEach((note,isActive) {currentProject.selectedNotes[note] = false;});
                  }
                }

                currentProject.selectedNotes[note] = true;
                
                var originalFirstNote = originalNoteData[note];
                var mouseBeats = pianoRoll.painter.getAbsoluteTimeAtCursor(mouseFirstPos.x);
                var endBeat = (originalFirstNote.startAtTime + originalFirstNote.duration) / currentProject.timeUnitsPerBeat.value;

                var cursorBeatEndDistance = (endBeat - mouseBeats) * pianoRoll.state.xScale * pianoRoll.painter.pixelsPerBeat;

                bool resizeMode = cursorBeatEndDistance < 10;

                final fpDeltaSemiTones = pianoRoll.painter.screenPixelsToSemitones(mouseFirstPos.y) % 1;
                final deltaSemiTones = (pianoRoll.painter.screenPixelsToSemitones(mousePos.y - mouseFirstPos.y) + fpDeltaSemiTones).floor();

                final fpDeltaBeats = (pianoRoll.painter.getAbsoluteTimeAtCursor(mouseFirstPos.x) % 1);
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
              (pianoRoll,mouseRect) {
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
