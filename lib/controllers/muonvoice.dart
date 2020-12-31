import 'package:get/get.dart';
import 'package:muon/controllers/muonnote.dart';
import 'package:muon/controllers/muonproject.dart';
import 'package:muon/serializable/muon.dart';
import 'package:muon/logic/musicxml.dart';

class MuonVoiceController extends GetxController {
  MuonProjectController project;

  // voice metadata
  final modelName = "".obs;
  final randomiseTiming = false.obs;

  // notes
  final notes = RxList<MuonNoteController>([]);

  MusicXML exportVoiceToMusicXML() {
    return project.exportVoiceToMusicXML(this);
  }

  void sortNotesByTime() {
    notes.sort((a,b) => a.startAtTime.value.compareTo(b.startAtTime.value));
  }

  void addNote(MuonNoteController note) {
    note.voice = this;
    notes.add(note);
  }

  MuonVoice toSerializable([MuonProject project]) {
    final out = MuonVoice();
    out.project = project ?? this.project.toSerializable();
    out.modelName = this.modelName.value;
    out.randomiseTiming = this.randomiseTiming.value;
    for(final note in notes) {
      out.notes.add(note.toSerializable());
    }
    return out;
  }

  static MuonVoiceController fromSerializable(MuonVoice obj, [MuonProjectController project]) {
    final out = MuonVoiceController();
    out.project = project ?? MuonProjectController.fromSerializable(obj.project);
    out.modelName.value = obj.modelName;
    out.randomiseTiming.value = obj.randomiseTiming;
    for(final note in obj.notes) {
      out.addNote(MuonNoteController.fromSerializable(note));
    }
    return out;
  }
}
