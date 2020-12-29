import 'dart:io';

import 'package:flutter/material.dart';
import 'package:muon/editor.dart';

import 'package:window_size/window_size.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle("Muon Editor");
    setWindowMinSize(Size(1280, 720));
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Muon',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: MuonEditor(),
    );
  }
}
