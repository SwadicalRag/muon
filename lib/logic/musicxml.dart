import "dart:io";
import "dart:math";

import "package:universal_html/html.dart" as html show Node,Element;
import "package:universal_html/parsing.dart" as html show parseXmlDocument;

class MusicXMLEvent {
  /// The time offset of this event, measured in beats (i.e. how much
  ///  time needs to pass before this event is triggered)
  double absoluteTime;
  
  /// The time offset of this event, measured in divisions (i.e. how much
  ///  time needs to pass before this event is triggered)
  /// 
  /// NB: `x` beats `= x * divisionsPerBeat` divisions
  /// 
  double time;
  
  /// The duration of this event, measured in divisions
  double duration = 0;
  
  MusicXMLEventTempo lastTempo;
  MusicXMLEventTimeSignature lastTimeSignature;
  MusicXMLEventDivision lastDivision;

  /// This constructor internally populates
  /// [lastTempo], [lastTimeSignature] and [lastDivision]
  MusicXMLEvent(MusicXML parent) {
    if(this is MusicXMLEventTempo) {
      lastTempo = this;
    }
    else {
      lastTempo = parent.lastTempo;
    }

    if(this is MusicXMLEventTimeSignature) {
      lastTimeSignature = this;
    }
    else {
      lastTimeSignature = parent.lastTimeSignature;
    }

    if(this is MusicXMLEventDivision) {
      lastDivision = this;
    }
    else {
      lastDivision = parent.lastDivision;
    }
  }

  /// The duration of this event, measured in beats
  double get absoluteDuration {
    int divisions = 1;

    if(lastDivision != null) {
      divisions = lastDivision.divisions;
    }

    return (duration / divisions);
  }
}

class MusicXMLEventDivision extends MusicXMLEvent {
  MusicXMLEventDivision(MusicXML parent) : super(parent);

  /// Number of divisions per beat
  /// Should never be zero
  int divisions;
}


class MusicXMLEventTempo extends MusicXMLEvent {
  MusicXMLEventTempo(MusicXML parent) : super(parent);

  /// Beats per minute
  double tempo;
}

class MusicXMLEventTimeSignature extends MusicXMLEvent {
  MusicXMLEventTimeSignature(MusicXML parent) : super(parent);

  /// Beats per measure (numerator in a time signature)
  int beats;

  /// Quantity of each beat (denominator in a time signature)
  /// 
  /// Example values are powers of 2
  /// `2`, `4`, `8`, `16`, ...
  int beatType;
}

class MusicXMLPitch {
  int octave;
  String note;

  /// returns true if both pitches are on the same
  /// octave and have the same note value
  bool isEqualTo(MusicXMLPitch other) {
    if(other.octave == octave) {
      if(other.note == note) {
        return true;
      }
    }

    return false;
  }
}

class MusicXMLEventVoiced extends MusicXMLEvent {
  MusicXMLEventVoiced(MusicXML parent) : super(parent);

  /// The MusicXML voice of this event
  /// Doesn't have any special use case in Muon
  int voice;
}

class MusicXMLEventRest extends MusicXMLEventVoiced {
  MusicXMLEventRest(MusicXML parent) : super(parent);
}

class MusicXMLEventNote extends MusicXMLEventVoiced {
  MusicXMLEventNote(MusicXML parent) : super(parent);
  String lyric;

  MusicXMLPitch pitch;

  /// Used internally to merge multiple notes
  bool compoundNote = false;

  /// Used internally to merge multiple notes
  bool compoundNoteResolved = false;
}

/// Used internally to convert divisions to note types
class _NoteResolution {
  String noteType;
  int dots;
  double beats;
}

/// 
/// The MusicXML class is an approximation of all of the data contained inside
/// a MusicXML file. It does not completely follow the Music XML spec!
/// My primary aim was to get an implementation of MusicXML that Neutrino accepts
/// and making an official spec compatible MusicXML parser and serializer is not
/// this project's goal.
/// 
/// That being said, the logic below does generalise well to most common MusicXML
/// files, and is robust enough to at least parse MusicXML, and serialize data
/// to a format that Neutrino almost always accepts.
/// 
/// NB: When serializing very complicated time intervals, the below logic does not
/// generate tuplets/etc. and will just fall back to not annotating notes appropriately.
/// Since Neutrino does not care about having proper annotations and tuplets, this is
/// therefore not implemented properly on purpose. The goal of this project is to speak
/// with Neutrino, and not to speak with something like Musescore.
/// 
class MusicXML {
  /// The list of all events (notes/rests/time data) contained in the MusicXML
  List<MusicXMLEvent> events = [];

