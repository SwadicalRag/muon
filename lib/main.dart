import 'dart:io';
import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:muon/licenses.dart';
import 'package:muon/editor.dart';
import 'package:muon/serializable/settings.dart';

import 'package:window_size/window_size.dart';

final darkMode = getMuonSettings().darkMode.obs..listen((bool newVal) {
  final settings = getMuonSettings();

  settings.darkMode = newVal;

  settings.save();
});

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
    return Obx(() => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Muon',
      themeMode: darkMode.value ? ThemeMode.dark : ThemeMode.light,
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
