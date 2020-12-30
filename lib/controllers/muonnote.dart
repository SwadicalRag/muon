import 'package:get/get.dart';
import 'package:muon/serializable/muon.dart';

class MuonNoteController extends GetxController {
  final note = "C".obs;
  final octave = 4.obs;
  final lyric = "".obs;

  // timing
  final startAtTime = 0.obs;
  final duration = 0.obs;

  void addSemitones(int deltaSemitones) {
    final midiNotes = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];

    final currentNoteID = midiNotes.indexOf(this.note.value);
    final deltaOctave = ((deltaSemitones + currentNoteID) / 12).floor();
    final fixedDeltaSemitones = deltaSemitones - deltaOctave * 12;
    
    note.value = midiNotes[currentNoteID + fixedDeltaSemitones];
    octave.value = octave.value + deltaOctave;
  }

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
