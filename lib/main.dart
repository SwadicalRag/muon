import "dart:io";

import "package:flutter/material.dart";
import 'package:muon/controllers/settings.dart';
import "package:muon/licenses.dart";
import "package:muon/editor.dart";
import 'package:synaps_flutter/synaps_flutter.dart';

import "package:window_size/window_size.dart";

/// Light/Dark mode implemented as a reactive boolean
/// This happened to be the easiest way to implement this.
final appSettings = MuonSettingsController().ctx();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle("Muon Editor");
    setWindowMinSize(Size(1280, 720));
  }

  addLicenses();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Rx(() => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Muon",
      themeMode: appSettings.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.purple,
        brightness: Brightness.dark,
      ),
      home: MuonEditor(),
    ));
  }
}
