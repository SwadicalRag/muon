import 'package:muon/actions/base.dart';
import 'package:muon/controllers/muonnote.dart';
import 'package:muon/controllers/muonvoice.dart';

class DeleteNoteAction extends MuonAction {
  String get title {
    if(notes.length > 1) {
      return "Delete notes";
    }
    else {
      return "Delete note";
    }
  }
  String get subtitle {
    return "";
  }

  final List<MuonNoteController> notes;

  DeleteNoteAction(this.notes);

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
}
