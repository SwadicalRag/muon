import "package:get/get.dart";
import "package:muon/controllers/muonvoice.dart";
import "package:muon/serializable/muon.dart";

class MuonNoteController extends GetxController {
  MuonVoiceController voice;

  /// The alphabetical value of this note
  /// `/[A-G]#?/`
  final note = "C".obs;

  /// The octave of this note
  final octave = 4.obs;

  /// Any lyrics attached to this note
  /// (can be an empty string!)
  final lyric = "".obs;

  /// The time at which this note starts
  final startAtTime = 0.obs;

  /// The duration of this note
  final duration = 0.obs;

  /// Adds `deltaSemitones` to this note
  /// 
  /// e.g. if this was a `C4`, adding `2` semitones gives you `D4`,
  /// and adding `-2` semitones gives you `A#3`
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
