
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muon/editor.dart';

class MuonProjectMetadataMenu extends StatelessWidget {
  const MuonProjectMetadataMenu({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Text("Project Settings",style: TextStyle(fontSize: 26),)
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Obx(() => Text(currentProject.bpm.value.toString() + " BPM",style: TextStyle(fontSize: 16),))
          ),
          Obx(() => Slider(
            value: currentProject.bpm.value,
            min: 40,
            max: 240,
            divisions: 200,
            label: currentProject.bpm.value.toString() + " bpm",
            onChanged: (double value) {
              currentProject.bpm.value = value.floorToDouble();
            },
          )),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Obx(() => Text(currentProject.beatsPerMeasure.value.toString() + " Beats per Measure",style: TextStyle(fontSize: 16),))
          ),
          Obx(() => Slider(
            value: currentProject.beatsPerMeasure.value.toDouble(),
            min: 1,
            max: 32,
            divisions: 32,
            label: currentProject.beatsPerMeasure.value.toString() + " beats",
            onChanged: (double value) {
              currentProject.beatsPerMeasure.value = value.round();
            },
          )),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Obx(() => Text("Beat Value of 1 / " + currentProject.beatValue.value.toString(),style: TextStyle(fontSize: 16),))
          ),
          Obx(() => Slider(
            value: log(currentProject.beatValue.value) / log(2),
            min: 1,
            max: 5,
            divisions: 4,
            label: "1 / " + currentProject.beatValue.value.toString(),
            onChanged: (double value) {
              currentProject.beatValue.value = pow(2,value.round());
            },
          )),
        ],
      )
    );
  }
}
