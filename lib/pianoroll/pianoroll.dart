import "dart:async";
import "dart:ui";

import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:muon/controllers/muonnote.dart";
import "dart:math";

import "package:muon/controllers/muonproject.dart";
import "package:muon/serializable/muon.dart";
import 'package:synaps_flutter/synaps_flutter.dart';

class PianoRollPitch {
  String note;
  int octave;
}

class PianoRollControls {
  PianoRollPainter painter;
  _PianoRollState state;
}

typedef _onMouseHoverCallbackType = void Function(PianoRollControls pianoRoll,PointerEvent mouseEvent);
typedef _onClickCallbackType = void Function(PianoRollControls pianoRoll,PointerEvent mouseEvent,int numClicks);
typedef _onSelectCallbackType = void Function(PianoRollControls pianoRoll,PointerEvent mouseEvent,Rect selectionBox);
typedef _onKeyCallbackType = void Function(PianoRollControls pianoRoll,RawKeyEvent keyEvent);

abstract class PianoRollModule {
  _PianoRollState _state;
  _PianoRollState get state => _state;
  PianoRollPainter _painter;
  PianoRollPainter get painter => _painter;
  BuildContext _context;
  BuildContext get context => _context;

  PianoRoll get widget => _state.widget;
  MuonProjectController get project => widget.project;

  void attach(_PianoRollState state,PianoRollPainter painter,BuildContext context) {
    _state = state;
    _painter = painter;
    _context = context;
  }

  void detach() {
    _state = null;
    _painter = null;
    _context = null;
  }

  void dispose() {}

  /// Returns true if there is an object defined by this Module at this screen coordinate
  bool hitTest(Point point);

  /// Called when the mouse hovers around the screen
  void onHover(PointerEvent mouseEvent);

  /// Called on a mousedown event
  void onClick(PointerEvent mouseEvent,int numClicks);

  /// Called when the mouse starts dragging (slightly later after mouse down)
  /// Internally, it ensures the mouse moves at least 3 square pixels
  void onDragStart(PointerEvent mouseEvent,Point mouseStartPos);

  /// Called while the mouse is dragging something
  void onDragging(PointerEvent mouseEvent,Point mouseStartPos);

  /// Called when the mouse is finished dragging (on mouse up)
  void onDragEnd(PointerEvent mouseEvent,Point mouseStartPos);

  /// Called when the mouse is selecting something on the screen by clicking and dragging
  void onSelect(PointerEvent mouseEvent,Rect selectionBox);

  /// Called when there is a keyboard event
  void onKey(RawKeyEvent keyEvent);

  /// Called by the custom painter to allow this module to paint more things on top of the grid
  void paint(Canvas canvas,Size size);
}

class PianoRoll extends StatefulWidget {
  PianoRoll({
    @required this.project,
    this.onHover,
    this.onClick,
    this.onSelect,
    this.onKey,
    this.modules = const [],
  });

  final MuonProjectController project;
  final _onMouseHoverCallbackType onHover;
  final _onClickCallbackType onClick;
  final _onSelectCallbackType onSelect;
  final _onKeyCallbackType onKey;
  final List<PianoRollModule> modules;

  @override
  _PianoRollState createState() => _PianoRollState();
}

enum _PianoRollPointerMode {
  IDLE,
  LMB_CLICK,
  RMB_CLICK,
  PANNING,
  DRAGGING,
  SELECTING,
}

class _PianoRollState extends State<PianoRoll> {
  _PianoRollState();
  
  // Used by the custompainter
  double pianoKeysWidth = 150.0;
  double xOffset = -1.0;
  double yOffset = -1.0;
  double xScale = 1;
  double yScale = 1;

  // Used by the scrollzoompan controller
  // and also made available to any modules
  bool isCtrlKeyHeld = false;
  bool isAltKeyHeld = false;
  bool isShiftKeyHeld = false;

