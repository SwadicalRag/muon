
import 'package:flutter/material.dart';
import 'package:muon/pianoroll.dart';

class MuonEditor extends StatefulWidget {
  MuonEditor() : super();

  @override
  _MuonEditorState createState() => _MuonEditorState();
}

class _MuonEditorState extends State<MuonEditor> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Muon Editor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: "Play",
            onPressed: () {
              
            },
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: "Stop",
            onPressed: () {
              
            },
          ),
          SizedBox(width: 40,),
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: "Calculate phoneme labels",
            onPressed: () {
              
            },
          ),
          IconButton(
            icon: const Icon(Icons.music_note),
            tooltip: "Calculate neutrino data",
            onPressed: () {
              
            },
          ),
          IconButton(
            icon: const Icon(Icons.computer),
            tooltip: "Render with NSF",
            onPressed: () {
              
            },
          ),
          SizedBox(width: 40,),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: "Save",
            onPressed: () {
              
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: "Load",
            onPressed: () {
              
            },
          ),
          IconButton(
            icon: const Icon(Icons.create),
            tooltip: "New project",
            onPressed: () {
              
            },
          ),
          SizedBox(width: 20,),
        ],
      ),
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
            child: PianoRoll()
          ),
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 7,
                  spreadRadius: 1,
                ),
              ]
            ),
          ),
        ]
      ),
    );
  }
}
