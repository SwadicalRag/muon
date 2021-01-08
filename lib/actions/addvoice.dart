import 'package:muon/actions/base.dart';
import 'package:muon/controllers/muonvoice.dart';

class AddVoiceAction extends MuonAction {
  String get title {
    return "Add voice";
  }
  String get subtitle {
    return "";
  }

  final MuonVoiceController voice;

  AddVoiceAction(this.voice);

  void perform() {
    voice.project.addVoiceInternal(voice);
  }

  void undo() {
    final currentID = voice.project.voices.indexOf(voice);
    if(currentID >= voice.project.currentVoiceID) {
      voice.project.currentVoiceID--;
    }
    if(voice.audioPlayer != null) {
      voice.audioPlayer.dispose();
      voice.audioPlayer = null;
    }
    voice.project.voices.remove(voice);
  }
}
