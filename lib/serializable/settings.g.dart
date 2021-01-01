// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MuonSettings _$MuonSettingsFromJson(Map<String, dynamic> json) {
  return MuonSettings()
    ..darkMode = json['darkMode'] as bool
    ..neutrinoDir = json['neutrinoDir'] as String;
}

Map<String, dynamic> _$MuonSettingsToJson(MuonSettings instance) =>
    <String, dynamic>{
      'darkMode': instance.darkMode,
      'neutrinoDir': instance.neutrinoDir,
    };
