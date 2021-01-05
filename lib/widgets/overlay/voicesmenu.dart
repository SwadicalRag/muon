
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muon/controllers/muonvoice.dart';
import 'package:muon/editor.dart';
import 'package:muon/logic/musicxml.dart';
import 'package:muon/widgets/overlay/voicecontrols.dart';

class MuonVoicesMenu extends StatelessWidget {
  const MuonVoicesMenu({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Container(
      child: Column(
        verticalDirection: VerticalDirection.up,
        children: [
          Expanded(
            child: Scrollbar(
              child: Obx(() => ListView.builder(
                itemCount: currentProject.voices.length,
                itemBuilder: (context, index) {
                  final voice = currentProject.voices[index];
                  return MuonVoiceControls(voice: voice);
                },
              )),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text("Voices",style: TextStyle(fontSize: 26),)
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    offset: Offset(-5,0),
                    child: IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: "Add voice",
                      onPressed: () {
                        final newVoice = MuonVoiceController();
                        newVoice.project = currentProject;
                        currentProject.voices.add(newVoice);
                      },
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    offset: Offset(-35,0),
                    child: IconButton(
                      icon: const Icon(Icons.code),
                      tooltip: "Import voice from MusicXML",
                      onPressed: () {
                        FileSelectorPlatform.instance.openFile(
                          confirmButtonText: "Open MusicXML File",
                        )
                        .catchError((err) {print("internal file browser error: " + err.toString());}) // oh wow i am so naughty
                        .then((value) {
                          if(value != null) {
                            MusicXML musicXML = parseFile(value.path);
                            currentProject.importVoiceFromMusicXML(musicXML, true);
                          }
                        });
                      },
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    offset: Offset(-65,0),
                    child: IconButton(
                      icon: const Icon(Icons.queue_music),
                      tooltip: "Import voice from MIDI",
                      onPressed: () {
                        FileSelectorPlatform.instance.openFile(
                          confirmButtonText: "Open MIDI File",
                        )
                        .catchError((err) {print("internal file browser error: " + err.toString());}) // oh wow i am so naughty
                        .then((value) {
                          if(value != null) {
                            currentProject.importVoiceFromMIDIFile(value.path, true);
                          }
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            decoration: BoxDecoration(
              color: themeData.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  offset: Offset(0,5),
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 3,
                  spreadRadius: 1,
                ),
              ]
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        color: themeData.scaffoldBackgroundColor,
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
