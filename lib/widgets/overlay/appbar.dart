import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muon/editor.dart';
import 'package:muon/main.dart';

class MuonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MuonAppBar({
    Key key,
  }) : super(key: key);

  @override
  Size get preferredSize => new Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text("Muon Editor"),
      actions: [
        IconButton(
          icon: const Icon(Icons.exposure_plus_1),
          tooltip: "Add subdivision",
          onPressed: () {
            currentProject.setSubdivision(currentProject.currentSubdivision.value + 1);
          },
        ),
        IconButton(
          icon: const Icon(Icons.exposure_minus_1),
          tooltip: "Subtract subdivision",
          onPressed: () {
            currentProject.setSubdivision(max(1,currentProject.currentSubdivision.value - 1));
          },
        ),
        SizedBox(width: 40,),
        Obx(() => IconButton(
          icon: const Icon(Icons.play_arrow),
          tooltip: "Play",
          color: currentProject.internalStatus.value == "compiling" ? 
            Colors.yellow : 
              currentProject.internalStatus.value == "playing" ?
                Colors.green :
                Colors.white,
          onPressed: () {
            MuonEditor.playAudio(context);
          },
        )),
        IconButton(
          icon: const Icon(Icons.stop),
          tooltip: "Stop",
          onPressed: () {
            MuonEditor.stopAudio();
          },
        ),
        SizedBox(width: 40,),
        IconButton(
          icon: const Icon(Icons.timer),
          tooltip: "Calculate phoneme labels",
          onPressed: () {
            for(final voice in currentProject.voices) {
              voice.makeLabels();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.music_note),
          tooltip: "Calculate neutrino data",
          onPressed: () {
            for(final voice in currentProject.voices) {
              voice.runNeutrino();
            }
          },
        ),
        Obx(() => IconButton(
          icon: const Icon(Icons.computer),
          color: currentProject.internalStatus.value == "compiling_nsf" ? 
            Colors.yellow : Colors.white,
          tooltip: "Render with NSF",
          onPressed: () {
            MuonEditor.compileVoiceInternalNSF(context);
          },
        )),
        SizedBox(width: 40,),
        Obx(() => IconButton(
            icon: darkMode.value ? const Icon(Icons.lightbulb) : const Icon(Icons.lightbulb_outline),
            tooltip: darkMode.value ? "Lights on" : "Lights out",
            onPressed: () {
              darkMode.value = !darkMode.value;
            },
          ),
        ),
        SizedBox(width: 40,),
        IconButton(
          icon: const Icon(Icons.save),
          tooltip: "Save",
          onPressed: () {
            currentProject.save();
          },
        ),
        IconButton(
          icon: const Icon(Icons.folder),
          tooltip: "Load",
          onPressed: () {
            MuonEditor.openProject(context);
          },
        ),
        IconButton(
          icon: const Icon(Icons.create),
          tooltip: "New project",
          onPressed: () {
            MuonEditor.createNewProject();
          },
        ),
        SizedBox(width: 20,),
      ],
    );
  }
}
