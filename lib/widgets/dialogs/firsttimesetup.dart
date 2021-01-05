
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:muon/editor.dart';
import 'package:muon/main.dart';
import 'package:muon/serializable/settings.dart';

class MuonFirstTimeSetupDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = getMuonSettings();

    return Scaffold(
      body: AlertDialog(
        title: Text("Hello and welcome!"),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text("Before you start using Muon, we need to do some housekeeping!"),
              SizedBox(height: 15,),
              RaisedButton(
                child: Text("Choose Neutrino SDK Folder Location"),
                onPressed: () {
                  FileSelectorPlatform.instance.getDirectoryPath(
                    confirmButtonText: "Open Neutrino SDK",
                  )
                  .catchError((err) {print("internal file browser error: " + err.toString());}) // oh wow i am so naughty
                  .then((value) {
                    if(value != null) {
                      if(Directory(value).existsSync()) {
                        if(File(value + "/bin/NEUTRINO.exe").existsSync() || File(value + "/bin/NEUTRINO").existsSync()) {
                          settings.neutrinoDir = value;
                          settings.save();
                          return;
                        }
                      }

                      settings.neutrinoDir = "";
                      settings.save();

                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: Theme.of(context).errorColor,
                          content: new Text("Error: That doesn't seem like a valid NEUTRINO directory!"),
                          duration: new Duration(seconds: 5),
                        )
                      );
                    }
                  });
                },
              ),
              SizedBox(height: 15,),
              SwitchListTile(
                title: Text("Please burn my eyes"),
                secondary: Icon(Icons.lightbulb_outline),
                value: !darkMode.value,
                onChanged: (value) {
                  darkMode.value = !value;
                },
              )
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text("I'm all set!"),
            onPressed: () {
              if(settings.neutrinoDir == "") {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: Theme.of(context).errorColor,
                    content: new Text("Error: Please choose a valid directory for the NEUTRINO library!"),
                    duration: new Duration(seconds: 5),
                  )
                );
              }
              else {
                Navigator.of(context, rootNavigator: true).pop();
                MuonEditor.showWelcomeScreen(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
