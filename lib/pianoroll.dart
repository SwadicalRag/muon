import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:muon/logic/musicxml.dart';

class PianoRoll extends StatefulWidget {
  @override
  _PianoRollState createState() => _PianoRollState();
}

class _PianoRollState extends State<PianoRoll> {
  double pianoKeysWidth = 150.0;
  double xOffset = 0.0;
  double yOffset = 0.0;
  double xScale = 1;
  double yScale = 1;
  bool isCtrlKeyHeld = false;
  bool isAltKeyHeld = false;
  bool isShiftKeyHeld = false;
  bool _dragging = false;
  final FocusNode focusNode = FocusNode();
  MusicXML musicXML = getDefaultFile();

  void clampXY(double renderBoxHeight) {
    xOffset = min(pianoKeysWidth, xOffset);

    double totHeight = renderBoxHeight / yScale;
    yOffset = min(0, yOffset);

    if (totHeight < 1920) {
      // not enough space
      double requiredExtraHeight = 1920 - totHeight;
      yOffset = min(0, max(-requiredExtraHeight, yOffset));
    } else if (totHeight >= 1920) {
      // too much space, dial it back down
      while (totHeight >= 1920 && renderBoxHeight > 0) {
        yScale += 0.25;
        totHeight = renderBoxHeight / yScale;
      }
      yOffset = 0;
    } else {
      // sufficient space!
      yOffset = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    var rectPainter = PianoRollPainter(
        pianoKeysWidth, xOffset, yOffset, xScale, yScale, musicXML);

    return Row(mainAxisSize: MainAxisSize.max, children: [
      Expanded(
          child: RawKeyboardListener(
              focusNode: focusNode,
              autofocus: true,
              onKey: (details) {
                isShiftKeyHeld = details.isShiftPressed;
                isAltKeyHeld = details.isAltPressed;
                isCtrlKeyHeld = details.isControlPressed;
              },
              child: Listener(
                onPointerSignal: (details) {
                  if (details is PointerScrollEvent) {
                    if (!focusNode.hasFocus) {
                      focusNode.requestFocus();
                    }
                    setState(() {
                      if (isShiftKeyHeld && focusNode.hasPrimaryFocus) {
                        xOffset = xOffset - details.scrollDelta.dy;

                        this.clampXY(rectPainter.lastHeight);
                      } else {
                        if (isAltKeyHeld) {
                          double targetScaleX = max(0.25,
                              min(4, xScale - details.scrollDelta.dy / 80));
                          double xPointer = details.localPosition.dx;
                          double xTarget = (xPointer / xScale - xOffset);

                          xScale = targetScaleX;
                          xOffset = -xTarget + xPointer / xScale;
                        }

                        if (isCtrlKeyHeld) {
                          double targetScaleY = max(0.25,
                              min(4, yScale - details.scrollDelta.dy / 80));
                          if (((rectPainter.lastHeight / targetScaleY) <=
                                  1920) ||
                              (details.scrollDelta.dy < 0)) {
                            // only attempt scale if it wont look stupid
                            double yPointer = details.localPosition.dy;
                            double yTarget = (yPointer / yScale - yOffset);

                            yScale = targetScaleY;
                            yOffset = -yTarget + yPointer / yScale;
                          }
                        }

                        if (!isAltKeyHeld && !isCtrlKeyHeld) {
                          yOffset = yOffset - details.scrollDelta.dy;
                        }

                        this.clampXY(rectPainter.lastHeight);
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
                      xOffset = xOffset + details.delta.dx / xScale;
                      yOffset = yOffset + details.delta.dy / yScale;

                      this.clampXY(rectPainter.lastHeight);
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
  PianoRollPainter(this.pianoKeysWidth, this.xOffset, this.yOffset, this.xScale,
      this.yScale, this.musicXML);
  final double pianoKeysWidth;
  final double xOffset;
  final double yOffset;
  final double xScale;
  final double yScale;
  final MusicXML musicXML;

  double lastHeight = 0;
  double lastWidth = 0;

  double get xPos {
    return -xOffset;
  }

  double get yPos {
    return -yOffset;
  }

  double get xInternalPos {
    return (xPos * xScale + pianoKeysWidth) / xScale;
  }

  final double timeGridScale = 2000;

  Map<String, int> pitchMap = {
    'C': 11,
    'C#': 10,
    'D': 9,
    'D#': 8,
    'E': 7,
    'F': 6,
    'F#': 5,
    'G': 4,
    'G#': 3,
    'A': 2,
    'A#': 1,
    'B': 0,
  };
  double pitchToYAxis(MusicXMLPitch pitch) {
    return (pitchMap[pitch.note] * 20 + 12 * 20 * (8 - pitch.octave))
        .toDouble();
  }

  double getCurrentLeftmostTime() {
    return xInternalPos / timeGridScale;
  }

  @override
  void paint(Canvas canvas, Size size) {
    lastWidth = size.width;
    lastHeight = size.height;

    // Clip to viewable area
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Save current state
    canvas.save();

    // set up x axis offset for grid
    // and scale appropriately
    canvas.scale(xScale, yScale);
    canvas.translate(xOffset + pianoKeysWidth, yOffset);

    // draw time grid
    Paint beatDiv = Paint()..color = Colors.grey;
    Paint measureDiv = Paint()..color = Colors.black;
    if (musicXML.lastTimeSignature != null) {
      if (musicXML.lastDivision != null) {
        int divisions = musicXML.lastDivision.divisions;
        int beats = musicXML.lastTimeSignature.beats;
        int beatType = musicXML.lastTimeSignature.beatType;

        double beatDuration = (1 / beatType / divisions) * timeGridScale;
        double leftMostBeat =
            (getCurrentLeftmostTime() * beatType * divisions).floorToDouble();
        double leftMostBeatPos =
            leftMostBeat * timeGridScale / divisions / beatType;
        int beatsInView = ((size.width / xScale) / beatDuration).floor();

        for (int i = -1; i < beatsInView; i++) {
          var curBeatIdx = leftMostBeat + i;
          if (curBeatIdx % beats == 0) {
            canvas.drawLine(Offset(leftMostBeatPos + i * beatDuration, 0),
                Offset(leftMostBeatPos + i * beatDuration, 1920), measureDiv);
          } else {
            canvas.drawLine(Offset(leftMostBeatPos + i * beatDuration, 0),
                Offset(leftMostBeatPos + i * beatDuration, 1920), beatDiv);
          }
        }
      }
    }

    // draw pitch grid
    Paint pitchGridDiv = Paint()..color = Colors.grey[200];
    double firstVisibleKey = (yPos / 20).floorToDouble();
    int visibleKeys = ((size.height / yScale) / 20).floor();
    print("visibleKeys: " + visibleKeys.toString());
    for (int i = 0; i < visibleKeys; i++) {
      canvas.drawLine(
          Offset(xPos - pianoKeysWidth * xScale, (firstVisibleKey + i) * 20),
          Offset(xPos + size.width / xScale, (firstVisibleKey + i) * 20),
          pitchGridDiv);
    }

    // draw notes on top of the grid
    for (final event in musicXML.events) {
      if (event is MusicXMLEventNote) {
        canvas.drawRect(
            Rect.fromLTWH(
                event.absoluteTime * timeGridScale,
                pitchToYAxis(event.pitch),
                event.absoluteDuration * timeGridScale,
                20),
            Paint()..color = Colors.blue);
      }
    }

    // set up y axis only offset
    canvas.restore();

    // draw *unscaled* text on top of midi notes
    for (final event in musicXML.events) {
      if (event is MusicXMLEventNote) {
        if(event.lyric != "") {
          TextSpan lyricSpan = new TextSpan(style: new TextStyle(color: Colors.grey[600]), text: event.lyric);
          TextPainter tp = new TextPainter(text: lyricSpan, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
          tp.layout();
          tp.paint(canvas, new Offset(
            (event.absoluteTime * timeGridScale + xOffset + pianoKeysWidth + 20) * xScale, 
            (pitchToYAxis(event.pitch) + yOffset) * yScale - 20
          ));
        }
      }
    }

    // set up piano keys scaling
    canvas.scale(1, yScale);
    canvas.translate(0, yOffset);

    Paint whiteKeys = Paint()..color = Colors.white;
    Paint blueKeys = Paint()..color = Colors.blue;
    double keyIdx = 0;
    for (int octave = 8; octave > 0; octave--) {
      if (octave == 8) {
        canvas.drawRect(
            Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), blueKeys); // B
      } else {
        canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20),
            whiteKeys); // B
      }
      keyIdx++;
      canvas.drawRect(
          Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), Paint()); // A#
      keyIdx++;
      canvas.drawRect(
          Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), whiteKeys); // A
      keyIdx++;
      canvas.drawRect(
          Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), Paint()); // G#
      keyIdx++;
      canvas.drawRect(
          Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), whiteKeys); // G
      keyIdx++;
      canvas.drawRect(
          Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), Paint()); // F#
      keyIdx++;
      canvas.drawRect(
          Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), whiteKeys); // F
      keyIdx++;
      canvas.drawRect(
          Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), whiteKeys); // E
      keyIdx++;
      canvas.drawRect(
          Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), Paint()); // D#
      keyIdx++;
      canvas.drawRect(
          Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), whiteKeys); // D
      keyIdx++;
      canvas.drawRect(
          Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), Paint()); // C#
      keyIdx++;
      if (octave == 1) {
        canvas.drawRect(
            Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), blueKeys); // C
      } else {
        canvas.drawRect(Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20),
            whiteKeys); // C
      }
      keyIdx++;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
