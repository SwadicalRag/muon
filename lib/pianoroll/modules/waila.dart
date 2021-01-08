import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:muon/pianoroll/pianoroll.dart';

class PianoRollWAILAModule extends PianoRollModule {
  PianoRollWAILAModule() : super();

  bool hitTest(Point point) {
    return false;
  }

  void onHover(PointerEvent mouseEvent) {}

  void onClick(PointerEvent mouseEvent, int numClicks) {}

  void onDragStart(PointerEvent mouseEvent, Point mouseStartPos) {}

  void onDragging(PointerEvent mouseEvent, Point mouseStartPos) {}

  void onDragEnd(PointerEvent mouseEvent, Point mouseStartPos) {}

  void onSelect(PointerEvent mouseEvent, Rect selectionBox) {}

  void onKey(RawKeyEvent keyEvent) {}

  void paint(Canvas canvas, Size size) {
    final curMousePos = state.curMousePos;
    final themeData = painter.themeData;

    // clear all transforms
    canvas.restore();

    if (curMousePos != null) {
      final mouseBeatNum = max(0, painter.getBeatNumAtCursor(curMousePos.x));
      final mouseBeatSubDivNum =
          (mouseBeatNum * project.timeUnitsPerBeat).floor() %
                  project.timeUnitsPerBeat +
              1;
      final mouseMeasureNum = (mouseBeatNum / project.beatsPerMeasure).ceil();
      final mousePitch = painter.getPitchAtCursor(curMousePos.y);
      var wailaLabelPainter = new TextPainter(
        text: new TextSpan(
          style: new TextStyle(
            color: themeData.brightness == Brightness.light
                ? Colors.grey[600]
                : Colors.grey[200],
            fontSize: 24,
          ),
          text: mousePitch.note +
              mousePitch.octave.toString() +
              " | " +
              mouseMeasureNum.toString() +
              "." +
              mouseBeatNum.ceil().toString() +
              "." +
              mouseBeatSubDivNum.toString(),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      var wailaRect = Rect.fromLTWH(
        size.width - 10 - wailaLabelPainter.width,
        size.height - 10 - wailaLabelPainter.height,
        10 + wailaLabelPainter.width,
        10 + wailaLabelPainter.height,
      );
      var wailaShadowPath = new Path();
      wailaShadowPath.addRect(wailaRect);

      canvas.drawShadow(wailaShadowPath, Colors.black, 10, false);
      canvas.drawRect(
          wailaRect, Paint()..color = themeData.scaffoldBackgroundColor);
      wailaLabelPainter.paint(
          canvas, new Offset(wailaRect.left + 5, wailaRect.top + 5));
    }

    // back up transforms
    canvas.save();

    // restore transforms
    painter.noteCoordinateSystem(canvas);
  }
}