  /// The total duration of all the events contained in this file, measured in divisions
  /// 
  /// NB: `x` beats `= x * divisionsPerBeat` divisions
  /// 
  double duration = 0.0;

  /// The total duration of all the events contained in this file, measured in beats
  double absoluteDuration = 0.0;

  MusicXMLEventTempo lastTempo;
  MusicXMLEventTimeSignature lastTimeSignature;
  MusicXMLEventDivision lastDivision;
  MusicXMLEventNote lastNote;

  /// 
  /// Adds a MusicXMLEvent to the list of events stored in this MusicXML class
  /// 
  /// Additionally also updates the [duration] and [absoluteDuration] fields of
  /// both the input `MusicXMLEvent` and this class
  /// 
  /// This will also keep track of the last Tempo/Time Signature/Division/Note
  /// events.
  /// 
  void addEvent(MusicXMLEvent event) {
    event.time = duration;
    event.absoluteTime = absoluteDuration;

    duration = duration + event.duration;
    absoluteDuration = absoluteDuration + event.absoluteDuration;

    if(event is MusicXMLEventTempo) {
      lastTempo = event;
    }
    else if(event is MusicXMLEventTimeSignature) {
      lastTimeSignature = event;
    }
    else if(event is MusicXMLEventDivision) {
      lastDivision = event;
    }
    else if(event is MusicXMLEventNote) {
      lastNote = event;
    }

    events.add(event);
  }

  /// Converts note duration (measured in divisions) to absolute
  /// duration (measured in beats)
  double noteDurationToAbsoluteTime(double noteDuration) {
    int divisions = 1;

    if(lastDivision != null) {
      divisions = lastDivision.divisions;
    }

    return noteDuration / divisions;
  }

  /// 
  /// Adds a rest (pause) for `duration` beats (for the given voice)
  /// 
  /// Internally creates a MusicXMLEventRest
  /// 
  void rest(double duration, int voice) {
    var rest = new MusicXMLEventRest(this);
    rest.voice = voice;
    rest.duration = duration;
    addEvent(rest);
  }

  /// 
  /// Similar to [addEvent], but merges the input `noteEvent` into a previous
  /// event IF the previous event is a compound note.
  /// 
  /// If the previous event is NOT a compound note, the input `noteEvent` is
  /// converted into a compound note so that it can accept any future
  /// requests to `mergeNote`s
  /// 
  /// If `resolve` is true, after performing the above logic and adding or updating 
  /// a compound note, it marks the last compound note as "complete", so
  /// it may no longer accept any note merges.
  /// 
  void mergeNote(MusicXMLEventNote noteEvent,bool resolve) {
    if(lastNote != null) {
      if(lastNote.compoundNote && !lastNote.compoundNoteResolved) {
        if(lastNote.pitch.isEqualTo(noteEvent.pitch)) {
          absoluteDuration = absoluteDuration + noteEvent.absoluteDuration;
          
          lastNote.duration += noteEvent.duration;
          duration = duration + noteEvent.duration;

          lastNote.compoundNoteResolved = resolve;

          return;
        }
      }
    }

    noteEvent.compoundNote = true;
    noteEvent.compoundNoteResolved = resolve;
    addEvent(noteEvent);
  }

  /// Resets [MusicXML.duration], [MusicXML.absoluteDuration], 
  ///  [MusicXMLEvent.time] and [MusicXMLEvent.absoluteTime] and recalculates
  /// their values by traversing [MusicXML.events]
  void recalculateAbsoluteTime() {
    duration = 0.0;
    absoluteDuration = 0.0;

    for(final event in events) {
      event.time = duration;
      event.absoluteTime = absoluteDuration;
    }
  }

