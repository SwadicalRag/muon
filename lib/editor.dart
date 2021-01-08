
import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:muon/controllers/muonnote.dart";
import "package:muon/controllers/muonproject.dart";
import "package:muon/controllers/muonvoice.dart";
import "package:muon/logic/japanese.dart";
import 'package:muon/pianoroll/modules/notes.dart';
import 'package:muon/pianoroll/modules/waila.dart';
import "package:muon/pianoroll/pianoroll.dart";
import "package:muon/serializable/settings.dart";
import "package:file_selector_platform_interface/file_selector_platform_interface.dart";
import 'package:muon/widgets/dialogs/firsttimesetup.dart';
import 'package:muon/widgets/dialogs/welcome.dart';
import 'package:muon/widgets/overlay/appbar.dart';
import 'package:muon/widgets/overlay/sidebar.dart';
import "package:path/path.dart" as p;

final currentProject = MuonProjectController.defaultProject();

class MuonEditor extends StatefulWidget {
  MuonEditor() : super();

  /// Shows the welcome screen via [showDialog]
  static void showWelcomeScreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext subContext) {
        return MuonWelcomeDialog();
      },
    );
  }

  /// Shows the first time setup screen via [showDialog]
  static void performFirstTimeSetup(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext subContext) {
        return MuonFirstTimeSetupDialog();
      },
    );
  }

  /// Opens a file selector dialog and prompts the user to open
  /// a project.json file
  static Future openProject(BuildContext context) {
    return FileSelectorPlatform.instance.openFile(
      confirmButtonText: "Open Project",
      acceptedTypeGroups: [XTypeGroup(
        label: "Muon Project Files",
        extensions: ["json"],
      )],
    )
    .then((value) {
      if(value != null) {
        final proj = MuonProjectController.loadFromFile(value.path);
        currentProject.updateWith(proj);

        return true;
      }
    })
    .catchError((err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).errorColor,
          content: new Text("internal error: " + err.toString()),
          duration: new Duration(seconds: 10),
        )
      );
    }); // oh wow i am so naughty
  }

  /// Opens a file selector dialog and prompts the user to create
  /// a project.json file
  static Future createNewProject() {
    return FileSelectorPlatform.instance.getSavePath(
      confirmButtonText: "Create Project",
      acceptedTypeGroups: [XTypeGroup(
        label: "Muon Project Files",
        extensions: ["json"],
      )],
      suggestedName: "project",
    )
    .then((value) {
      if(value != null) {
        currentProject.updateWith(MuonProjectController.defaultProject());
        currentProject.projectDir = p.dirname(value);
        currentProject.projectFileName = p.basename(value);
        if(!currentProject.projectFileName.endsWith(".json")) {
          currentProject.projectFileName += ".json";
        }
        currentProject.save();

        return true;
      }
    })
    .catchError((err) {print("internal error: " + err.toString());}); // oh wow i am so naughty
  }

  /// Compiles all voices, and then plays audio from the playhead's
  /// current position
  /// 
  /// Will show snackbars on errors
  /// 
  static Future<void> playAudio(BuildContext context) async {
    if(currentProject.internalStatus != "idle") {return;}

    List<Future<void>> compileRes = [];
    currentProject.internalStatus = "compiling";
    for(final voice in currentProject.voices) {
      compileRes.add(_compileVoiceInternal(voice));
    }
    await Future.wait(compileRes);
    currentProject.internalStatus = "idle";

    final playPos = Duration(
      milliseconds: currentProject.getLabelMillisecondOffset() + 
        (
          1000 * 
          (
            currentProject.playheadTime / 
            (currentProject.bpm / 60)
          )
        ).floor()
      );

    List<Future<bool>> voiceRes = [];
    for(final voice in currentProject.voices) {
      voiceRes.add(_playVoiceInternal(voice,playPos, 1 / currentProject.voices.length));
    }

    final voiceRes2 = await Future.wait(voiceRes);

    var errorShown = false;
    for(final res in voiceRes2) {
      if(!res) {
        if(!errorShown) {
          errorShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Theme.of(context).errorColor,
              content: new Text("Unable to play audio!"),
              duration: new Duration(seconds: 5),
            )
          );
        }
      }
      else {
        currentProject.internalStatus = "playing";
      }
    }
  }

  static Future<void> _compileVoiceInternal(MuonVoiceController voice) async {
    if(voice.audioPlayer != null) {
      await voice.audioPlayer.unload();
    }
    
    await voice.makeLabels();
    await voice.runNeutrino();
    await voice.vocodeWORLD();
  }

  /// Compiles all voices with NSF
  /// 
  /// Will show snackbars on progress
  /// 
  static Future<void> compileVoiceInternalNSF(BuildContext context) async {
    currentProject.internalStatus = "compiling_nsf";
    int voiceID = 0;
    for(final voice in currentProject.voices) {
      voiceID++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: new Text("Compiling voice " + voiceID.toString() + " with NSF..."),
          duration: new Duration(seconds: 2),
        )
      );
      await voice.vocodeNSF();
    }
    currentProject.internalStatus = "idle";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: new Text("NSF complete!"),
        duration: new Duration(seconds: 2),
      )
    );
  }

  static Future<bool> _playVoiceInternal(MuonVoiceController voice,Duration playPos,double volume) async {
    if(voice.audioPlayer != null) {
      await voice.audioPlayer.unload();
    }

    final audioPlayer = await voice.getAudioPlayer(playPos);

    audioPlayer.setVolume(volume);
    await audioPlayer.setPosition(playPos);
    final suc = await audioPlayer.play();

    if(suc) {
      return true;
    }
    else {
      return false;
    }
  }

  /// Stops any currently playing audio, if there is any.
  /// Otherwise, brings the playhead to the start of the project.
  static Future<void> stopAudio() async {
    for(final voice in currentProject.voices) {
      if(voice.audioPlayer != null) {
        voice.audioPlayer.unload();
      }
    }
    if(currentProject.internalStatus == "playing") {
      currentProject.internalStatus = "idle";
    }
    else {
      currentProject.playheadTime = 0;
    }
  }

  @override
  _MuonEditorState createState() => _MuonEditorState();
}