  // used by the mouse controller
  _PianoRollPointerMode pointerMode = _PianoRollPointerMode.IDLE;
  bool _hasMouseMovedSignificantly = false;
  Point _firstMouseDownPos;
  Timer _lastClickTimeDecay;
  int _lastClickCount = 0;
  PianoRollModule currentlyDraggingModule;
  Rect selectionRect;

  /// Current mouse cursor
  MouseCursor cursor = MouseCursor.defer;

  /// Current mouse position
  Point curMousePos;

  // Why am I doing this, you ask?
  // Because flutter uses arrow keys for Focus traversal
  // but i don't want that. I couldn't find an easy way to achieve this
  // whilst preserving my onKey callback, so we're using this ugly hack
  // Enjoy!
  final Map<LogicalKeySet, Intent> _disabledNavigationKeys = <LogicalKeySet, Intent>{
    LogicalKeySet(LogicalKeyboardKey.arrowUp): Intent.doNothing,
    LogicalKeySet(LogicalKeyboardKey.arrowDown): Intent.doNothing,
    LogicalKeySet(LogicalKeyboardKey.arrowLeft): Intent.doNothing,
    LogicalKeySet(LogicalKeyboardKey.arrowRight): Intent.doNothing,
  };

  // why initialise the FocusNode here and not in the parent class, you ask?
  // I have no idea why but when I initialise the FocusNode in the parent,
  // focus logic breaks after the first hot reload. I do not have the patience
  // to figure out why.
  final focusNode = FocusNode();

  @override
  void initState() {
    RawKeyboard.instance.addListener(_keyListener);
    super.initState();
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_keyListener);
          
    for(final module in widget.modules) {
      module.dispose();
      module.detach();
    }
    