  /// Increases ALL [MusicXMLEventDivision]s by a factor of `divMul`
  /// and also updates every single time/duration field appropriately
  /// by calling [recalculateAbsoluteTime]
  void multiplyDivisions(int divMul) {
    for(final event in events) {
      if(event is MusicXMLEventDivision) {
        event.divisions *= divMul;
      }
      event.duration *= divMul;
    }

    recalculateAbsoluteTime();
  }

  /// Aims to reduce every [MusicXMLEventDivision.divisions] as 
  /// much as possible by calculating the greatest common denominator
  /// of each time value and dividing the above by this result
  /// and also updates every single time/duration field appropriately
  /// by calling [recalculateAbsoluteTime]
  void factorDivisions() {
    // who cares about computational efficiency anyway
    
    int gcd(int a,int b) => (b == 0) ? a : gcd(b, a % b);
    int gcdArray(List<int> a) {
      int result = a[0];
      for(int i = 1; i < a.length; i++){
        result = gcd(result, a[i]);
      }
      return result;
    }

    List<int> allDurations = [];
    for(final event in events) {
      if(event.duration.floor() != 0) {
        allDurations.add(event.duration.floor());
      }
    }

    var lcmDuration = gcdArray(allDurations);

    if(lcmDuration > 1) {
      for(final event in events) {
        if(event is MusicXMLEventDivision) {
          event.divisions = (event.divisions / lcmDuration).floor();
        }
        event.duration /= lcmDuration;
      }
    }

    recalculateAbsoluteTime();
  }
}

class MusicXMLUtils {
  static html.Element _getChildElement(html.Element el, String tag) {
    for(final child in el.childNodes) {
      if(child is html.Element) {
        if(child.nodeName == tag) {
          return child;
        }
      }
    }

    return null;
  }

  static String _getChildText(html.Element el, String tag, String defaultVal) {
    var child = _getChildElement(el, tag);
    if (child != null) {
      return child.text;
    }

    return defaultVal;
  }

  static String _getChildAttributeText(html.Element el, String tag, String attribute, String defaultVal) {
    var child = _getChildElement(el, tag);
    if (child != null) {
      if(child.attributes[attribute] != null) {
        return child.attributes[attribute];
      }
    }

    return defaultVal;
  }

  static void _parseMeasure(html.Element measure,MusicXML out) {
    for(final el in measure.childNodes) {
      if(el is html.Element) {
        switch(el.nodeName) {
          case "attributes": {
            for(final attribute in el.childNodes) {
              switch(attribute.nodeName) {
                case "time": {
                  var timeSigEvent = MusicXMLEventTimeSignature(out);
                  for(final timeSignature in attribute.childNodes) {
                    if(timeSignature.nodeName == "beats") {
                      timeSigEvent.beats = int.parse(timeSignature.text);
                    }
                    else if(timeSignature.nodeName == "beat-type") {
                      timeSigEvent.beatType = int.parse(timeSignature.text);
                    }
                  }
                  out.addEvent(timeSigEvent);
                  break;
                }
                case "divisions": {
                  var divEvent = MusicXMLEventDivision(out);
                  divEvent.divisions = int.parse(attribute.text);
                  out.addEvent(divEvent);

                  break;
                }
                default: {
                  // ignore
                }
              }
            }
            break;
          }
          case "direction": {
            for(final directionData in el.childNodes) {
              if(directionData is html.Element) {
                if(directionData.nodeName == "sound") {
                  var tempoEvent = MusicXMLEventTempo(out);
                  tempoEvent.tempo = double.parse(directionData.getAttribute("tempo"));
                  out.addEvent(tempoEvent);
                }
              }
            }
            break;
          }
          case "sound": {
            var tempoEvent = MusicXMLEventTempo(out);
            tempoEvent.tempo = double.parse(el.getAttribute("tempo"));
            out.addEvent(tempoEvent);
            break;
          }
          case "note": {
            var duration = _getChildElement(el,"duration");
            if(duration == null) {continue;}
            
            var voiceRaw = _getChildText(el,"voice","1");
            int voice = int.parse(voiceRaw);

            var durationVal = double.parse(duration.text);

            var rest = _getChildElement(el,"rest");
            if(rest != null) {
              out.rest(durationVal,voice);
            }
            else {
              var noteEvent = MusicXMLEventNote(out);
              
              noteEvent.voice = voice;
              noteEvent.duration = durationVal;
              noteEvent.lyric = _getChildText(el,"lyric","").trim();

              var pitch = MusicXMLPitch();
              var pitchData = _getChildElement(el, "pitch");
              pitch.note = _getChildText(pitchData,"step","C");
              pitch.octave = int.parse(_getChildText(pitchData,"octave","4"));
              if(_getChildText(pitchData, "alter", "0") == "1") {
                pitch.note += "#";
              }
              noteEvent.pitch = pitch;

              String tieData = _getChildAttributeText(el,"tie","type","");
              if(tieData != "") {
                if(tieData == "stop") {
                  out.mergeNote(noteEvent,true);
                }
                else {
                  out.mergeNote(noteEvent,false);
                }
              }
              else {
                out.addEvent(noteEvent);
              }
            }

            break;
          }
          default: {
            print("Unhandled node: " + (el.nodeName ?? "?"));
          }
        }
      }
    }

  }

