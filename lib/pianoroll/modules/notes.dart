import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:muon/controllers/muonnote.dart';
import 'package:muon/controllers/muonvoice.dart';
import 'package:muon/logic/japanese.dart';
import 'package:muon/pianoroll/pianoroll.dart';
import 'package:muon/serializable/muon.dart';
import 'package:synaps_flutter/synaps_flutter.dart';

class PianoRollNotesModule extends PianoRollModule {
  final SynapsMap<MuonNoteController, bool> selectedNotes;

  MuonNoteController _internalDragFirstNote;
  Map<MuonNoteController, MuonNote> noteDragOriginalData;

  PianoRollNotesModule({
    @required this.selectedNotes,
  }) : super();

  /// Get the bounding rect of the note in the canvas coordinate system
  Rect getNoteRect(MuonNoteController note) {
    final noteL =
        note.startAtTime * painter.pixelsPerBeat / project.timeUnitsPerBeat;
    final noteT = PianoRollPainter.pitchToYAxis(note);
    final noteR = noteL +
        (note.duration * painter.pixelsPerBeat / project.timeUnitsPerBeat);
    final noteB = noteT + 20;

    return Rect.fromLTRB(noteL, noteT, noteR, noteB);
  }

  /// Get the note under where the mouse is
  MuonNoteController getNoteAtScreenPos(Point screenPos) {
    // O(n), LOOK AWAY!
    // I DON'T CARE

    final canvasPos = painter.screenPosToCanvasPos(screenPos, false);

    for (final voice in project.voices) {
      for (final note in voice.notes) {
        final noteRect = getNoteRect(note);

        if(noteRect.contains(Offset(canvasPos.x,canvasPos.y))) {
          return note;
        }
      }
    }

    return null;
  }

  /// Get the notes inside the screen coordinate system rect
  List<MuonNoteController> getNotesTouchingRect(Rect screenRect) {
    // O(n), LOOK AWAY!
    // I STILL DON'T CARE

    final canvasRect = painter.screenRectToCanvasRect(screenRect, false);

    final List<MuonNoteController> out = [];

    for (final voice in project.voices) {
      for (final note in voice.notes) {
        var noteRect = getNoteRect(note);

        if (canvasRect.overlaps(noteRect)) {
          out.add(note);
        }
      }
    }

    return out;
  }

  bool hitTest(Point point) {
    final noteAtCursor = getNoteAtScreenPos(point);
    
    if(noteAtCursor != null) {
      return true;
    }

    return false;
  }

  void onHover(PointerEvent mouseEvent) {
    final mousePos = Point(mouseEvent.localPosition.dx,mouseEvent.localPosition.dy);
    final noteAtCursor = getNoteAtScreenPos(mousePos);
    
    if(noteAtCursor != null) {
      var mouseBeats = painter.getBeatNumAtCursor(mousePos.x);
      var endBeat = (noteAtCursor.startAtTime + noteAtCursor.duration) / project.timeUnitsPerBeat;

      var cursorBeatEndDistance = (endBeat - mouseBeats) * painter.xScale * painter.pixelsPerBeat;

      if(cursorBeatEndDistance < 10) {
        state.setCursor(SystemMouseCursors.resizeLeftRight);
      }
      else {
        state.setCursor(SystemMouseCursors.click);
      }
    }
    else {
      state.setCursor(MouseCursor.defer);
    }
  }

  void onClick(PointerEvent mouseEvent, int numClicks) {
    final mousePos = Point(mouseEvent.localPosition.dx,mouseEvent.localPosition.dy);
    // onClick
    final noteAtCursor = getNoteAtScreenPos(mousePos);

    if(!RawKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.shiftLeft)) {
      selectedNotes.forEach((note,isActive) {selectedNotes[note] = false;});
    }

