import "dart:convert";
import "dart:io";

import "package:json_annotation/json_annotation.dart";
import "package:muon/controllers/muonproject.dart";
import "package:path/path.dart" as p;

part "muon.g.dart";

@JsonSerializable(nullable: false)
class MuonNote {
  MuonNote();

  String note;
  int octave;
  String lyric;

  // timing
  int startAtTime;
  int duration;

  factory MuonNote.fromJson(Map<String, dynamic> json) => _$MuonNoteFromJson(json);
  Map<String, dynamic> toJson() => _$MuonNoteToJson(this);
}

@JsonSerializable(nullable: false)
class MuonVoice {
  MuonVoice();

  @JsonKey(ignore: true)
  MuonProject project;

  // voice metadata
  String modelName;
  bool randomiseTiming = false;

  // notes
  List<MuonNote> notes = [];

  // synthesised data
  // TODO: F0, Aperiodicity, Spectral Envelope

  factory MuonVoice.fromJson(Map<String, dynamic> json) => _$MuonVoiceFromJson(json);
  Map<String, dynamic> toJson() => _$MuonVoiceToJson(this);
}

@JsonSerializable(nullable: false)
class MuonProject {
  MuonProject();

  // project metadata
  @JsonKey(ignore: true)
  String projectDir;

  // project metadata
  @JsonKey(ignore: true)
  String projectFileName;

  // tempo
  double bpm = 120;
  int timeUnitsPerBeat = 1;

  // time signature
  int beatsPerMeasure = 4;
  int beatValue = 4;

  List<MuonVoice> voices = [];

  factory MuonProject.fromJson(Map<String, dynamic> json) => _$MuonProjectFromJson(json);
  Map<String, dynamic> toJson() => _$MuonProjectToJson(this);

  static MuonProject loadFromFile(String projectFile) {
    if(File(projectFile).existsSync()) {
      final file = new File(projectFile);

      if(file.existsSync()) {
        var fileContents = file.readAsStringSync();

        final jsonData = jsonDecode(fileContents);
        MuonProject project = MuonProject.fromJson(jsonData);

        for(final voice in project.voices) {
          voice.project = project;
        }

        project.projectDir = p.dirname(projectFile);
        project.projectFileName = p.basename(projectFile);

        return project;
      }
    }

    return null;
  }

  static MuonProject loadFromDir(String projectDir,String projectFileName) {
    if(Directory(projectDir).existsSync()) {
      return MuonProject.loadFromFile(projectDir + "/" + projectFileName);
    }

    return null;
  }

  void save() {
    if(!Directory(projectDir).existsSync()) {
      Directory(projectDir).createSync();
    }

    final jsonContents = this.toJson();
    String fileContents = jsonEncode(jsonContents);

    final file = new File(projectDir + "/" + projectFileName);
    file.writeAsStringSync(fileContents);
  }
}
