
import 'dart:async';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:muon/widgets/overlay/actioncontrols.dart';
import "package:synaps_flutter/synaps_flutter.dart";
import 'package:muon/controllers/muonvoice.dart';
import 'package:muon/editor.dart';
import 'package:muon/logic/musicxml.dart';
import 'package:muon/widgets/overlay/voicecontrols.dart';

class MuonActionsMenu extends StatelessWidget {
  MuonActionsMenu({
    Key key,
  }) : super(key: key);

  final _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    int lastLength = 0;
    final themeData = Theme.of(context);
    return Container(
      child: Column(
        verticalDirection: VerticalDirection.up,
        children: [
          Expanded(
            child: Scrollbar(
              thickness: 2,
              child: Rx(() {
                final nextActionPos = currentProject.nextActionPos;

                final listView = ListView.builder(
                  controller: _controller,
                  reverse: true,
                  itemCount: currentProject.actions.length,
                  itemBuilder: (context, index) {
                    final action = currentProject.actions[index];
                    return MuonActionControls(
                      action: action,
                      isPerformed: index < nextActionPos,
                    );
                  },
                );

                if(currentProject.actions.length != lastLength) {
                  scheduleMicrotask(() {
                    if(currentProject.actions.length > 0) {
                      _controller.animateTo(
                        _controller.position.maxScrollExtent / currentProject.actions.length * currentProject.nextActionPos,
                        duration: Duration(milliseconds: 200),
                        curve: Curves.fastOutSlowIn,
                      );
                    }
                  });
                }

                lastLength = currentProject.actions.length;

                return listView;
              }),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text("Actions",style: TextStyle(fontSize: 26),)
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    offset: Offset(-5,0),
                    child: IconButton(
                      icon: const Icon(Icons.restore),
                      tooltip: "Redo all",
                      onPressed: () {
                        if(currentProject.actions.isNotEmpty) {
                          currentProject.redoUntilAction(currentProject.actions.last);
                        }
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
