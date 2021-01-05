import 'package:flutter/material.dart';
import 'package:muon/widgets/overlay/projectmetadatamenu.dart';
import 'package:muon/widgets/overlay/voicesmenu.dart';

class MuonSidebar extends StatelessWidget {
  const MuonSidebar({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MuonProjectMetadataMenu(),
          const SizedBox(height: 10),
          Expanded(
            child: MuonVoicesMenu(),
          ),
        ],
      ),
      width: 400,
      decoration: BoxDecoration(
        color: themeData.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 7,
            spreadRadius: 1,
          ),
        ]
      ),
    );
  }
}
