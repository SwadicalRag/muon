import 'dart:math';

import 'package:muon/actions/base.dart';
import 'package:muon/controllers/muonnote.dart';

class RetimeNoteAction extends MuonAction {
  String get title {
    if(durationDeltaMax > 0) {
      if(notes.isNotEmpty) {
        return "Lengthen ${notes.length} notes";
      }
      else {
        return "Lengthen note";
      }
    }
    else {
      if(notes.isNotEmpty) {
        return "Shorten ${notes.length} notes";
      }
      else {
        return "Shorten note";
      }
    }
  }
  String get subtitle {
    if(durationDeltaMax != 0) {
      return "by ${fixTimeDelta(durationDeltaMax).abs()} time units";
    }

    return "by nothing";
  }

  final List<MuonNoteController> notes;
  final List<int> durationDelta;

  int get durationDeltaMax => durationDelta.reduce(max);

  int cachedProjectTimeUnitsPerBeat;

  int fixTimeDelta(int timeDelta) => ((timeDelta * notes.first.voice.project.timeUnitsPerBeat) ~/ cachedProjectTimeUnitsPerBeat);

  RetimeNoteAction(this.notes,this.durationDelta) {
    assert(this.notes.isNotEmpty);
    assert(this.notes.length == this.durationDelta.length);
    cachedProjectTimeUnitsPerBeat = notes.first.voice.project.timeUnitsPerBeat;
  }

  void perform() {
    for(int i=0;i < notes.length;i++) {
      final note = notes[i];
      note.duration += fixTimeDelta(durationDelta[i]);
    }
  }

  void undo() {
    for(int i=0;i < notes.length;i++) {
      final note = notes[i];
      note.duration = max(0,note.duration - fixTimeDelta(durationDelta[i]));
    }
  }
  
  void markVoiceModified() {
    for(final note in notes) {
      note.voice.hasChangedNoteData = true;
    }
  }
}