    super.dispose();
  }

  _keyListener(RawKeyEvent event) {
    isShiftKeyHeld = event.isShiftPressed;
    isAltKeyHeld = event.isAltPressed;
    isCtrlKeyHeld = event.isControlPressed;
  }

  void setCursor(MouseCursor cursor) {
    setState(() {
      this.cursor = cursor;
    });
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

  void onScrollZoomPan(PointerScrollEvent details,BoxConstraints constraints) {
    setState(() {
      if (isShiftKeyHeld && !isCtrlKeyHeld) {
        xOffset = xOffset - details.scrollDelta.dy / xScale;
        yOffset = yOffset - details.scrollDelta.dx / yScale;

        this.clampXY(constraints.maxHeight);
      } else {
        if (isShiftKeyHeld) {
          double targetScaleX = max(
              0.0625, min(4, xScale - details.scrollDelta.dy / 320));
          double xPointer = details.localPosition.dx - pianoKeysWidth;
          double xTarget = (xPointer / xScale - xOffset);

          xScale = targetScaleX;
          xOffset = -xTarget + xPointer / xScale;
        }
        else if (isCtrlKeyHeld) {
          double targetScaleY = max(
              0.25, min(4, yScale - details.scrollDelta.dy / 80));
          if (((constraints.maxHeight / targetScaleY) <= 1920) ||
              (details.scrollDelta.dy < 0)) {
            // only attempt scale if it wont look stupid
            double yPointer = details.localPosition.dy;
            double yTarget = (yPointer / yScale - yOffset);

            yScale = targetScaleY;
            yOffset = -yTarget + yPointer / yScale;
          }
        }

        if (!isShiftKeyHeld && !isCtrlKeyHeld) {
          yOffset = yOffset - details.scrollDelta.dy / yScale;
          xOffset = xOffset - details.scrollDelta.dx / xScale * 2;
        }

        this.clampXY(constraints.maxHeight);
      }
    });
  }

  void onPointerHover(PointerHoverEvent details,PianoRollControls controls) {
    curMousePos = Point(details.localPosition.dx,details.localPosition.dy);
    if((_lastClickTimeDecay == null) || (_firstMouseDownPos == null)) {
      _lastClickCount = 0;
    }
    else if(curMousePos.squaredDistanceTo(_firstMouseDownPos) > 9) {
      _lastClickCount = 0;
    }

    if(widget.onHover != null) {
      widget.onHover(controls,details);
    }

    for(final module in widget.modules) {
      module.onHover(details);
    }
  }

  void onPointerDown(PointerDownEvent details) {
    if((details.buttons & kMiddleMouseButton) == kMiddleMouseButton) {
      // Middle mouse events are always pans
      pointerMode = _PianoRollPointerMode.PANNING;
    }
    else if((details.buttons & kPrimaryMouseButton) == kPrimaryMouseButton) {
      // Left mouse events are ambiguous.
      // If the mouseup event immediately follows the mousedown OR
      // If the mouse stays within 3 square pixels of the mousedown pos, it's a click
      // Otherwise, two things can happen:
      // 1. If the mousedown occurred over a module.hitTest() == true point, it starts a drag event
      // 2. Elsewhere, it starts a select event
      // This logic is handled in onPointerMove

      final screenPos = Point(details.localPosition.dx,details.localPosition.dy);

      pointerMode = _PianoRollPointerMode.LMB_CLICK;

      // save the first mousedown pos so that onPointerMove can calculate pointer move distance
      // and also use it in the callbacks to modules/etc. 
      _firstMouseDownPos = screenPos;
      _hasMouseMovedSignificantly = false;

      // Reset last click count if the timer has timed out (OR if the user clicks more than 2 times).
      _lastClickCount++;
      if((_lastClickTimeDecay == null) || (_lastClickCount >= 2)) {
        _lastClickCount = 0;
      }
    }
  }

  void onPointerMove(PointerMoveEvent details,BoxConstraints constraints,PianoRollControls controls) {
    final screenPos = Point(details.localPosition.dx,details.localPosition.dy);
    curMousePos = screenPos;

    if(!_hasMouseMovedSignificantly && (pointerMode == _PianoRollPointerMode.LMB_CLICK)) {
      if(_firstMouseDownPos == null) {
        // This should never happen, but I'm paranoid I guess? haha
        _firstMouseDownPos = screenPos;
      }

      if(curMousePos.squaredDistanceTo(_firstMouseDownPos) > 9) {
        _hasMouseMovedSignificantly = true;

        // mouse started moving for the first time after mousedown

        if(_firstMouseDownPos == null) {
          _firstMouseDownPos = screenPos;
        }

        PianoRollModule hitTestPassedModule;
        for(int modIdx=widget.modules.length-1;modIdx >=0;modIdx--) {
          final module = widget.modules[modIdx];

          if(module.hitTest(_firstMouseDownPos)) {
            hitTestPassedModule = module;
            break;
          }
        }
        
        if(hitTestPassedModule != null) {
          // There is something under the pointer
          // therefore, start dragging

          pointerMode = _PianoRollPointerMode.DRAGGING;
          currentlyDraggingModule = hitTestPassedModule;
          currentlyDraggingModule.onDragStart(details,_firstMouseDownPos);
        }
        else if(details.kind == PointerDeviceKind.touch) {
          // touchscreens default to panning
          pointerMode = _PianoRollPointerMode.PANNING;
        }
        else {
          // otherwise start selecting
          pointerMode = _PianoRollPointerMode.SELECTING;
        }
      }
    }

    if(_hasMouseMovedSignificantly) {
      _lastClickCount = 0;
    }

    if (pointerMode == _PianoRollPointerMode.PANNING) {
      setState(() {
        xOffset = xOffset + details.delta.dx / xScale;
        yOffset = yOffset + details.delta.dy / yScale;

        this.clampXY(constraints.maxHeight);
      });
    }
    else if (pointerMode == _PianoRollPointerMode.SELECTING) {
      setState(() {
        var left = min(_firstMouseDownPos.x, details.localPosition.dx);
        var right = max(_firstMouseDownPos.x, details.localPosition.dx);
        var top = min(_firstMouseDownPos.y, details.localPosition.dy);
        var bottom = max(_firstMouseDownPos.y, details.localPosition.dy);
        selectionRect = Rect.fromLTRB(left,top,right,bottom);

        if(widget.onSelect != null) {
          widget.onSelect(controls,details,selectionRect);
        }

        for(final module in widget.modules) {
          module.onSelect(details,selectionRect);
        }
      });
    }
    else if (pointerMode == _PianoRollPointerMode.DRAGGING) {
      currentlyDraggingModule?.onDragging(details,_firstMouseDownPos);
    }
  }

  void onPointerUp(PointerUpEvent details,PianoRollControls controls) {
    // Pointer has stopped clicking, so it's time to clean up state

    if(pointerMode == _PianoRollPointerMode.SELECTING) {
      // Fire the final onSelect events
      if(widget.onSelect != null) {
        widget.onSelect(controls,details,selectionRect);
      }

      for(final module in widget.modules) {
        module.onSelect(details,selectionRect);
      }

      setState(() {
        // Free the selection rect
        // (inside setstate because it is used in the custompaint widget)
        selectionRect = null;
      });
    }
    else if(pointerMode == _PianoRollPointerMode.PANNING) {
      // No special state to free
    }
    else if(pointerMode == _PianoRollPointerMode.DRAGGING) {
      // finish dragging something!
      currentlyDraggingModule?.onDragEnd(details,_firstMouseDownPos);
      currentlyDraggingModule = null;
    }
    else if(pointerMode == _PianoRollPointerMode.LMB_CLICK) {
      // click!
      if(widget.onClick != null) {
        widget.onClick(controls,details,_lastClickCount + 1);
      }

      for(final module in widget.modules) {
        module.onClick(details,_lastClickCount + 1);
      }

      // Special logic for consecutive clicks:
      // If the second mousedown event occurs within 300 milliseconds
      // it increments a clickCount variable
      // Otherwise, it is reset
      if(_lastClickTimeDecay != null) {
        _lastClickTimeDecay.cancel();
      }

      _lastClickTimeDecay = new Timer(Duration(milliseconds: 300),() {
        _firstMouseDownPos = null;
        _lastClickTimeDecay = null;
      });
    }

    // Reset hasMouseMovedSignificantly to false
    _hasMouseMovedSignificantly = false;

    pointerMode = _PianoRollPointerMode.IDLE;
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Shortcuts(
      // Disable flutter's focus traversal
      shortcuts: _disabledNavigationKeys,

      child: Row(mainAxisSize: MainAxisSize.max, children: [
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          if ((xOffset == -1) && (yOffset == -1)) {
            // first run: scroll to C#6
            xOffset = 0;
            yOffset = -PianoRollPainter.pitchToYAxisEx("C#", 6);
          }

          // Use the LayoutBuilder's constraints to ensure that the
          // scale/offsets are appropriate for our current window height
          this.clampXY(constraints.maxHeight);

          var rectPainter = PianoRollPainter(widget.project, themeData,
              pianoKeysWidth, xOffset, yOffset, xScale, yScale, selectionRect, curMousePos, widget.modules);

          final controls = PianoRollControls();
          controls.painter = rectPainter;
          controls.state = this;
          
          for(final module in widget.modules) {
            module.attach(this,rectPainter,context);
          }

          return RawKeyboardListener(
            focusNode: focusNode,
            autofocus: true,
            onKey: (RawKeyEvent event) {
              // Forward keyevents to listeners
              if(widget.onKey != null) {
                widget.onKey(controls,event);
              }

              for(final module in widget.modules) {
                module.onKey(event);
              }
            },
            child: MouseRegion(
              cursor: cursor,
              child: Listener(
                onPointerSignal: (details) {
                  if (details is PointerScrollEvent) {
                    this.onScrollZoomPan(details, constraints);
                  }
                },
                onPointerDown: onPointerDown,
                onPointerUp: (details) => onPointerUp(details,controls),
                onPointerMove: (details) => onPointerMove(details,constraints,controls),
                onPointerHover: (details) => onPointerHover(details,controls),
                child: Container(
                  color: themeData.scaffoldBackgroundColor,
                  child: RxCustomPaint(
                    painter: rectPainter,
                    child: Container(),
                    willChange: true,
                  ),
                ),
              ),
            ),
          );
        }))
      ]),
    );
  }
}

