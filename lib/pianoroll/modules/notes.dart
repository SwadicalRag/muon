import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:muon/actions/deletenote.dart';
import 'package:muon/actions/movenote.dart';
import 'package:muon/actions/pastenote.dart';
import 'package:muon/actions/renamenote.dart';
import 'package:muon/actions/retimenote.dart';
import 'package:muon/controllers/muonnote.dart';
import 'package:muon/controllers/muonvoice.dart';
import 'package:muon/editor.dart';
import 'package:muon/helpers.dart';
import 'package:muon/logic/japanese.dart';
import 'package:muon/pianoroll/pianoroll.dart';
import 'package:muon/serializable/muon.dart';
import 'package:synaps_flutter/synaps_flutter.dart';

int _toAbsoluteSemitones(String note, int octave) {
  const midiNotes = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];

  final currentNoteID = midiNotes.indexOf(note);
  
  return octave * 12 + currentNoteID;
}

class PianoRollNotesModule extends PianoRollModule {
  final SynapsMap<MuonNoteController, bool> selectedNotes;

  MuonNoteController _internalDragFirstNote;
  Map<MuonNoteController, MuonNote> noteDragOriginalData;

  PianoRollNotesModule({
    @required this.selectedNotes,
  }) : super();

  List<MuonNoteController> getSelectedNotesAsList() {
    final otherNotes = <MuonNoteController>[];
    for(final selectedNote in selectedNotes.keys) {
      if(selectedNotes[selectedNote]) {
        otherNotes.add(selectedNote);
      }
    }
    return otherNotes;
  }

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

