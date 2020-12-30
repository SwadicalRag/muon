// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'muon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MuonNote _$MuonNoteFromJson(Map<String, dynamic> json) {
  return MuonNote()
    ..note = json['note'] as String
    ..octave = json['octave'] as int
    ..lyric = json['lyric'] as String
    ..startAtTime = json['startAtTime'] as int
    ..duration = json['duration'] as int;
}

Map<String, dynamic> _$MuonNoteToJson(MuonNote instance) => <String, dynamic>{
      'note': instance.note,
      'octave': instance.octave,
      'lyric': instance.lyric,
      'startAtTime': instance.startAtTime,
      'duration': instance.duration,
    };

MuonVoice _$MuonVoiceFromJson(Map<String, dynamic> json) {
  return MuonVoice()
    ..modelName = json['modelName'] as String
    ..randomiseTiming = json['randomiseTiming'] as bool
    ..notes = (json['notes'] as List)
        .map((e) => MuonNote.fromJson(e as Map<String, dynamic>))
        .toList();
}

Map<String, dynamic> _$MuonVoiceToJson(MuonVoice instance) => <String, dynamic>{
      'modelName': instance.modelName,
      'randomiseTiming': instance.randomiseTiming,
      'notes': instance.notes,
    };

MuonProject _$MuonProjectFromJson(Map<String, dynamic> json) {
  return MuonProject()
    ..bpm = (json['bpm'] as num).toDouble()
    ..timeUnitsPerBeat = json['timeUnitsPerBeat'] as int
    ..beatsPerMeasure = json['beatsPerMeasure'] as int
    ..beatValue = json['beatValue'] as int
    ..voices = (json['voices'] as List)
        .map((e) => MuonVoice.fromJson(e as Map<String, dynamic>))
        .toList();
}

Map<String, dynamic> _$MuonProjectToJson(MuonProject instance) =>
    <String, dynamic>{
      'bpm': instance.bpm,
      'timeUnitsPerBeat': instance.timeUnitsPerBeat,
      'beatsPerMeasure': instance.beatsPerMeasure,
      'beatValue': instance.beatValue,
      'voices': instance.voices,
    };
