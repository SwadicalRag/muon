import 'dart:convert';
import 'dart:io';

import 'package:json_annotation/json_annotation.dart';

part 'settings.g.dart';

@JsonSerializable(nullable: false)
class MuonSettings {
  MuonSettings();

  bool darkMode = false;
  String neutrinoDir = "";

  factory MuonSettings.fromJson(Map<String, dynamic> json) => _$MuonSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$MuonSettingsToJson(this);

  static MuonSettings loadFromFile([String settingsFile = "muon_settings.json"]) {
    if(File(settingsFile).existsSync()) {
      final file = new File(settingsFile);

      if(file.existsSync()) {
        var fileContents = file.readAsStringSync();

        final jsonData = jsonDecode(fileContents);
        MuonSettings settings = MuonSettings.fromJson(jsonData);

        return settings;
      }
    }

    return null;
  }

  void save([String settingsFile = "muon_settings.json"]) {
    final jsonContents = this.toJson();
    String fileContents = jsonEncode(jsonContents);

    final file = new File(settingsFile);
    file.writeAsStringSync(fileContents);
  }
}

MuonSettings getMuonSettings() {
  var settings = MuonSettings.loadFromFile();

  if(settings == null) {
    return MuonSettings();
  }

  return settings;
}
