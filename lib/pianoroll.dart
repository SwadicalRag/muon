import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import 'package:muon/logic/musicxml.dart';

class PianoRoll extends StatefulWidget {
  @override
  _PianoRollState createState() => _PianoRollState();
}

class _PianoRollState extends State<PianoRoll> {
  double pianoKeysWidth = 150.0;
  double xOffset = -1.0;
  double yOffset = -1.0;
  double xScale = 1;
  double yScale = 1;
  bool isCtrlKeyHeld = false;
  bool isAltKeyHeld = false;
  bool isShiftKeyHeld = false;
  bool _dragging = false;
  bool _selecting = false;
  MusicXML musicXML = getDefaultFile();
  Map<MusicXMLEventNote,bool> selectedNotes = {};
  Point _firstSelectionPos;
  Rect selectionRect;

  @override
  void initState() {
    RawKeyboard.instance.addListener(_keyListener);
    super.initState();
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_keyListener);
    super.dispose();
  }

  _keyListener(RawKeyEvent event) {
    isShiftKeyHeld = event.isShiftPressed;
    isAltKeyHeld = event.isAltPressed;
    isCtrlKeyHeld = event.isControlPressed;
  }

  void clampXY(double renderBoxHeight) {
    xOffset = min(-2, xOffset);

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
    return Row(mainAxisSize: MainAxisSize.max, children: [
      Expanded(child: LayoutBuilder(builder: (context, constraits) {
        if ((xOffset == -1) && (yOffset == -1)) {
          // first run: scroll to C#6
          xOffset = 0;
          yOffset = -PianoRollPainter.pitchToYAxisEx("C#", 6);
        }

        this.clampXY(constraits.maxHeight);

        var rectPainter = PianoRollPainter(
            pianoKeysWidth, xOffset, yOffset, xScale, yScale, musicXML, selectedNotes, selectionRect);

        return Listener(
          onPointerSignal: (details) {
            if (details is PointerScrollEvent) {
              setState(() {
                if (isShiftKeyHeld) {
                  xOffset = xOffset - details.scrollDelta.dy / xScale;

                  this.clampXY(rectPainter.lastHeight);
                } else {
                  if (isAltKeyHeld) {
                    double targetScaleX = max(
                        0.25, min(4, xScale - details.scrollDelta.dy / 80));
                    double xPointer = details.localPosition.dx - pianoKeysWidth;
                    double xTarget = (xPointer / xScale - xOffset);

                    xScale = targetScaleX;
                    xOffset = -xTarget + xPointer / xScale;
                  }

                  if (isCtrlKeyHeld) {
                    double targetScaleY = max(
                        0.25, min(4, yScale - details.scrollDelta.dy / 80));
                    if (((rectPainter.lastHeight / targetScaleY) <= 1920) ||
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
            if((details.buttons & kMiddleMouseButton) == kMiddleMouseButton) {
              _dragging = true;
            }
            else if((details.buttons & kPrimaryMouseButton) == kPrimaryMouseButton) {
              final screenPos = Point(details.localPosition.dx,details.localPosition.dy);
              _selecting = true;
              _firstSelectionPos = screenPos;
              setState(() {
                selectionRect = Rect.fromLTRB(details.localPosition.dx, details.localPosition.dy, details.localPosition.dx, details.localPosition.dy);
              });
            }
          },
          onPointerUp: (details) {
            if(_selecting) {
              _firstSelectionPos = null;
              setState(() {
                selectionRect = null;
              });
            }

            _dragging = false;
            _selecting = false;
          },
          onPointerMove: (details) {
            if (_dragging == true) {
              setState(() {
                xOffset = xOffset + details.delta.dx / xScale;
                yOffset = yOffset + details.delta.dy / yScale;

                this.clampXY(rectPainter.lastHeight);
              });
            }
            else if (_selecting == true) {
              setState(() {
                var left = min(_firstSelectionPos.x, details.localPosition.dx);
                var right = max(_firstSelectionPos.x, details.localPosition.dx);
                var top = min(_firstSelectionPos.y, details.localPosition.dy);
                var bottom = max(_firstSelectionPos.y, details.localPosition.dy);
                selectionRect = Rect.fromLTRB(left,top,right,bottom);
              });
            }
          },
          onPointerHover: (details) {
            // final screenPos = Point(details.localPosition.dx,details.localPosition.dy);
            // var pitch = rectPainter.getPitchAtCursor(screenPos.y);
            // var absTime = rectPainter.getAbsoluteTimeAtCursor(screenPos.x);
            // print("pitch: " + pitch.note + pitch.octave.toString());
            // print("absTime: " + absTime.toString());

            // var eventAtCursor = rectPainter.getMusicXMLEventAtScreenPos(screenPos);
            // print("event " + eventAtCursor.toString());

            // if(eventAtCursor is MusicXMLEventNote) {
            //   setState(() {
            //     selectedNotes.putIfAbsent(eventAtCursor, () => true);
            //   });
            // }
          },
          child: Container(
            color: Colors.white,
            child: CustomPaint(
              painter: rectPainter,
              child: Container(),
            ),
          ),
        );
      }))
    ]);
  }
}

class PianoRollPainter extends CustomPainter {
  PianoRollPainter(this.pianoKeysWidth, this.xOffset, this.yOffset, this.xScale,
      this.yScale, this.musicXML, this.selectedNotes, this.selectionRect);
  final double pianoKeysWidth;
  final double xOffset;
  final double yOffset;
  final double xScale;
  final double yScale;
  final MusicXML musicXML;
  final Map<MusicXMLEventNote,bool> selectedNotes;
  final Rect selectionRect;

  double lastHeight = 0;
  double lastWidth = 0;

  final double pixelsPerBeat = 500;

  double get xPos {
    return -xOffset;
  }

  double get yPos {
    return -yOffset;
  }

  double get xInternalPos {
    return (xPos * xScale - pianoKeysWidth) / xScale;
  }

  static Map<String, int> pitchMap = {
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
  static Map<int, String> pitchMapReverse =
      pitchMap.map((key, value) => new MapEntry(value, key));
  static double pitchToYAxis(MusicXMLPitch pitch) {
    return pitchToYAxisEx(pitch.note, pitch.octave);
  }

  static double pitchToYAxisEx(String note, int octave) {
    return (pitchMap[note] * 20 + 12 * 20 * (8 - octave)).toDouble();
  }

  double getCurrentLeftmostBeat() {
    return xInternalPos / pixelsPerBeat;
  }

  Point screenPosToCanvasPos(Point screenPos, bool outsideGrid) {
    if (!outsideGrid) {
      return Point(
        (screenPos.x - pianoKeysWidth) / xScale - xOffset,
        screenPos.y / yScale - yOffset,
      );
    } else {
      return Point(
        screenPos.x / xScale - xOffset,
        screenPos.y / yScale - yOffset,
      );
    }
  }

  Point canvasPosToScreenPos(Point canvasPos, bool outsideGrid) {
    if (!outsideGrid) {
      return Point(
        (canvasPos.x + xOffset) * xScale + pianoKeysWidth,
        (canvasPos.y + yOffset) * yScale,
      );
    } else {
      return Point(
        (canvasPos.x + xOffset) * xScale,
        (canvasPos.y + yOffset) * yScale,
      );
    }
  }

  double getAbsoluteTimeAtCursor(double screenPosX) {
    var canvasX = screenPosX / xScale - xOffset;
    var internalCanvasX = (canvasX * xScale - pianoKeysWidth) / xScale;

    return internalCanvasX / pixelsPerBeat;
  }

  MusicXMLPitch getPitchAtCursor(double screenPosY) {
    var canvasY = screenPosY / yScale - yOffset;

    var pitchDiv = (canvasY / 20).floor();
    var rawOctave = (pitchDiv / 12).floor();
    var noteID = pitchDiv - rawOctave * 12;

    var pitch = new MusicXMLPitch();
    pitch.note = pitchMapReverse[noteID];
    pitch.octave = 8 - rawOctave;

    return pitch;
  }

  MusicXMLEvent getMusicXMLEventAtScreenPos(Point screenPos) {
    // O(n), LOOK AWAY!
    // I DON'T CARE

    final canvasPos = screenPosToCanvasPos(screenPos, false);

    for (final event in musicXML.events) {
      if (event is MusicXMLEventNote) {
        var noteX = event.absoluteTime * pixelsPerBeat;
        var noteY = pitchToYAxis(event.pitch);
        var noteW = event.absoluteDuration * pixelsPerBeat;
        var noteH = 20;

        if ((noteX < canvasPos.x) &&
            ((noteX + noteW) > canvasPos.x) &&
            (noteY < canvasPos.y) &&
            ((noteY + noteH) > canvasPos.y)) {
          return event;
        }
      }
    }

    return null;
  }

  final noteColors = [
    Colors.blue,
    Colors.purple,
    Colors.amber,
    Colors.indigo,
    Colors.green,
    Colors.teal,
    Colors.brown,
  ];

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
    canvas.translate(xOffset + pianoKeysWidth / xScale, yOffset);

    // draw pitch grid
    Paint pitchGridDiv = Paint()..color = Colors.grey[200];
    Paint pitchGridOctaveDiv = Paint()..color = Colors.grey[400];
    double firstVisibleKey = (yPos / 20).floorToDouble();
    int visibleKeys = ((size.height / yScale) / 20).floor();
    for (int i = 0; i < visibleKeys; i++) {
      if ((firstVisibleKey + i) % 12 == 0) {
        canvas.drawLine(
            Offset(xPos - pianoKeysWidth * xScale, (firstVisibleKey + i) * 20),
            Offset(xPos + size.width / xScale, (firstVisibleKey + i) * 20),
            pitchGridOctaveDiv);
      } else {
        canvas.drawLine(
            Offset(xPos - pianoKeysWidth * xScale, (firstVisibleKey + i) * 20),
            Offset(xPos + size.width / xScale, (firstVisibleKey + i) * 20),
            pitchGridDiv);
      }
    }

    // draw time grid
    Paint beatDiv = Paint()..color = Colors.grey;
    Paint measureDiv = Paint()..color = Colors.black;
    if (musicXML.lastTimeSignature != null) {
      if (musicXML.lastDivision != null) {
        int divisions = musicXML.lastDivision.divisions;
        int beats = musicXML.lastTimeSignature.beats;
        int beatType = musicXML.lastTimeSignature.beatType;

        double beatDuration = pixelsPerBeat;
        double leftMostBeat = getCurrentLeftmostBeat().floorToDouble();
        double leftMostBeatPos = leftMostBeat * pixelsPerBeat;
        int beatsInView = ((size.width / xScale) / beatDuration).ceil();

        for (int i = 0; i <= beatsInView; i++) {
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

    // draw notes on top of the grid
    for (final event in musicXML.events) {
      if (event is MusicXMLEventNote) {
        // print("Abs" + (event.absoluteTime).toString());
        var noteColor = noteColors[event.voice % noteColors.length];
        if(selectedNotes.containsKey(event)) {
          canvas.drawRect(
              Rect.fromLTWH(
                  event.absoluteTime * pixelsPerBeat,
                  pitchToYAxis(event.pitch),
                  event.absoluteDuration * pixelsPerBeat,
                  20),
              Paint()..color = noteColor[200]);
          canvas.drawRect(
              Rect.fromLTWH(
                  event.absoluteTime * pixelsPerBeat + 3,
                  pitchToYAxis(event.pitch) + 3,
                  event.absoluteDuration * pixelsPerBeat - 6,
                  20 - 6.0),
              Paint()..color = noteColor);
        }
        else {
          canvas.drawRect(
              Rect.fromLTWH(
                  event.absoluteTime * pixelsPerBeat,
                  pitchToYAxis(event.pitch),
                  event.absoluteDuration * pixelsPerBeat,
                  20),
              Paint()..color = noteColor);
        }
      }
    }

    // set up y axis only offset
    canvas.restore();

    // draw *unscaled* stuff on top of midi notes
    for (final event in musicXML.events) {
      if (event is MusicXMLEventNote) {
        if (event.lyric != "") {
          TextSpan lyricSpan = new TextSpan(
              style: new TextStyle(color: Colors.grey[600]), text: event.lyric);
          TextPainter tp = new TextPainter(
              text: lyricSpan,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr);
          tp.layout();
          tp.paint(
              canvas,
              new Offset(
                  (event.absoluteTime * pixelsPerBeat +
                          xOffset +
                          pianoKeysWidth / xScale +
                          20) *
                      xScale,
                  (pitchToYAxis(event.pitch) + yOffset) * yScale - 20));
        }
      } else if (event is MusicXMLEventTempo) {
        var yPos = pitchToYAxisEx("C", 6);
        TextSpan lyricSpan = new TextSpan(
            style: new TextStyle(color: Colors.black, fontSize: 10 * yScale),
            text: "BPM: " + event.tempo.toStringAsFixed(2));
        TextPainter tp = new TextPainter(
            text: lyricSpan,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr);
        tp.layout();
        canvas.drawRect(
            Rect.fromLTWH(
                (event.absoluteTime * pixelsPerBeat +
                        xOffset +
                        pianoKeysWidth / xScale) *
                    xScale + 1,
                (yPos + yOffset) * yScale,
                (tp.width + 20),
                20 * yScale),
            Paint()..color = Colors.lightBlueAccent);
        tp.paint(
            canvas,
            new Offset(
                (event.absoluteTime * pixelsPerBeat +
                            xOffset +
                            pianoKeysWidth / xScale) *
                        xScale +
                    10,
                (yPos + yOffset) * yScale + tp.height / 4));
      } else if (event is MusicXMLEventTimeSignature) {
        var yPos = pitchToYAxisEx("C#", 6);
        TextSpan lyricSpan = new TextSpan(
            style: new TextStyle(color: Colors.black, fontSize: 10 * yScale),
            text: "Time Signature: " +
                event.beats.toString() +
                "/" +
                event.beatType.toString());
        TextPainter tp = new TextPainter(
            text: lyricSpan,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr);
        tp.layout();
        canvas.drawRect(
            Rect.fromLTWH(
                (event.absoluteTime * pixelsPerBeat +
                        xOffset +
                        pianoKeysWidth / xScale) *
                    xScale + 1,
                (yPos + yOffset) * yScale,
                (tp.width + 20),
                20 * yScale),
            Paint()..color = Colors.lightBlueAccent[100]);
        tp.paint(
            canvas,
            new Offset(
                (event.absoluteTime * pixelsPerBeat +
                            xOffset +
                            pianoKeysWidth / xScale) *
                        xScale +
                    10,
                (yPos + yOffset) * yScale + tp.height / 4));
      }
    }

    // back up translation
    canvas.save();

    // draw selection rect on untransformed canvas
    if(selectionRect != null) {
      final selPaintBorder = Paint();
      selPaintBorder.color = Colors.blue.withOpacity(0.75);
      selPaintBorder.style = PaintingStyle.stroke;
      final selPaint = Paint();
      selPaint.color = Colors.blue.withOpacity(0.3);
      selPaint.style = PaintingStyle.fill;
      canvas.drawRect(selectionRect,selPaintBorder);
      canvas.drawRect(selectionRect,selPaint);
    }

    // set up piano keys scaling
    canvas.scale(1, yScale);
    canvas.translate(0, yOffset);

    // draw shadow
    var shadowPath = new Path();
    shadowPath.addRect(Rect.fromLTWH(0, 0, pianoKeysWidth, 1920));
    canvas.drawShadow(shadowPath, Colors.black, 10, false);

    Paint whiteKeys = Paint()..color = Colors.white;
    Paint blackKeys = Paint()..color = Colors.black;
    List<String> toDraw = [
      "B",
      "A#",
      "A",
      "G#",
      "G",
      "F#",
      "F",
      "E",
      "D#",
      "D",
      "C#",
      "C"
    ];

    double keyIdx = 0;
    for (int octave = 8; octave > 0; octave--) {
      for (int noteID = 0; noteID < toDraw.length; noteID++) {
        final note = toDraw[noteID];
        if (note.endsWith("#")) {
          canvas.drawRect(
              Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), blackKeys);
        } else {
          canvas.drawRect(
              Rect.fromLTWH(0, (keyIdx) * 20, pianoKeysWidth, 20), whiteKeys);
        }

        canvas.drawLine(Offset(0, (keyIdx) * 20),
            Offset(pianoKeysWidth, (keyIdx) * 20), pitchGridDiv);

        keyIdx++;
      }
    }

    // restore up translation
    canvas.restore();

    // paint piano key labels without stretch
    keyIdx = 0;
    for (int octave = 8; octave > 0; octave--) {
      for (int noteID = 0; noteID < toDraw.length; noteID++) {
        var note = toDraw[noteID];
        var labelPainter = new TextPainter(
          text: new TextSpan(
              style: new TextStyle(
                  color: Colors.grey[600], fontSize: (12 * yScale)),
              text: note + octave.toString()),
          textAlign: TextAlign.right,
          textDirection: TextDirection.ltr,
        )..layout();
        labelPainter.paint(
            canvas,
            new Offset(pianoKeysWidth - 26 * yScale,
                ((keyIdx) * 20 + yOffset) * yScale + labelPainter.height / 10));

        keyIdx++;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
