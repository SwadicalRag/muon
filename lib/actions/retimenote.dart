import 'dart:math';

import 'package:muon/actions/base.dart';
import 'package:muon/controllers/muonnote.dart';

class RetimeNoteAction extends MuonAction {
  String get title {
    if(timeDelta > 0) {
      if(otherNotes.isNotEmpty) {
        return "Lengthen ${otherNotes.length} notes";
      }
      else {
        return "Lengthen note";
      }
    }
    else {
      if(otherNotes.isNotEmpty) {
        return "Shorten ${otherNotes.length} notes";
      }
      else {
        return "Shorten note";
      }
    }
  }
  String get subtitle {
    if(timeDelta != 0) {
      return "by ${fixedTimeDelta.abs()} time units";
    }

    return "by nothing";
  }

  final MuonNoteController baseNote;
  final List<MuonNoteController> otherNotes;
  final int timeDelta;

  int cachedProjectTimeUnitsPerBeat;

  int get fixedTimeDelta => ((timeDelta * baseNote.voice.project.timeUnitsPerBeat) ~/ cachedProjectTimeUnitsPerBeat);

  RetimeNoteAction(this.baseNote,this.otherNotes,this.timeDelta) {
    cachedProjectTimeUnitsPerBeat = baseNote.voice.project.timeUnitsPerBeat;
  }

  void perform() {
    baseNote.duration += fixedTimeDelta;
    for(final note in otherNotes) {
      note.duration += fixedTimeDelta;
    }
  }

  void undo() {
    baseNote.duration = max(0,baseNote.duration - fixedTimeDelta);
    for(final note in otherNotes) {
      note.duration = max(0,note.duration - fixedTimeDelta);
    }
  }
}
