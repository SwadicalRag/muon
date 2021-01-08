import 'dart:math';

import 'package:muon/actions/base.dart';
import 'package:muon/controllers/muonnote.dart';

String upDown(int val) {
  if(val >= 0) {
    return "up";
  }
  else {
    return "down";
  }
}

class MoveNoteAction extends MuonAction {
  String get title {
    if(otherNotes.isNotEmpty) {
      return "Move ${otherNotes.length} notes";
    }
    else {
      return "Move note";
    }
  }
  String get subtitle {
    if((fixedTimeDelta != 0) && (semitoneDelta != 0)) {
      return "${upDown(fixedTimeDelta)} ${fixedTimeDelta.abs()} time units and ${upDown(semitoneDelta)} ${semitoneDelta.abs()} semitones";
    }
    else if(timeDelta != 0) {
      return "${upDown(fixedTimeDelta)} ${fixedTimeDelta.abs()} time units";
    }
    else if(semitoneDelta != 0) {
      return "${upDown(semitoneDelta)} ${semitoneDelta.abs()} semitones";
    }

    return "by nothing";
  }

  final MuonNoteController baseNote;
  final List<MuonNoteController> otherNotes;
  final int timeDelta;
  final int semitoneDelta;

  int cachedProjectTimeUnitsPerBeat;

  int get fixedTimeDelta => ((timeDelta * baseNote.voice.project.timeUnitsPerBeat) ~/ cachedProjectTimeUnitsPerBeat);

  MoveNoteAction(this.baseNote,this.otherNotes,this.timeDelta,this.semitoneDelta) {
    cachedProjectTimeUnitsPerBeat = baseNote.voice.project.timeUnitsPerBeat;
  }

  void perform() {
    baseNote.startAtTime += fixedTimeDelta;
    baseNote.addSemitones(semitoneDelta);
    for(final note in otherNotes) {
      note.startAtTime += fixedTimeDelta;
      note.addSemitones(semitoneDelta);
    }
  }

  void undo() {
    baseNote.startAtTime = max(0,baseNote.startAtTime - fixedTimeDelta);
    baseNote.addSemitones(-semitoneDelta);
    for(final note in otherNotes) {
      note.startAtTime = max(0,note.startAtTime - fixedTimeDelta);
      note.addSemitones(-semitoneDelta);
    }
  }
}
