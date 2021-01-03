import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muon/controllers/muonnote.dart';
import 'package:muon/controllers/muonproject.dart';
import 'package:muon/serializable/muon.dart';
import 'package:muon/serializable/settings.dart';
import 'package:muon/logic/musicxml.dart';
import 'package:flutter_audio_desktop/flutter_audio_desktop.dart';
import 'package:path/path.dart' as p;

String getRawProgramPath(String programName) {
  return getMuonSettings().neutrinoDir + "/" + programName;
}

String getProgramPath(String programName) {
  String out = getMuonSettings().neutrinoDir + "/bin/" + programName;

  if(Platform.isWindows) {
    out += ".exe";
  }

  return out;
}

List<String> getAllVoiceModels() {
  final List<String> items = [];

  final modelsDir = Directory(getRawProgramPath("model"));
  final modelsDirFiles = modelsDir.listSync();

  for(final modelsDirFile in modelsDirFiles) {
    if(modelsDirFile is Directory) {
      final modelName = p.relative(modelsDirFile.path,from: modelsDir.path);
      items.add(modelName);
    }
  }

  items.sort();

  return items;
}

String getDefaultVoiceModel() {
  final models = getAllVoiceModels();
  if(models.length == 0) {return "";}
  return models[0];
}

class MuonVoiceController extends GetxController {
  MuonProjectController project;

  // voice metadata
  final modelName = getDefaultVoiceModel().obs;
  final randomiseTiming = false.obs;

  // notes
  final notes = RxList<MuonNoteController>([]);

  MusicXML exportVoiceToMusicXML() {
    return project.exportVoiceToMusicXML(this);
  }

  void sortNotesByTime() {
    notes.sort((a,b) => a.startAtTime.value.compareTo(b.startAtTime.value));
  }

  void addNote(MuonNoteController note) {
    note.voice = this;
    notes.add(note);
  }

  static final noteColors = [
    Colors.blue,
    Colors.purple,
    Colors.amber,
    Colors.indigo,
    Colors.green,
    Colors.teal,
    Colors.brown,
  ];
  get color {
    final voiceID = (project != null ? project.voices.indexOf(this) : -1) + 1;
    return noteColors[voiceID % noteColors.length];
  }

  String get voiceFileName => project.projectFileNameNoExt + "_" + project.voices.indexOf(this).toString() + "_voice";

  Future<void> makeLabels() async {
    final musicXML = exportVoiceToMusicXML();
    final musicXMLString = serializeMusicXML(musicXML);

    if(!Directory(project.getProjectFilePath("musicxml/")).existsSync()) {
      Directory(project.getProjectFilePath("musicxml/")).createSync();
    }

    if(!Directory(project.getProjectFilePath("label/")).existsSync()) {
      Directory(project.getProjectFilePath("label/")).createSync();
    }

    if(!Directory(project.getProjectFilePath("label/full/")).existsSync()) {
      Directory(project.getProjectFilePath("label/full/")).createSync();
    }

    if(!Directory(project.getProjectFilePath("label/mono/")).existsSync()) {
      Directory(project.getProjectFilePath("label/mono/")).createSync();
    }

    final musicXMLPath = project.getProjectFilePath("musicxml/" + voiceFileName + ".musicxml");

    File(musicXMLPath)
      .writeAsStringSync(musicXMLString);

    await Process.run(getProgramPath("musicXMLtoLabel"), [
      musicXMLPath,
      project.getProjectFilePath("label/full/" + voiceFileName + ".lab"),
      project.getProjectFilePath("label/mono/" + voiceFileName + ".lab"),
      "-x",
      getRawProgramPath("settings/dic"),
    ]).then((ProcessResult results) {
      print(results.stdout);
    });
  }

