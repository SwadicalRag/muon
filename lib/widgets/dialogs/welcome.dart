
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:muon/editor.dart';

class MuonWelcomeDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AlertDialog(
        title: Center(child: Text("Welcome to Muon!")),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              RaisedButton(
                child: Text("Create New Project"),
                onPressed: () async {
                  final suc = await MuonEditor.createNewProject();
                  if(suc == true) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                }
              ),
              SizedBox(height: 10),
              RaisedButton(
                child: Text("Open Project"),
                onPressed: () async {
                  final suc = await MuonEditor.openProject(context);
                  if(suc == true) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                }
              )
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text("About"),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationVersion: "0.0.1",
                applicationName: "Muon",
                applicationLegalese: "copyright (c) swadical 2021",
              );
            },
          ),
          OutlineButton(
            child: Text("Quit"),
            onPressed: () {
              exit(0);
            },
          ),
        ],
      ),
    );
  }
}