    if(numClicks == 1) {
      if(noteAtCursor != null) {
        if(selectedNotes[noteAtCursor] == null) {
          selectedNotes[noteAtCursor] = false;
        }
        selectedNotes[noteAtCursor] = !selectedNotes[noteAtCursor];
      }
      else {
        project.playheadTime = (painter.getBeatNumAtCursor(mousePos.x) * project.timeUnitsPerBeat).roundToDouble() / project.timeUnitsPerBeat;
      }
    }
    else if(numClicks == 2) {
      if(noteAtCursor != null) {
        selectedNotes[noteAtCursor] = true;

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
        if(project.voices.length > project.currentVoiceID) {
          MuonVoiceController voice = project.voices[project.currentVoiceID];
          var note = MuonNoteController().ctx();
          var pitch = painter.getPitchAtCursor(mousePos.y);
          note.octave = pitch.octave;
          note.note = pitch.note;
          note.startAtTime = (painter.getBeatNumAtCursor(mousePos.x) * project.timeUnitsPerBeat).floor();
          note.duration = 1;
          voice.addNote(note);
        }
      }
    }
  }

  void onDragStart(PointerEvent mouseEvent, Point mouseStartPos) {
    final noteAtCursor = getNoteAtScreenPos(mouseStartPos);

    // this should never happen?
    if(noteAtCursor == null) {return;}

    _internalDragFirstNote = noteAtCursor;

    noteDragOriginalData = {};
    noteDragOriginalData[noteAtCursor] = noteAtCursor.toSerializable();

    for(final note in selectedNotes.keys) {
      if(selectedNotes[note]) {
        noteDragOriginalData[note] = note.toSerializable();
      }
    }
  }

  void onDragging(PointerEvent mouseEvent, Point mouseStartPos) {
    if(_internalDragFirstNote == null) {return;}

    final note = _internalDragFirstNote;
    final mousePos = Point(mouseEvent.localPosition.dx,mouseEvent.localPosition.dy);

    if(!RawKeyboard.instance.physicalKeysPressed.contains(PhysicalKeyboardKey.shiftLeft)) {
      if(selectedNotes[note] != true) {
        selectedNotes.forEach((note,isActive) {selectedNotes[note] = false;});
      }
    }

    selectedNotes[note] = true;
    
    var originalFirstNote = noteDragOriginalData[note];
    var mouseBeats = painter.getBeatNumAtCursor(mouseStartPos.x);
    var endBeat = (originalFirstNote.startAtTime + originalFirstNote.duration) / project.timeUnitsPerBeat;

    var cursorBeatEndDistance = (endBeat - mouseBeats) * painter.xScale * painter.pixelsPerBeat;

    bool resizeMode = cursorBeatEndDistance < 10;

    final fpDeltaSemiTones = painter.screenPixelsToSemitones(mouseStartPos.y) % 1;
    final deltaSemiTones = (painter.screenPixelsToSemitones(mousePos.y - mouseStartPos.y) + fpDeltaSemiTones).floor();

    final fpDeltaBeats = (painter.getBeatNumAtCursor(mouseStartPos.x) % 1);
    final deltaBeats = painter.screenPixelsToBeats(mousePos.x - mouseStartPos.x) + fpDeltaBeats / project.timeUnitsPerBeat;
    final deltaSegments = deltaBeats * project.timeUnitsPerBeat;
    final deltaSegmentsFixed = deltaSegments.floor();

    for(final selectedNote in selectedNotes.keys) {
      if(selectedNotes[selectedNote]) {
        if(noteDragOriginalData[selectedNote] != null) {
          if(resizeMode) {
            selectedNote.duration = max(1,noteDragOriginalData[selectedNote].duration + deltaSegmentsFixed);
          }
          else {
            selectedNote.startAtTime = max(0,noteDragOriginalData[selectedNote].startAtTime + deltaSegmentsFixed);
            selectedNote.note = noteDragOriginalData[selectedNote].note;
            selectedNote.octave = noteDragOriginalData[selectedNote].octave;
            selectedNote.addSemitones(deltaSemiTones.floor());
          }
        }
      }
    }

    project.playheadTime = note.startAtTime / project.timeUnitsPerBeat;
  }

  void onDragEnd(PointerEvent mouseEvent, Point mouseStartPos) {
    noteDragOriginalData.clear();
    _internalDragFirstNote = null;
  }

  void onSelect(PointerEvent mouseEvent, Rect selectionBox) {
    if (!RawKeyboard.instance.physicalKeysPressed
        .contains(PhysicalKeyboardKey.shiftLeft)) {
      selectedNotes.forEach((note, isActive) => selectedNotes[note] = false);
    }

    var notes = getNotesTouchingRect(selectionBox);

    double earliestTime = 1 / 0;
    for (final note in notes) {
      selectedNotes[note] = true;
      earliestTime =
          min(earliestTime, note.startAtTime / project.timeUnitsPerBeat);
    }

    if (earliestTime.isFinite) {
      project.playheadTime = earliestTime;
    }
  }

  void onKey(RawKeyEvent keyEvent) {
    if(keyEvent.isControlPressed) {
      // control key commands

      if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyA)) {
        // select all

        for(final voice in project.voices) {
          for(final note in voice.notes) {
            selectedNotes[note] = true;
          }
        }
      }
      else if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyC) || keyEvent.isKeyPressed(LogicalKeyboardKey.keyX)) {
        // copy / cut

        bool cut = keyEvent.isKeyPressed(LogicalKeyboardKey.keyX);
        project.copiedNotes.clear();
        project.copiedNotesVoices.clear();

        int earliestTime = 2147483647; // assuming int32, I cannot be bothered verifying this
        for(final selectedNote in selectedNotes.keys) {
          if(selectedNotes[selectedNote]) {
            project.copiedNotesVoices.add(selectedNote.voice);
            project.copiedNotes.add(selectedNote.toSerializable());
            earliestTime = min(earliestTime,selectedNote.startAtTime);

            if(cut) {
              selectedNote.voice.notes.remove(selectedNote);
            }
          }
        }

        for(final note in project.copiedNotes) {
          note.startAtTime -= earliestTime;
        }
      }
      else if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyV)) {
        // paste

        for(int idx = 0;idx < project.copiedNotes.length;idx++) {
          final note = project.copiedNotes[idx];
          final voice = project.copiedNotesVoices[idx];
          final cNote = MuonNoteController.fromSerializable(note);
          cNote.startAtTime = cNote.startAtTime + (project.playheadTime * project.timeUnitsPerBeat).floor();
          if(keyEvent.isShiftPressed) {
            if(project.currentVoiceID < project.voices.length) {
              project.voices[project.currentVoiceID].addNote(cNote);
            }
          }
          else {
            voice.addNote(cNote);
          }
        }
      }
    }

    if(keyEvent.isKeyPressed(LogicalKeyboardKey.delete)) {
      for(final selectedNote in selectedNotes.keys) {
        if(selectedNotes[selectedNote]) {
          selectedNote.voice.notes.remove(selectedNote);
        }
      }
    }
    else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      int moveBy = keyEvent.isShiftPressed ? 12 : 1;

      for(final selectedNote in selectedNotes.keys) {
        if(selectedNotes[selectedNote]) {
          selectedNote.addSemitones(moveBy);
        }
      }
    }
    else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      int moveBy = keyEvent.isShiftPressed ? -12 : -1;

      for(final selectedNote in selectedNotes.keys) {
        if(selectedNotes[selectedNote]) {
          selectedNote.addSemitones(moveBy);
        }
      }
    }
    else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
      int moveBy = keyEvent.isShiftPressed ? project.timeUnitsPerBeat : 1;

      for(final selectedNote in selectedNotes.keys) {
        if(selectedNotes[selectedNote]) {
          selectedNote.startAtTime = selectedNote.startAtTime + moveBy;
        }
      }
    }
    else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      int moveBy = keyEvent.isShiftPressed ? -project.timeUnitsPerBeat : -1;

      for(final selectedNote in selectedNotes.keys) {
        if(selectedNotes[selectedNote]) {
          selectedNote.startAtTime = max(0,selectedNote.startAtTime + moveBy);
        }
      }
    }
  }

  void paint(Canvas canvas, Size size) {
    final themeData = painter.themeData;
    final pixelsPerBeat = painter.pixelsPerBeat;
    final xScale = painter.xScale;
    final yScale = painter.yScale;

    for (final voice in project.voices) {
      final noteColor = voice.color;

      for (final note in voice.notes) {
        final noteRect = getNoteRect(note);

        if (selectedNotes.containsKey(note) && selectedNotes[note]) {
          final borderThickness = 10.0;
          if (themeData.brightness == Brightness.dark) {
            canvas.drawRect(noteRect, Paint()..color = Colors.white);
            canvas.drawRect(
                noteRect, Paint()..color = noteColor.withOpacity(0.75));
          } else {
            canvas.drawRect(
                noteRect, Paint()..color = noteColor.withOpacity(0.5));
          }

          canvas.drawRect(painter.deflateScaled(noteRect, borderThickness),
              Paint()..color = noteColor);
        } else {
          if (themeData.brightness == Brightness.light) {
            canvas.drawRect(noteRect, Paint()..color = noteColor);
          } else {
            canvas.drawRect(noteRect, Paint()..color = Colors.black);
            canvas.drawRect(
                noteRect, Paint()..color = noteColor.withOpacity(0.95));
          }
        }
      }
    }

    for (final voice in project.voices) {
      for (final note in voice.notes) {
        if (note.lyric != "") {
          TextSpan lyricSpan = new TextSpan(
              style: new TextStyle(
                  color: themeData.brightness == Brightness.light
                      ? Colors.grey[600]
                      : Colors.grey[300]),
              text: note.lyric);

          painter.drawTextAt(
            canvas,
            Offset(
              note.startAtTime * pixelsPerBeat / project.timeUnitsPerBeat +
                  10 / xScale,
              PianoRollPainter.pitchToYAxis(note) - 25 / yScale,
            ),
            20,
            lyricSpan,
          );
        }
      }
    }
  }
}
