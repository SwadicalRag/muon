
import 'dart:math';

import 'package:flutter/material.dart';
import "package:synaps_flutter/synaps_flutter.dart";
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
            child: Rx(() => Text(currentProject.bpm.toString() + " BPM",style: TextStyle(fontSize: 16),))
          ),
          Rx(() => Slider(
            value: currentProject.bpm,
            min: 40,
            max: 240,
            divisions: 200,
            label: currentProject.bpm.toString() + " bpm",
            onChanged: (double value) {
              currentProject.bpm = value.floorToDouble();
            },
          )),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Rx(() => Text(currentProject.beatsPerMeasure.toString() + " Beats per Measure",style: TextStyle(fontSize: 16),))
          ),
          Rx(() => Slider(
            value: currentProject.beatsPerMeasure.toDouble(),
            min: 1,
            max: 32,
            divisions: 32,
            label: currentProject.beatsPerMeasure.toString() + " beats",
            onChanged: (double value) {
              currentProject.beatsPerMeasure = value.round();
            },
          )),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Rx(() => Text("Beat Value of 1 / " + currentProject.beatValue.toString(),style: TextStyle(fontSize: 16),))
          ),
          Rx(() => Slider(
            value: log(currentProject.beatValue) / log(2),
            min: 1,
            max: 5,
            divisions: 4,
            label: "1 / " + currentProject.beatValue.toString(),
            onChanged: (double value) {
              currentProject.beatValue = pow(2,value.round());
            },
          )),
        ],
      )
    );
  }
}