  static void _parseRootEl(html.Node rootEl,MusicXML out) {
    switch(rootEl.nodeName) {
      case "score-partwise": {
        for(final metaTags in rootEl.childNodes) {
          if(metaTags is html.Element) {
            if(metaTags.nodeName == "part") {
              for(final measure in metaTags.childNodes) {
                if(measure is html.Element) {
                  if(measure.nodeName == "measure") {
                    _parseMeasure(measure,out);
                  }
                  else {
                    print("Unhandled measure node: " + (measure.nodeName ?? "?"));
                  }
                }
              }
            }
          }
        }
        break;
      }
      default: {
        print("Unhandled root node: " + (rootEl.nodeName ?? "?"));
      }
    }
  }

  /// Opens the specified file, reads it, and parses it into a [MusicXML] class
  static MusicXML parseFile(String filePath) {
    final file = new File(filePath);
    final document = html.parseXmlDocument(file.readAsStringSync());

    final out = new MusicXML();

    for(final rootEl in document.childNodes) {
      _parseRootEl(rootEl, out);
    }

    return out;
  }

  /// Converts the input [MusicXML] class into an XML String
  static String serializeMusicXML(MusicXML musicXML) {
    String out = "";
    int indentLevel = 0;

    void append(str) => out += str;
    void indent() {
      indentLevel += 1;
      if(out.contains(RegExp("\n[ ]+\$"))) {
        out = out.replaceFirst(RegExp("\n[ ]+\$"), "");
        out += "\n" + (("    ") * indentLevel);
      }
    }
    void outdent() {
      indentLevel -= 1;
      if(out.contains(RegExp("\n[ ]+\$"))) {
        out = out.replaceFirst(RegExp("\n[ ]+\$"), "");
        out += "\n" + (("    ") * indentLevel);
      }
    }
    void newline() {
      if(!out.contains(RegExp("\n[ ]*\$"))) {
        out += "\n" + (("    ") * indentLevel);
      }
    }

    void beginTag(tagName,Map<String,String> attributes) {
      append("<");
      append(tagName);
      if(attributes.length > 0) {
        append(" ");
        for(final attrKey in attributes.keys) {
          append(attrKey);
          append("=");
          append('"');
          append(attributes[attrKey]);
          append('"');
        }
      }
      append(">");
      indent();
      newline();
    }

    void endTag(tagName) {
      outdent();
      newline();
      append("</");
      append(tagName);
      append(">");
      newline();
    }

    void valueTag(String tagName,String tagValue,Map<String,String> attributes) {
      append("<");
      append(tagName);
      if(attributes.length > 0) {
        append(" ");
        for(final attrKey in attributes.keys) {
          append(attrKey);
          append("=");
          append('"');
          append(attributes[attrKey]);
          append('"');
        }
      }
      
      append(">");
      append(tagValue);
      append("</");
      append(tagName);
      append(">");
    }

    void valueTagSelfClosing(String tagName,Map<String,String> attributes) {
      append("<");
      append(tagName);
      if(attributes.length > 0) {
        append(" ");
        for(final attrKey in attributes.keys) {
          append(attrKey);
          append("=");
          append('"');
          append(attributes[attrKey]);
          append('"');
        }
      }
      
      append(" />");
    }

    append("""<?xml version="1.0" encoding="utf-8"?>""");
    newline();
    append("""<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd"[]>""");
    newline();

    int curMeasureNum = 1;
    int lastDivision = 1;
    int lastBeats = 1;
    int lastBeatType = 1;
    double curBeat = 0;
    Map<double,String> divisionToNoteType = {};
    Map<double,String> divisionToDottedNoteType = {};
    Map<double,String> divisionToDoubleDottedNoteType = {};
    Map<double,String> divisionToTripleDottedNoteType = {};
    void regenerateDivisionMapping() {
      divisionToNoteType = {};
      double curDiv = (lastDivision * lastBeatType).toDouble();
      void addDiv(String type) {
        divisionToNoteType[curDiv] = type;
        divisionToDottedNoteType[curDiv * 3 / 2] = type;
        divisionToDoubleDottedNoteType[curDiv * 3 / 2 + curDiv * 3 / 2 / 2] = type;
        divisionToTripleDottedNoteType[curDiv * 3 / 2 + curDiv * 3 / 2 / 2 + curDiv * 3 / 2 / 2 / 2] = type;
        curDiv /= 2;
      }
      
      addDiv("whole");
      addDiv("half");
      addDiv("quarter");
      addDiv("eighth");
      addDiv("16th");
      addDiv("32nd");
      addDiv("64th");
      addDiv("128th");
    }
    regenerateDivisionMapping();

    _NoteResolution resolveNote(double beats) {
      var resolution = _NoteResolution();
      if(divisionToNoteType.containsKey(beats)) {
        resolution.beats = beats;
        resolution.dots = 0;
        resolution.noteType = divisionToNoteType[beats];
      }
      else {
        if(divisionToDottedNoteType.containsKey(beats)) {
          resolution.beats = beats;
          resolution.dots = 1;
          resolution.noteType = divisionToDottedNoteType[beats];
        }
        else if(divisionToDoubleDottedNoteType.containsKey(beats)) {
          resolution.beats = beats;
          resolution.dots = 2;
          resolution.noteType = divisionToDoubleDottedNoteType[beats];
        }
        else if(divisionToTripleDottedNoteType.containsKey(beats)) {
          resolution.beats = beats;
          resolution.dots = 3;
          resolution.noteType = divisionToTripleDottedNoteType[beats];
        }
      }
      
      if(resolution.dots != null) {
        return resolution;
      }

      return null;
    }

    _NoteResolution resolveNoteFallback(double beats) {
      var beatList = divisionToNoteType.keys.toList();
      beatList.sort((a,b) => b.compareTo(a));
      
      var beatListDotted = divisionToDottedNoteType.keys.toList();
      beatListDotted.sort((a,b) => b.compareTo(a));
      
      var beatListDoubleDotted = divisionToDoubleDottedNoteType.keys.toList();
      beatListDoubleDotted.sort((a,b) => b.compareTo(a));
      
      var beatListTripleDotted = divisionToTripleDottedNoteType.keys.toList();
      beatListTripleDotted.sort((a,b) => b.compareTo(a));

      for(int i=0;i < beatList.length;i++) {
        final noteTime = beatList[i];
        final noteTimeDotted = beatListDotted[i];
        final noteTimeDoubleDotted = beatListDoubleDotted[i];
        final noteTimeTripleDotted = beatListTripleDotted[i];
        if(beats >= noteTimeTripleDotted) {
          _NoteResolution resolution = _NoteResolution();
          resolution.beats = noteTimeTripleDotted;
          resolution.dots = 3;
          resolution.noteType = divisionToTripleDottedNoteType[noteTimeTripleDotted];
          return resolution;
        }
        else if(beats >= noteTimeDoubleDotted) {
          _NoteResolution resolution = _NoteResolution();
          resolution.beats = noteTimeDoubleDotted;
          resolution.dots = 2;
          resolution.noteType = divisionToDoubleDottedNoteType[noteTimeDoubleDotted];
          return resolution;
        }
        else if(beats >= noteTimeDotted) {
          _NoteResolution resolution = _NoteResolution();
          resolution.beats = noteTimeDotted;
          resolution.dots = 1;
          resolution.noteType = divisionToDottedNoteType[noteTimeDotted];
          return resolution;
        }
        else if(beats >= noteTime) {
          _NoteResolution resolution = _NoteResolution();
          resolution.beats = noteTime;
          resolution.dots = 0;
          resolution.noteType = divisionToNoteType[noteTime];
          return resolution;
        }
      }

      return null;
    }

    _NoteResolution resolveNoteFallbackDiscrete(int beats) {
      var lhs = (beats / 2).floor();
      var rhs = beats - lhs;

      var lhsRes = resolveNote(lhs.toDouble());
      var rhsRes = resolveNote(rhs.toDouble());

      if(lhsRes != null) {
        if(rhsRes != null) {
          return lhsRes;
        }
      }

      // return resolveNoteFallback(beats.toDouble());
      return null;
    }

    bool divSet = false;
    bool beatSet = false;
    bool divBeatWritten = false;

    beginTag("score-partwise",{});
      beginTag("identification",{});
        beginTag("encoding",{});
          valueTag("software", "muon", {});
        endTag("encoding");
      endTag("identification");
      beginTag("part-list",{});
        beginTag("score-part",{"id": "P1"});
          valueTag("part-name", "Part1", {});
        endTag("score-part");
      endTag("part-list");
      beginTag("part",{"id": "P1"});
        beginTag("measure",{"number": "1"});
          for(final event in musicXML.events) {
            if(event is MusicXMLEventDivision) {
              lastDivision = event.divisions;
              regenerateDivisionMapping();
              if(!divSet) {
                divSet = true;
              }
              else {
                // division has .. changed?

                beginTag("attributes",{});
                  valueTag("divisions", lastDivision.toString(), {}); newline();
                endTag("attributes");
              }
            }
            else if(event is MusicXMLEventTimeSignature) {
              lastBeats = event.beats;
              lastBeatType = event.beatType;
              regenerateDivisionMapping();
              if(!beatSet) {
                beatSet = true;
              }
              else {
                // time signature has changed

                beginTag("attributes",{});
                  beginTag("time",{});
                    valueTag("beats", lastBeats.toString(), {}); newline();
                    valueTag("beat-type", lastBeatType.toString(), {});
                  endTag("time");
                endTag("attributes");
              }
            }
            else if(event is MusicXMLEventTempo) {
              beginTag("direction",{});
                valueTagSelfClosing("sound", {"tempo": event.tempo.toString()});
              endTag("direction");
            }
            else if(event is MusicXMLEventRest) {
              var beatsRemaining = max(0,curMeasureNum * lastBeats - curBeat);
              var duration = event.duration;

              var tieMode = false;

              while(duration > 0) {
                if(beatsRemaining <= 0) {
                  endTag("measure");
                  curMeasureNum++;
                  beginTag("measure",{"number": curMeasureNum.toString()});
                  beatsRemaining = lastBeats.toDouble();
                }

                var writeDur = min(beatsRemaining * lastDivision,duration);
                var noteResolution = resolveNote(writeDur);

                if(noteResolution == null) {
                  // ruh roh
                  var backupResolution = resolveNoteFallback(writeDur);

                  if(backupResolution != null) {
                    noteResolution = backupResolution;
                    writeDur = backupResolution.beats;
                  }
                }

                curBeat += writeDur / lastDivision;
                beatsRemaining = max(0,curMeasureNum * lastBeats - curBeat);
                duration = duration - writeDur;
                
                beginTag("note",{});
                  valueTagSelfClosing("rest", {}); newline();
                  valueTag("duration", writeDur.toStringAsFixed(0), {}); newline();
                  if(noteResolution != null) {
                    valueTag("type", noteResolution.noteType, {}); newline();
                    for(int dotN=0;dotN < noteResolution.dots;dotN++) {
                      valueTagSelfClosing("dot", {}); newline();
                    }
                  }
                  else {
                    // we gave up
                    // valueTag("type", "?", {}); newline();
                  }
                  valueTag("voice", event.voice.toString(), {}); newline();
                  if(!tieMode) {
                    if(duration > 0) {
                      // still more left to write.
                      // begin tie.

                      valueTagSelfClosing("tie", {"type": "start"}); newline();
                      beginTag("notations",{});
                      valueTagSelfClosing("tied", {"type": "start"});
                      endTag("notations");

                      tieMode = true;
                    }
                  }
                  else {
                    valueTagSelfClosing("tie", {"type": "stop"}); newline();
                    beginTag("notations",{});
                    valueTagSelfClosing("tied", {"type": "stop"});
                    endTag("notations");
                    if(duration > 0) {
                      // still more left to write.
                      // continue tie.

                      valueTagSelfClosing("tie", {"type": "start"}); newline();
                      beginTag("notations",{});
                      valueTagSelfClosing("tied", {"type": "start"});
                      endTag("notations");
                    }
                  }
                endTag("note");
              }
            }
            else if(event is MusicXMLEventNote) {
              var beatsRemaining = max(0,curMeasureNum * lastBeats - curBeat);
              var duration = event.duration;

              var tieMode = false;

              while(duration > 0) {
                if(beatsRemaining <= 0) {
                  endTag("measure");
                  curMeasureNum++;
                  beginTag("measure",{"number": curMeasureNum.toString()});
                  beatsRemaining = lastBeats.toDouble();
                }

                var writeDur = min(beatsRemaining * lastDivision,duration);
                var noteResolution = resolveNote(writeDur);

                if(noteResolution == null) {
                  // ruh roh
                  var backupResolution = resolveNoteFallbackDiscrete(writeDur.toInt());

                  if(backupResolution != null) {
                    noteResolution = backupResolution;
                    writeDur = backupResolution.beats;
                  }
                }

                curBeat += writeDur / lastDivision;
                beatsRemaining = max(0,curMeasureNum * lastBeats - curBeat);
                duration = duration - writeDur;
                
                beginTag("note",{});
                  valueTag("duration", writeDur.toStringAsFixed(0), {}); newline();
                  if(noteResolution != null) {
                    valueTag("type", noteResolution.noteType, {}); newline();
                    for(int dotN=0;dotN < noteResolution.dots;dotN++) {
                      valueTagSelfClosing("dot", {}); newline();
                    }
                  }
                  else {
                    // we gave up
                    // valueTag("type", "?", {}); newline();
                  }
                  valueTag("voice", event.voice.toString(), {}); newline();
                  if((event.lyric.length > 0) && !tieMode) {
                    beginTag("lyric",{});
                      valueTag("text", event.lyric, {}); newline();
                    endTag("lyric");
                  }
                  beginTag("pitch",{});
                    if(event.pitch.note.endsWith("#")) {
                      valueTag("alter", "1", {}); newline();
                      valueTag("step", event.pitch.note[0], {}); newline();
                    }
                    else {
                      valueTag("step", event.pitch.note, {}); newline();
                    }
                    valueTag("octave", event.pitch.octave.toString(), {}); newline();
                  endTag("pitch");
                  if(!tieMode) {
                    if(duration > 0) {
                      // still more left to write.
                      // begin tie.

                      valueTagSelfClosing("tie", {"type": "start"}); newline();
                      beginTag("notations",{});
                      valueTagSelfClosing("tied", {"type": "start"});
                      endTag("notations");

                      tieMode = true;
                    }
                  }
                  else {
                    valueTagSelfClosing("tie", {"type": "stop"}); newline();
                    beginTag("notations",{});
                    valueTagSelfClosing("tied", {"type": "stop"});
                    endTag("notations");
                    if(duration > 0) {
                      // still more left to write.
                      // continue tie.

                      valueTagSelfClosing("tie", {"type": "start"}); newline();
                      beginTag("notations",{});
                      valueTagSelfClosing("tied", {"type": "start"});
                      endTag("notations");
                    }
                  }
                endTag("note");
              }
            }

            if(!divBeatWritten && divSet && beatSet) {
              divBeatWritten = true;

              beginTag("attributes",{});
                valueTag("divisions", lastDivision.toString(), {}); newline();
                beginTag("key",{});
                valueTag("fifths", "5", {});
                endTag("key");
                beginTag("time",{});
                  valueTag("beats", lastBeats.toString(), {}); newline();
                  valueTag("beat-type", lastBeatType.toString(), {});
                endTag("time");
                beginTag("clef",{});
                  valueTag("sign", "G", {}); newline();
                  valueTag("line", "2", {});
                endTag("clef");
              endTag("attributes");
            }
          }
        endTag("measure");
      endTag("part");
    endTag("score-partwise");

    return out;
  }
}