  Future<void> runNeutrino() async {
    if(!Directory(project.getProjectFilePath("neutrino/")).existsSync()) {
      Directory(project.getProjectFilePath("neutrino/")).createSync();
    }

    if(!Directory(project.getProjectFilePath("label/timing/")).existsSync()) {
      Directory(project.getProjectFilePath("label/timing/")).createSync();
    }

    print(getRawProgramPath("label/timing/" + voiceFileName + ".lab"));
    await Process.run(getProgramPath("NEUTRINO"), [
      project.getProjectFilePath("label/full/" + voiceFileName + ".lab"),
      project.getProjectFilePath("label/timing/" + voiceFileName + ".lab"),
      project.getProjectFilePath("neutrino/" + voiceFileName + ".f0"),
      project.getProjectFilePath("neutrino/" + voiceFileName + ".mgc"),
      project.getProjectFilePath("neutrino/" + voiceFileName + ".bap"),
      getRawProgramPath("model/" + modelName.value + "/"),
      "-n","8",
      "-k","0",
      "-m",
      "-t",
    ]).then((ProcessResult results) {
      print(results.stdout);
    });
  }

  Future<void> vocodeWORLD() async {
    if(!Directory(project.getProjectFilePath("audio/")).existsSync()) {
      Directory(project.getProjectFilePath("audio/")).createSync();
    }

    print(getRawProgramPath("model/" + (modelName.value) + "/"));
    await Process.run(getProgramPath("WORLD"), [
      project.getProjectFilePath("neutrino/" + voiceFileName + ".f0"),
      project.getProjectFilePath("neutrino/" + voiceFileName + ".mgc"),
      project.getProjectFilePath("neutrino/" + voiceFileName + ".bap"),
      "-f","1.0",
      "-m","1.0",
      "-o",project.getProjectFilePath("audio/" + voiceFileName + "_world.wav"),
      "-n","8",
      "-t",
    ]).then((ProcessResult results) {
      print(results.stdout);
    });
  }

  Future<void> vocodeNSF() async {
    if(!Directory(project.getProjectFilePath("audio/")).existsSync()) {
      Directory(project.getProjectFilePath("audio/")).createSync();
    }

    print(getRawProgramPath("model/" + (modelName.value) + "/"));
    await Process.run(getProgramPath("NSF_IO"), [
      project.getProjectFilePath("label/full/" + voiceFileName + ".lab"),
      project.getProjectFilePath("label/timing/" + voiceFileName + ".lab"),
      project.getProjectFilePath("neutrino/" + voiceFileName + ".f0"),
      project.getProjectFilePath("neutrino/" + voiceFileName + ".mgc"),
      project.getProjectFilePath("neutrino/" + voiceFileName + ".bap"),
      modelName.value,
      project.getProjectFilePath("audio/" + voiceFileName + "_nsf.wav"),
      "-t",
    ],workingDirectory: getRawProgramPath("")).then((ProcessResult results) {
      print(results.stdout);
    });
  }

  AudioPlayer audioPlayer;
  int audioPlayerDuration = 0;
  Future<AudioPlayer> getAudioPlayer([Duration playPos]) async {
    final voiceID = project.voices.indexOf(this);
    if(audioPlayer == null) {
      audioPlayer = new AudioPlayer(id: voiceID);
    }

    await audioPlayer.unload();
    final suc = await audioPlayer.load(project.getProjectFilePath("audio/" + voiceFileName + "_world.wav"));

    audioPlayerDuration = (await audioPlayer.getDuration()).inMilliseconds;
    audioPlayer.setPosition(playPos ?? Duration(seconds: 2));

    if(!suc) {
      audioPlayer = null;
    }

    return audioPlayer;
  }

  MuonVoice toSerializable([MuonProject project]) {
    final out = MuonVoice();
    out.project = project ?? this.project.toSerializable();
    out.modelName = this.modelName.value;
    out.randomiseTiming = this.randomiseTiming.value;
    for(final note in notes) {
      out.notes.add(note.toSerializable());
    }
    return out;
  }

  static MuonVoiceController fromSerializable(MuonVoice obj, [MuonProjectController project]) {
    final out = MuonVoiceController();
    out.project = project ?? MuonProjectController.fromSerializable(obj.project);
    out.modelName.value = obj.modelName;
    out.randomiseTiming.value = obj.randomiseTiming;
    for(final note in obj.notes) {
      out.addNote(MuonNoteController.fromSerializable(note));
    }
    return out;
  }
}
