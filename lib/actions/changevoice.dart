import 'package:muon/actions/base.dart';
import 'package:muon/controllers/muonvoice.dart';

class ChangeVoiceAction extends MuonAction {
  String get title {
    return "Change voice";
  }
  String get subtitle {
    return "to $newVoiceModel";
  }

  final MuonVoiceController voice;
  final String newVoiceModel;
  final String oldVoiceModel;

  ChangeVoiceAction(this.voice,this.newVoiceModel,this.oldVoiceModel);

  void perform() {
    voice.modelName = newVoiceModel;
  }

  void undo() {
    voice.modelName = oldVoiceModel;
  }
}