class _MuonEditorState extends State<MuonEditor> {
  static bool _firstTimeRunning = true;

  void _onFirstRun(BuildContext context) {
    final settings = getMuonSettings();

    if(settings.neutrinoDir != "") {
      // We have already performed first time set-up!

      Timer(Duration(milliseconds: 1),() {
        MuonEditor.showWelcomeScreen(context);
      });
    }
    else {
      // no neutrino library, so let's perform first time set-up!

      Timer(Duration(milliseconds: 1),() {
        MuonEditor.performFirstTimeSetup(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    currentProject.setupPlaybackTimers();

    if(_firstTimeRunning) {
      _firstTimeRunning = false;
      _onFirstRun(context);
    }

    return Scaffold(
      appBar: MuonAppBar(),
      // drawer: Drawer(
      //   child: ListView(
      //     children: [
      //       DrawerHeader(
      //         child: Text("Options"),
      //       )
      //     ],
      //   )
      // ),
      body: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: PianoRoll(
              project: currentProject,
              modules: [
                PianoRollNotesModule(selectedNotes: currentProject.selectedNotes),
                PianoRollWAILAModule(),
              ],
              onKey: (pianoRoll,keyEvent) {
                if(keyEvent.isControlPressed) {
                  if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyS)) {
                    currentProject.save();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: new Text("Saved project!"),
                        duration: new Duration(seconds: 2),
                      )
                    );
                  }
                  else if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyZ)) {
                    // undo
                    currentProject.undoAction();
                  }
                  else if(keyEvent.isKeyPressed(LogicalKeyboardKey.keyY)) {
                    // redo
                    currentProject.redoAction();
                  }
                }
                
                if(keyEvent.isKeyPressed(LogicalKeyboardKey.space)) {
                  if(currentProject.internalStatus == "playing") {
                    MuonEditor.stopAudio();
                  }
                  else {
                    MuonEditor.playAudio(context);
                  }
                }
              },
            )
          ),
          MuonSidebar(),
        ]
      ),
    );
  }
}