      if(cursorBeatEndDistance < 15) {
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

        String lastInput = "";
        final newNoteLyrics = <MuonNoteController,String>{};

        showMenu<void>(
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
                  lastInput = hiraganaList.join("");

                  newNoteLyrics.clear();

                  final curNotePos = noteAtCursor.voice.notes.indexOf(noteAtCursor);
                  for(int i=curNotePos;i < noteAtCursor.voice.notes.length;i++) {
                    if((i - curNotePos) < hiraganaList.length) {
                      if(!editHistory.containsKey(i)) {
                        editHistory[i] = noteAtCursor.voice.notes[i].lyric;
                      }
                      noteAtCursor.voice.notes[i].lyric = hiraganaList[i - curNotePos];
                      newNoteLyrics[noteAtCursor.voice.notes[i]] = hiraganaList[i - curNotePos];
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
        ).then((_) {
          final originalNoteLyrics = <MuonNoteController,String>{};

          for(final editedNote in newNoteLyrics.keys) {
            final notePos = noteAtCursor.voice.notes.indexOf(editedNote);
            originalNoteLyrics[editedNote] = editHistory[notePos] ?? newNoteLyrics[editedNote];
          }

          final action = RenameNoteAction(newNoteLyrics, originalNoteLyrics, lastInput);

          project.addAction(action);
        });
      }
      else {
        if(project.voices.length > project.currentVoiceID) {
          MuonVoiceController voice = project.voices[project.currentVoiceID];
          var note = MuonNoteController().ctx();
          var pitch = painter.getPitchAtCursor(mousePos.y);
          note.octave = pitch.octave;
          note.note = pitch.note;
          note.startAtTime = (painter.getBeatNumAtCursor(mousePos.x) * project.timeUnitsPerBeat).floor();
          note.startAtTime = floorToModulus(note.startAtTime, project.timeUnitsPerSubdivision);
          note.duration = project.timeUnitsPerSubdivision;
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

    bool resizeMode = cursorBeatEndDistance < 15;

    final mousePitch = painter.getPitchAtCursor(mousePos.y);
    final deltaSemiTones = _toAbsoluteSemitones(mousePitch.note,mousePitch.octave) - _toAbsoluteSemitones(originalFirstNote.note,originalFirstNote.octave);

    final mouseBeatNum = max(0, painter.getBeatNumAtCursor(mousePos.x));
    final mouseBeatSubDivNum =
        ((mouseBeatNum * project.timeUnitsPerBeat) ~/ project.timeUnitsPerSubdivision);
    final originalMouseBeatNum = max(0, painter.getBeatNumAtCursor(mouseStartPos.x));
    final originalMouseBeatSubDivNum =
        ((originalMouseBeatNum * project.timeUnitsPerBeat) ~/ project.timeUnitsPerSubdivision);
    
    final deltaSubDiv = mouseBeatSubDivNum - originalMouseBeatSubDivNum;
    final deltaSegments = deltaSubDiv * project.timeUnitsPerSubdivision;

    var resizeDelta = deltaSegments;
    if(state.isShiftKeyHeld) {
      resizeDelta = deltaSegments + project.timeUnitsPerSubdivision;
    }

    for(final selectedNote in selectedNotes.keys) {
      if(selectedNotes[selectedNote]) {
        if(noteDragOriginalData[selectedNote] != null) {
          if(resizeMode) {
            selectedNote.duration = noteDragOriginalData[selectedNote].duration + resizeDelta;
            if(state.isShiftKeyHeld) {
              selectedNote.duration = max(project.timeUnitsPerSubdivision,floorToModulus(selectedNote.duration, project.timeUnitsPerSubdivision));
            }
          }
          else {
            selectedNote.startAtTime = max(0,noteDragOriginalData[selectedNote].startAtTime + deltaSegments);
            if(state.isShiftKeyHeld) {
              selectedNote.startAtTime = floorToModulus(selectedNote.startAtTime, project.timeUnitsPerSubdivision);
            }
            
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
    if(_internalDragFirstNote != null) {
      final originalNoteData = noteDragOriginalData[_internalDragFirstNote];

      final timeDelta = _internalDragFirstNote.startAtTime - originalNoteData.startAtTime;
      final semitoneDelta = _internalDragFirstNote.toAbsoluteSemitones() - _toAbsoluteSemitones(originalNoteData.note,originalNoteData.octave);
      if((timeDelta != 0) || (semitoneDelta != 0)) {
        final otherNotes = getSelectedNotesAsList();
        otherNotes.remove(_internalDragFirstNote);
        final action = MoveNoteAction(_internalDragFirstNote,otherNotes,timeDelta,semitoneDelta);

        project.addAction(action);
      }
      else {
        final durationDelta = _internalDragFirstNote.duration - originalNoteData.duration;

        if(durationDelta != 0) {
        final otherNotes = getSelectedNotesAsList();
        otherNotes.remove(_internalDragFirstNote);
          final action = RetimeNoteAction(_internalDragFirstNote,otherNotes,durationDelta);

          project.addAction(action);
        }
      }
    }

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

        final listNotes = <MuonNoteController>[];

        for(int idx = 0;idx < project.copiedNotes.length;idx++) {
          final note = project.copiedNotes[idx];
          final voice = project.copiedNotesVoices[idx];
          final cNote = MuonNoteController.fromSerializable(note);
          listNotes.add(cNote);
          cNote.startAtTime = cNote.startAtTime + (project.playheadTime * project.timeUnitsPerBeat).floor();
          if(keyEvent.isShiftPressed) {
            if(project.currentVoiceID < project.voices.length) {
              project.voices[project.currentVoiceID].addNoteInternal(cNote);
            }
          }
          else {
            voice.addNoteInternal(cNote);
          }
        }

        if(listNotes.isNotEmpty) {
          final action = PasteNoteAction(listNotes);

          project.addAction(action);
        }
      }
    }

    if(keyEvent.isKeyPressed(LogicalKeyboardKey.delete)) {
      for(final selectedNote in selectedNotes.keys) {
        if(selectedNotes[selectedNote]) {
          selectedNote.voice.notes.remove(selectedNote);
        }
      }

      final action = DeleteNoteAction(getSelectedNotesAsList());
      project.addAction(action);

      selectedNotes.clear();
    }
    else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
      int moveBy = keyEvent.isShiftPressed ? 12 : 1;

      MuonNoteController lastNote;
      for(final selectedNote in selectedNotes.keys) {
        if(selectedNotes[selectedNote]) {
          selectedNote.addSemitones(moveBy);
          lastNote = selectedNote;
        }
      }
      
      if(lastNote != null) {
        final otherNotes = getSelectedNotesAsList();
        otherNotes.remove(lastNote);
        final action = MoveNoteAction(lastNote,otherNotes,0,moveBy);

        project.addAction(action);
      }
    }
    else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
      int moveBy = keyEvent.isShiftPressed ? -12 : -1;

      MuonNoteController lastNote;
      for(final selectedNote in selectedNotes.keys) {
        if(selectedNotes[selectedNote]) {
          selectedNote.addSemitones(moveBy);
          lastNote = selectedNote;
        }
      }
      
      if(lastNote != null) {
        final otherNotes = getSelectedNotesAsList();
        otherNotes.remove(lastNote);
        final action = MoveNoteAction(lastNote,otherNotes,0,moveBy);

        project.addAction(action);
      }
    }
    else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
      int moveBy = keyEvent.isShiftPressed ? project.timeUnitsPerBeat : project.timeUnitsPerSubdivision;

      MuonNoteController lastNote;
      for(final selectedNote in selectedNotes.keys) {
        if(selectedNotes[selectedNote]) {
          selectedNote.startAtTime = selectedNote.startAtTime + moveBy;
          lastNote = selectedNote;
        }
      }
      
      if(lastNote != null) {
        final otherNotes = getSelectedNotesAsList();
        otherNotes.remove(lastNote);
        final action = MoveNoteAction(lastNote,otherNotes,moveBy,0);

        project.addAction(action);
      }
    }
    else if(keyEvent.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
      int moveBy = keyEvent.isShiftPressed ? -project.timeUnitsPerBeat : -project.timeUnitsPerSubdivision;

      MuonNoteController lastNote;
      for(final selectedNote in selectedNotes.keys) {
        if(selectedNotes[selectedNote]) {
          selectedNote.startAtTime = max(0,selectedNote.startAtTime + moveBy);
          lastNote = selectedNote;
        }
      }
      
      if(lastNote != null) {
        final otherNotes = getSelectedNotesAsList();
        otherNotes.remove(lastNote);
        final action = MoveNoteAction(lastNote,otherNotes,moveBy,0);

        project.addAction(action);
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
