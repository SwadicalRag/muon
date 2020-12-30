import 'package:get/get.dart';
import 'package:muon/serializable/muon.dart';

class MuonNoteController extends GetxController {
  final note = "C".obs;
  final octave = 4.obs;
  final lyric = "".obs;

  // timing
  final startAtTime = 0.obs;
  final duration = 0.obs;

  MuonNote toSerializable() {
    final out = MuonNote();
    out.note = this.note.value;
    out.octave = this.octave.value;
    out.lyric = this.lyric.value;
    out.startAtTime = this.startAtTime.value;
    out.duration = this.duration.value;
    return out;
  }

  static MuonNoteController fromSerializable(MuonNote obj) {
    final out = MuonNoteController();
    out.note.value = obj.note;
    out.octave.value = obj.octave;
    out.lyric.value = obj.lyric;
    out.startAtTime.value = obj.startAtTime;
    out.duration.value = obj.duration;
    return out;
  }
}
