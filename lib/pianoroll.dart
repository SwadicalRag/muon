import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class PianoRoll extends StatefulWidget {
  @override
  _PianoRollState createState() => _PianoRollState();
}

class _PianoRollState extends State<PianoRoll> {
  var xPos = 0.0;
  var yPos = 0.0;
  bool isShiftKeyHeld = false;
  bool _dragging = false;
  final FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    var rectPainter = PianoRollPainter(xPos, yPos);

    return Row(mainAxisSize: MainAxisSize.max, children: [
      Expanded(
          child: RawKeyboardListener(
              focusNode: focusNode,
              autofocus: true,
              onKey: (details) {
                isShiftKeyHeld = details.isShiftPressed;
              },
              child: Listener(
                onPointerSignal: (details) {
                  if (details is PointerScrollEvent) {
                    if (!focusNode.hasFocus) {
                      focusNode.requestFocus();
                    }
                    setState(() {
                      if (isShiftKeyHeld && focusNode.hasPrimaryFocus) {
                        xPos = min(100, xPos - details.scrollDelta.dy);
                      } else {
                        yPos = min(
                            0,
                            max(-1920 + rectPainter.lastHeight,
                                yPos - details.scrollDelta.dy));
                      }
                    });
                  }
                },
                onPointerDown: (details) {
                  _dragging = true;
                },
                onPointerUp: (details) {
                  _dragging = false;
                },
                onPointerMove: (details) {
                  if (_dragging) {
                    setState(() {
                      xPos = min(100, xPos + details.delta.dx);
                      yPos = min(
                          0,
                          max(-1920 + rectPainter.lastHeight,
                              yPos + details.delta.dy));
                    });
                  }
                },
                child: Container(
                  color: Colors.white,
                  child: CustomPaint(
                    painter: rectPainter,
                    child: Container(),
                  ),
                ),
              )))
    ]);
  }
}

class PianoRollPainter extends CustomPainter {
  PianoRollPainter(this.xOffset, this.yOffset);
  final double xOffset;
  final double yOffset;

  double lastHeight = 0;
  double lastWidth = 0;

  @override
  void paint(Canvas canvas, Size size) {
    lastWidth = size.width;
    lastHeight = size.height;

    // Clip to viewable area
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // set up x axis offset for grid
    canvas.translate(xOffset, yOffset);

    canvas.drawRect(
        Rect.fromLTWH(200, 200, 100, 20), Paint()..color = Colors.blue);

    // set up y axis only offset
    canvas.translate(-xOffset, 0);

    Paint whiteKeys = Paint()..color = Colors.white;
    double keyIdx = 0;
    for (int octave = 8; octave > 0; octave--) {
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), whiteKeys); // C
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), Paint()); // C#
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), whiteKeys); // D
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), Paint()); // D#
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), whiteKeys); // E
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), whiteKeys); // F
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), Paint()); // F#
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), whiteKeys); // G
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), Paint()); // G#
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), whiteKeys); // A
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), Paint()); // A#
      keyIdx++;
      canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, 100, 20), whiteKeys); // B
      keyIdx++;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