class PianoRollPainter extends CustomPainter {
  PianoRollPainter(this.project, this.themeData, this.pianoKeysWidth, this.xOffset, this.yOffset, this.xScale,
      this.yScale, this.selectionRect, this.curMousePos, this.modules) : super();
  final MuonProjectController project;
  final ThemeData themeData;
  final double pianoKeysWidth;
  final double xOffset;
  final double yOffset;
  final double xScale;
  final double yScale;
  final Rect selectionRect;
  final Point curMousePos;
  final List<PianoRollModule> modules;

  final double pixelsPerBeat = 500;

  double get xPos {
    return -xOffset;
  }

  double get yPos {
    return -yOffset;
  }

  static Map<String, int> pitchMap = {
    "C": 11,
    "C#": 10,
    "D": 9,
    "D#": 8,
    "E": 7,
    "F": 6,
    "F#": 5,
    "G": 4,
    "G#": 3,
    "A": 2,
    "A#": 1,
    "B": 0,
  };
  static Map<int, String> pitchMapReverse =
      pitchMap.map((key, value) => new MapEntry(value, key));
  static double pitchToYAxis(MuonNoteController pitch) {
    return pitchToYAxisEx(pitch.note, pitch.octave);
  }

  static double pitchToYAxisEx(String note, int octave) {
    return (pitchMap[note] * 20 + 12 * 20 * (8 - octave)).toDouble();
  }

