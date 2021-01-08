import 'package:muon/actions/base.dart';
import 'package:muon/controllers/muonnote.dart';
import 'package:muon/controllers/muonvoice.dart';

class AddNoteAction extends MuonAction {
  String get title {
    return "Add note";
  }
  String get subtitle {
    return "";
  }

  final MuonNoteController note;

  AddNoteAction(this.note);

  void perform() {
    note.voice.addNoteInternal(note);
  }

  void undo() {
    note.voice.notes.remove(note);
  }
}
