import 'package:muon/actions/base.dart';
import 'package:muon/controllers/muonnote.dart';

class CutNoteAction extends MuonAction {
  String get title {
    if(notes.length > 1) {
      return "Cut notes";
    }
    else {
      return "Cut note";
    }
  }
  String get subtitle {
    return "";
  }

  final List<MuonNoteController> notes;

  CutNoteAction(this.notes);

  void perform() {
    for(final note in notes) {
      note.voice.notes.remove(note);
    }
  }

  void undo() {
    for(final note in notes) {
      note.voice.addNoteInternal(note);
    }
  }
  
  void markVoiceModified() {
    for(final note in notes) {
      note.voice.hasChangedNoteData = true;
    }
  }
}