  double getCurrentLeftmostBeat() {
    return xPos / pixelsPerBeat;
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

  Rect screenRectToCanvasRect(Rect screenRect, bool outsideGrid) {
    if (!outsideGrid) {
      return Rect.fromLTRB(
        (screenRect.left - pianoKeysWidth) / xScale - xOffset,
        screenRect.top / yScale - yOffset,
        (screenRect.right - pianoKeysWidth) / xScale - xOffset,
        screenRect.bottom / yScale - yOffset,
      );
    } else {
      return Rect.fromLTRB(
        screenRect.left / xScale - xOffset,
        screenRect.top / yScale - yOffset,
        screenRect.right / xScale - xOffset,
        screenRect.bottom / yScale - yOffset,
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

  Rect deflateScaled(Rect rect,double deflateBy) {
    final deflateByX = deflateBy / xScale;
    final deflateByY = deflateBy / yScale;

    return Rect.fromLTWH(
      rect.left + deflateByX / 2,
      rect.top + deflateByY / 2,
      rect.width - deflateByX,
      rect.height - deflateByY,
    );
  }

  double getBeatNumAtCursor(double screenPosX) {
    var canvasX = screenPosX / xScale - xOffset;
    var internalCanvasX = (canvasX * xScale - pianoKeysWidth) / xScale;

    return internalCanvasX / pixelsPerBeat;
  }

  double screenPixelsToBeats(double screenPixels) {
    return (screenPixels / xScale) / pixelsPerBeat;
  }

  double screenPixelsToSemitones(double screenPixels) {
    return ((-screenPixels / yScale) / 20);
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

  double scaleTextSize(double textSize) {
    return textSize * yScale;
  }

  /// assumes that we are currently drawing inside the grid
  void drawTextAt(Canvas canvas,Offset point,int textSize, InlineSpan text,[TextAlign textAlign = TextAlign.left]) {
    // clear all transforms
    canvas.restore();

    // draw text
    TextPainter tp = new TextPainter(
      text: text,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      new Offset(
        (point.dx + xOffset) * xScale + pianoKeysWidth,
        (point.dy + yOffset) * yScale
      ),
    );

    // back up transforms
    canvas.save();
    
    // restore transforms
    noteCoordinateSystem(canvas);
  }

  void noteCoordinateSystem(Canvas canvas) {
    canvas.scale(xScale, yScale);
    canvas.translate(xOffset + pianoKeysWidth / xScale, yOffset);
  }

  void drawUnscaled(Canvas canvas,Function cb) {
    // clear all transforms
    canvas.restore();

    cb();

    // back up transforms
    canvas.save();
    
    // restore transforms
    noteCoordinateSystem(canvas);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Clip to viewable area
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Save current state
    canvas.save();

    // set up x axis offset for grid
    // and scale appropriately
    noteCoordinateSystem(canvas);

    // draw pitch grid
    Paint pitchGridDiv = Paint()..color = themeData.brightness == Brightness.light ? Colors.grey[200] : Colors.grey[600];
    Paint pitchGridOctaveDiv = Paint()..color = themeData.brightness == Brightness.light ? Colors.grey[400] : Colors.white;
    double firstVisibleKey = (yPos / 20).floorToDouble();
    int visibleKeys = ((size.height / yScale) / 20).floor();
    for (int i = 0; i <= visibleKeys; i++) {
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
    Paint subBeatDiv = Paint()..color = themeData.brightness == Brightness.light ? Colors.grey[200] : Colors.grey[800];
    Paint beatDiv = Paint()..color = themeData.brightness == Brightness.light ? Colors.grey : Colors.grey[600];
    Paint measureDiv = Paint()..color = themeData.brightness == Brightness.light ? Colors.black : Colors.white;
    int beats = project.beatsPerMeasure;

    double beatDuration = pixelsPerBeat;
    double leftMostBeat = getCurrentLeftmostBeat().floorToDouble();
    double leftMostBeatPos = leftMostBeat * pixelsPerBeat;
    int beatsInView = ((size.width / xScale) / beatDuration).ceil();

    for (int rawI = 0; rawI <= ((beatsInView + 1) * project.currentSubdivision); rawI++) {
      double i = rawI / project.currentSubdivision;
      var curBeatIdx = leftMostBeat + i;
      if (curBeatIdx % beats == 0) {
        canvas.drawLine(Offset(leftMostBeatPos + i * beatDuration, 0),
            Offset(leftMostBeatPos + i * beatDuration, 1920), measureDiv);
      } else if (i % 1 == 0) {
        canvas.drawLine(Offset(leftMostBeatPos + i * beatDuration, 0),
            Offset(leftMostBeatPos + i * beatDuration, 1920), beatDiv);
      } else {
        canvas.drawLine(Offset(leftMostBeatPos + i * beatDuration, 0),
            Offset(leftMostBeatPos + i * beatDuration, 1920), subBeatDiv);
      }
    }

    // draw playhead
    final playhead = Paint();
    playhead.color = themeData.indicatorColor.withOpacity(0.75);
    playhead.strokeWidth = 2 / xScale;
    final playheadXVal = project.playheadTime * pixelsPerBeat;
    canvas.drawVertices(
      new Vertices(
        VertexMode.triangles,
        [
          Offset(playheadXVal - 15 / xScale,-yOffset),
          Offset(playheadXVal + 15 / xScale,-yOffset),
          Offset(playheadXVal,-yOffset + 15 / yScale),
        ]
      ), 
      BlendMode.overlay, 
      playhead
    );
    canvas.drawVertices(
      new Vertices(
        VertexMode.triangles,
        [
          Offset(playheadXVal - 15 / xScale,-yOffset + size.height / yScale),
          Offset(playheadXVal + 15 / xScale,-yOffset + size.height / yScale),
          Offset(playheadXVal,-15 / yScale + -yOffset + size.height / yScale),
        ]
      ), 
      BlendMode.overlay, 
      playhead
    );
    canvas.drawLine(Offset(playheadXVal,-yOffset + 14 / yScale),Offset(playheadXVal,-yOffset + size.height / yScale - 14 / yScale),playhead);


    for(final module in modules) {
      module.paint(canvas,size);
    }

    // set up y axis only offset
    canvas.restore();

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
