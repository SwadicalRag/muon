
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muon/controllers/muonvoice.dart';
import 'package:muon/editor.dart';
import 'package:muon/logic/helpers.dart';

class MuonVoiceControls extends StatelessWidget {
  const MuonVoiceControls({
    Key key,
    @required this.voice,
  }) : super(key: key);

  final MuonVoiceController voice;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Container(
      height: 40,
      margin: EdgeInsets.symmetric(horizontal: 5,vertical: 5),
      padding: EdgeInsets.only(left: 15),
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.only(right: 10),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: voice.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.7),
                  blurRadius: 2,
                  spreadRadius: 2,
                ),
              ]
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Obx(() => Text(
              "Voice " + (currentProject.voices.indexOf(voice) + 1).toString() + " (" + voice.modelName.value + ")",
            ))
          ),
          Expanded(
            child: Container(),
          ),
          Obx(() => IconButton(
            icon: const Icon(Icons.center_focus_strong),
            disabledColor: Colors.green.withOpacity(0.9),
            tooltip: "Select voice",
            onPressed: currentProject.currentVoiceID.value == currentProject.voices.indexOf(voice) ? null : () {
              currentProject.currentVoiceID.value = currentProject.voices.indexOf(voice);
            },
          )),
          PopupMenuButton(
            icon: const Icon(Icons.speaker_notes),
            tooltip: "Change voice model",
            onSelected: (String result) {
              voice.modelName.value = result;
            },
            itemBuilder: (BuildContext context) {
              final List<PopupMenuItem<String>> items = [];

              final models = MuonHelpers.getAllVoiceModels();

              for(final modelName in models) {
                items.add(
                  PopupMenuItem(
                    value: modelName,
                    child: Text(modelName),
                  ),
                );
              }

              return items;
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Delete voice",
            onPressed: () {
              currentProject.voices.remove(voice);
            },
          ),
        ],
      ),
      decoration: BoxDecoration(
        color: themeData.buttonColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 1,
            spreadRadius: 1,
          ),
        ]
      ),
    );
  }
}
