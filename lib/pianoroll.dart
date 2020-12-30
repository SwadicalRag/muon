import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:muon/controllers/muonnote.dart';
import 'dart:math';

import 'package:muon/controllers/muonproject.dart';
import 'package:muon/serializable/muon.dart';

class PianoRollPitch {
  String note;
  int octave;
}

class PianoRoll extends StatefulWidget {
  PianoRoll(this.project,this.selectedNotes);

  final MuonProjectController project;
  final Map<MuonNoteController,bool> selectedNotes;

  @override
  _PianoRollState createState() => _PianoRollState(project,selectedNotes);
}

class _PianoRollState extends State<PianoRoll> {
  _PianoRollState(this.project,this.selectedNotes);
  final MuonProjectController project;
  final Map<MuonNoteController,bool> selectedNotes;
  
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
    final themeData = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.max, children: [
      Expanded(child: LayoutBuilder(builder: (context, constraits) {
        if ((xOffset == -1) && (yOffset == -1)) {
          // first run: scroll to C#6
          xOffset = 0;
          yOffset = -PianoRollPainter.pitchToYAxisEx("C#", 6);
        }

        this.clampXY(constraits.maxHeight);

        var rectPainter = PianoRollPainter(project, selectedNotes, themeData,
            pianoKeysWidth, xOffset, yOffset, xScale, yScale, selectionRect);

        return Listener(
          onPointerSignal: (details) {
            if (details is PointerScrollEvent) {
              setState(() {
                if (isShiftKeyHeld) {
                  xOffset = xOffset - details.scrollDelta.dy / xScale;

                  this.clampXY(constraits.maxHeight);
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
                    if (((constraits.maxHeight / targetScaleY) <= 1920) ||
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

                  this.clampXY(constraits.maxHeight);
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

                this.clampXY(constraits.maxHeight);
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

            // var eventAtCursor = rectPainter.getNoteAtScreenPos(screenPos);
            // print("event " + eventAtCursor.toString());

            // if(eventAtCursor != null) {
            //   setState(() {
            //     selectedNotes.putIfAbsent(eventAtCursor, () => true);
            //   });
            // }
          },
          child: Container(
            color: themeData.scaffoldBackgroundColor,
            child: CustomPaint(
              painter: rectPainter,
              child: Container(),
              willChange: true,
            ),
          ),
        );
      }))
    ]);
  }
}

class PianoRollPainter extends CustomPainter {
  PianoRollPainter(this.project, this.selectedNotes, this.themeData, this.pianoKeysWidth, this.xOffset, this.yOffset, this.xScale,
      this.yScale, this.selectionRect);
  final MuonProjectController project;
  final Map<MuonNoteController,bool> selectedNotes;
  final ThemeData themeData;
  final double pianoKeysWidth;
  final double xOffset;
  final double yOffset;
  final double xScale;
  final double yScale;
  final Rect selectionRect;

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
  static double pitchToYAxis(MuonNoteController pitch) {
    return pitchToYAxisEx(pitch.note.value, pitch.octave.value);
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

  PianoRollPitch getPitchAtCursor(double screenPosY) {
    var canvasY = screenPosY / yScale - yOffset;

    var pitchDiv = (canvasY / 20).floor();
    var rawOctave = (pitchDiv / 12).floor();
    var noteID = pitchDiv - rawOctave * 12;

    var pitch = new PianoRollPitch();
    pitch.note = pitchMapReverse[noteID];
    pitch.octave = 8 - rawOctave;

    return pitch;
  }

  MuonNoteController getNoteAtScreenPos(Point screenPos) {
    // O(n), LOOK AWAY!
    // I DON'T CARE

    final canvasPos = screenPosToCanvasPos(screenPos, false);

    for (final voice in project.voices) {
      for (final note in voice.notes) {
        var noteX = note.startAtTime * pixelsPerBeat;
        var noteY = pitchToYAxis(note);
        var noteW = note.duration * pixelsPerBeat;
        var noteH = 20;

        if ((noteX < canvasPos.x) &&
            ((noteX + noteW) > canvasPos.x) &&
            (noteY < canvasPos.y) &&
            ((noteY + noteH) > canvasPos.y)) {
          return note;
        }
      }
    }

    return null;
  }

  static final noteColors = [
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
    // Clip to viewable area
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    print("Paint");

    // Save current state
    canvas.save();

    // set up x axis offset for grid
    // and scale appropriately
    canvas.scale(xScale, yScale);
    canvas.translate(xOffset + pianoKeysWidth / xScale, yOffset);

    // draw pitch grid
    Paint pitchGridDiv = Paint()..color = themeData.brightness == Brightness.light ? Colors.grey[200] : Colors.grey[600];
    Paint pitchGridOctaveDiv = Paint()..color = themeData.brightness == Brightness.light ? Colors.grey[400] : Colors.white;
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
    Paint beatDiv = Paint()..color = themeData.brightness == Brightness.light ? Colors.grey : Colors.grey[600];
    Paint measureDiv = Paint()..color = themeData.brightness == Brightness.light ? Colors.black : Colors.white;
    int beats = project.beatsPerMeasure.value;

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

    // draw notes on top of the grid
    int voiceID = 0;
    for (final voice in project.voices) {
      voiceID++;
      for (final note in voice.notes) {
        // print("Abs" + (event.absoluteTime).toString());
        var noteColor = noteColors[voiceID % noteColors.length];
        if(selectedNotes.containsKey(note)) {
          final xBorderThickness = 5;
          final yBorderThickness = 5;
          if(themeData.brightness == Brightness.dark) {
            canvas.drawRect(
                Rect.fromLTWH(
                    note.startAtTime * pixelsPerBeat,
                    pitchToYAxis(note),
                    note.duration * pixelsPerBeat,
                    20),
                Paint()..color = Colors.white);
            canvas.drawRect(
                Rect.fromLTWH(
                    note.startAtTime * pixelsPerBeat,
                    pitchToYAxis(note),
                    note.duration * pixelsPerBeat,
                    20),
                Paint()..color = noteColor.withOpacity(0.75));
          }
          else {
            canvas.drawRect(
                Rect.fromLTWH(
                    note.startAtTime * pixelsPerBeat,
                    pitchToYAxis(note),
                    note.duration * pixelsPerBeat,
                    20),
                Paint()..color = noteColor.withOpacity(0.5));
          }
          canvas.drawRect(
              Rect.fromLTWH(
                  note.startAtTime * pixelsPerBeat + xBorderThickness / xScale,
                  pitchToYAxis(note) + yBorderThickness / yScale,
                  note.duration * pixelsPerBeat - xBorderThickness / xScale * 2,
                  20 - yBorderThickness / yScale * 2),
              Paint()..color = noteColor);
        }
        else {
          if(themeData.brightness == Brightness.light) {
            canvas.drawRect(
                Rect.fromLTWH(
                    note.startAtTime * pixelsPerBeat,
                    pitchToYAxis(note),
                    note.duration * pixelsPerBeat,
                    20),
                Paint()..color = noteColor);
          }
          else {
            final xBorderThickness = 0;
            final yBorderThickness = 0;
            canvas.drawRect(
                Rect.fromLTWH(
                    note.startAtTime * pixelsPerBeat,
                    pitchToYAxis(note),
                    note.duration * pixelsPerBeat + xBorderThickness / xScale,
                    20),
                Paint()..color = Colors.black);
            canvas.drawRect(
                Rect.fromLTWH(
                    note.startAtTime * pixelsPerBeat + xBorderThickness / xScale,
                    pitchToYAxis(note) + yBorderThickness  / yScale,
                    note.duration * pixelsPerBeat - xBorderThickness  / xScale,
                    20 - (yBorderThickness / yScale * 2)),
                Paint()..color = noteColor.withOpacity(0.95));
          }
        }
      }
    }

    // set up y axis only offset
    canvas.restore();

    // draw *unscaled* stuff on top of midi notes
    for (final voice in project.voices) {
      for (final note in voice.notes) {
        if (note.lyric.value != "") {
          TextSpan lyricSpan = new TextSpan(
              style: new TextStyle(color: themeData.brightness == Brightness.light ? Colors.grey[600] : Colors.grey[300]), text: note.lyric.value);
          TextPainter tp = new TextPainter(
              text: lyricSpan,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr);
          tp.layout();
          tp.paint(
              canvas,
              new Offset(
                  (note.startAtTime * pixelsPerBeat +
                          xOffset +
                          pianoKeysWidth / xScale +
                          20) *
                      xScale,
                  (pitchToYAxis(note) + yOffset) * yScale - 20));
        }
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

    Paint whiteKeys = Paint()..color = themeData.brightness == Brightness.light ? Colors.white : Colors.grey[100];
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
