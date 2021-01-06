import 'package:muon/serializable/settings.dart';
import "package:synaps_flutter/synaps_flutter.dart";

part "settings.g.dart";

@Controller()
class MuonSettingsController {
  bool _darkModeInternal = getMuonSettings().darkMode;

  @Observable()
  bool get darkMode {
    return _darkModeInternal;
  }

  set darkMode(bool value) {
    final settings = getMuonSettings();

    settings.darkMode = value;
    _darkModeInternal = value;

    settings.save();
  }
}
