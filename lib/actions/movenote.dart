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
    if(notes.length > 1) {
      return "Move ${notes.length} notes";
    }
    else {
      return "Move note";
    }
  }
  String get subtitle {
    final fixedTimeDelta = fixTimeDelta(timeDeltaMax);
    if((fixedTimeDelta != 0) && (semitoneDeltaMax != 0)) {
      return "${upDown(fixedTimeDelta)} ${fixedTimeDelta.abs()} time units and ${upDown(semitoneDeltaMax)} ${semitoneDeltaMax.abs()} semitones";
    }
    else if(timeDeltaMax != 0) {
      return "${upDown(fixedTimeDelta)} ${fixedTimeDelta.abs()} time units";
    }
    else if(semitoneDeltaMax != 0) {
      return "${upDown(semitoneDeltaMax)} ${semitoneDeltaMax.abs()} semitones";
    }

    return "by nothing";
  }

  final List<MuonNoteController> notes;
  final List<int> timeDelta;
  final List<int> semitoneDelta;

  int get timeDeltaMax => timeDelta.reduce(max);
  int get semitoneDeltaMax => semitoneDelta.reduce(max);

  int cachedProjectTimeUnitsPerBeat;

  int fixTimeDelta(int timeDelta) => ((timeDelta * notes.first.voice.project.timeUnitsPerBeat) ~/ cachedProjectTimeUnitsPerBeat);

  MoveNoteAction(this.notes,this.timeDelta,this.semitoneDelta) {
    assert(this.notes.isNotEmpty);
    cachedProjectTimeUnitsPerBeat = notes.first.voice.project.timeUnitsPerBeat;
  }

  void perform() {
    for(int i=0;i < notes.length;i++) {
      final note = notes[i];
      note.startAtTime += fixTimeDelta(timeDelta[i]);
      note.addSemitones(semitoneDelta[i]);
    }
  }

  void undo() {
    for(int i=0;i < notes.length;i++) {
      final note = notes[i];
      note.startAtTime = max(0,note.startAtTime - fixTimeDelta(timeDelta[i]));
      note.addSemitones(-semitoneDelta[i]);
    }
  }
  
  void markVoiceModified() {
    for(final note in notes) {
      note.voice.hasChangedNoteData = true;
    }
  }
}
