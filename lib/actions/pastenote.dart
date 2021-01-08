import 'package:muon/actions/base.dart';
import 'package:muon/controllers/muonnote.dart';
import 'package:muon/controllers/muonvoice.dart';

class PasteNoteAction extends MuonAction {
  String get title {
    if(notes.length > 1) {
      return "Paste notes";
    }
    else {
      return "Paste note";
    }
  }
  String get subtitle {
    return "";
  }

  final List<MuonNoteController> notes;

  PasteNoteAction(this.notes);

  void perform() {
    for(final note in notes) {
      note.voice.addNoteInternal(note);
    }
  }

  void undo() {
    for(final note in notes) {
      note.voice.notes.remove(note);
    }
  }
  
  void markVoiceModified() {
    for(final note in notes) {
      note.voice.hasChangedNoteData = true;
    }
  }
}
