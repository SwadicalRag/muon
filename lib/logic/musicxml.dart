import 'dart:io';
import 'dart:math';

import 'package:universal_html/html.dart' as html show Node,Element;
import 'package:universal_html/parsing.dart' as html show parseXmlDocument;

class MusicXMLEvent {
  double absoluteTime;
  double time;
  double duration = 0;
  
  MusicXMLEventTempo lastTempo;
  MusicXMLEventTimeSignature lastTimeSignature;
  MusicXMLEventDivision lastDivision;

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
  int divisions;
}


class MusicXMLEventTempo extends MusicXMLEvent {
  MusicXMLEventTempo(MusicXML parent) : super(parent);
  double tempo;
}

class MusicXMLEventTimeSignature extends MusicXMLEvent {
  MusicXMLEventTimeSignature(MusicXML parent) : super(parent);
  int beats;
  int beatType;
}

class MusicXMLPitch {
  int octave;
  String note;

  @override
  bool operator ==(Object other) {
    if(other is MusicXMLPitch) {
      if(other.octave == octave) {
        if(other.note == note) {
          return true;
        }
      }
    }

    return false;
  }
}

class MusicXMLEventRest extends MusicXMLEvent {
  MusicXMLEventRest(MusicXML parent) : super(parent);
}

class MusicXMLEventNote extends MusicXMLEvent {
  MusicXMLEventNote(MusicXML parent) : super(parent);
  String lyric;

  MusicXMLPitch pitch;

  int voice;

  bool compoundNote = false;
  bool compoundNoteResolved = false;
}

class MusicXML {
  List<MusicXMLEvent> events = [];
  double duration = 0;
  double absoluteDuration = 0;
  MusicXMLEventTempo lastTempo;
  MusicXMLEventTimeSignature lastTimeSignature;
  MusicXMLEventDivision lastDivision;
  MusicXMLEventNote lastNote;

  void addEvent(MusicXMLEvent event) {
    event.time = duration;
    event.absoluteTime = absoluteDuration;

    duration += event.duration;
    absoluteDuration += event.absoluteDuration;

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

  double noteDurationToAbsoluteTime(double noteDuration) {
    int divisions = 1;

    if(lastDivision != null) {
      divisions = lastDivision.divisions;
    }

    return noteDuration / divisions;
  }

  void rest(double duration) {
    addEvent(new MusicXMLEventRest(this)..duration = duration);
  }

  void mergeNote(MusicXMLEventNote noteEvent,bool resolve) {
    if(lastNote != null) {
      if(lastNote.compoundNote && !lastNote.compoundNoteResolved) {
        if(lastNote.pitch == noteEvent.pitch) {
          absoluteDuration += noteEvent.absoluteDuration;
          
          lastNote.duration += noteEvent.duration;
          duration += noteEvent.duration;

          lastNote.compoundNoteResolved = resolve;

          return;
        }
      }
    }

    noteEvent.compoundNote = true;
    noteEvent.compoundNoteResolved = resolve;
    addEvent(noteEvent);
  }

  void recalculateAbsoluteTime() {
    duration = 0;
    absoluteDuration = 0;

    for(final event in events) {
      event.time = duration;
      event.absoluteTime = absoluteDuration;
      duration += event.duration;
      absoluteDuration += event.absoluteDuration;
    }
  }

  void multiplyDivisions(int divMul) {
    for(final event in events) {
      if(event is MusicXMLEventDivision) {
        event.divisions *= divMul;
      }
      event.duration *= divMul;
    }

    recalculateAbsoluteTime();
  }

  void factorDivisions() {
    // who cares about computational efficiency anyway
    
    int gcd(int a,int b) => (b == 0) ? a : gcd(b, a % b);
    int gcdArray(List<int> a, int offset) {
      if(a.length < (offset + 1)) {
        return gcd(a[offset],gcdArray(a,offset + 1));
      }
      else {
        return a[offset];
      }
    }

    List<int> allDurations = [];
    for(final event in events) {
      if(event.duration.floor() != 0) {
        allDurations.add(event.duration.floor());
      }
    }

    var lcmDuration = gcdArray(allDurations,1);

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

html.Element _getChildElement(html.Element el, String tag) {
  for(final child in el.childNodes) {
    if(child is html.Element) {
      if(child.nodeName == tag) {
        return child;
      }
    }
  }

  return null;
}

String _getChildText(html.Element el, String tag, String defaultVal) {
  var child = _getChildElement(el, tag);
  if (child != null) {
    return child.text;
  }

  return defaultVal;
}

String _getChildAttributeText(html.Element el, String tag, String attribute, String defaultVal) {
  var child = _getChildElement(el, tag);
  if (child != null) {
    if(child.attributes[attribute] != null) {
      return child.attributes[attribute];
    }
  }

  return defaultVal;
}

void _parseMeasure(html.Element measure,MusicXML out) {
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

          var durationVal = double.parse(duration.text);

          var rest = _getChildElement(el,"rest");
          if(rest != null) {
            out.rest(durationVal);
          }
          else {
            var noteEvent = MusicXMLEventNote(out);
            
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

void _parseRootEl(html.Node rootEl,MusicXML out) {
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

MusicXML parseFile(String filePath) {
  final file = new File(filePath);
  final document = html.parseXmlDocument(file.readAsStringSync());

  final out = new MusicXML();

  for(final rootEl in document.childNodes) {
    _parseRootEl(rootEl, out);
  }

  return out;
}

String serializeMusicXML(MusicXML musicXML) {
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

  append('<?xml version="1.0" encoding="utf-8"?>');
  newline();
  append('<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd"[]>');
  newline();

  int curMeasureNum = 1;
  int lastDivision = 1;
  int lastBeats = 1;
  int lastBeatType = 1;
  double curBeat = 0;
  Map<double,String> divisionToNoteType = {};
  void regenerateDivisionMapping() {
    divisionToNoteType = {};
    double curDiv = (lastDivision * lastBeatType).toDouble();
    void addDiv(String type) {
      divisionToNoteType[curDiv] = type;
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
              var writeDurInternal = writeDur;
              var isDotted = false;

              if(!divisionToNoteType.containsKey(writeDur.toDouble())) {
                if(writeDur % 2 != 0) {
                  // make dotted note
                  writeDurInternal = writeDurInternal - 1;
                  isDotted = true;
                }
                
                if(divisionToNoteType.containsKey(writeDur.toDouble())) {
                  // problem solved!
                }
                else if((writeDur % 2 == 0) && divisionToNoteType.containsKey((writeDur / 2).toDouble())) {
                  writeDurInternal = writeDurInternal / 2;
                }
                else {
                  // give up
                }
              }

              curBeat += writeDur / lastDivision;
              beatsRemaining = max(0,curMeasureNum * lastBeats - curBeat);
              duration = duration - writeDur;
              
              beginTag("note",{});
                valueTagSelfClosing("rest", {}); newline();
                valueTag("duration", writeDur.toStringAsFixed(0), {}); newline();
                if(divisionToNoteType.containsKey(writeDurInternal.toDouble())) {
                  valueTag("type", divisionToNoteType[writeDurInternal.toDouble()], {}); newline();
                }
                else {
                  // we gave up
                  // valueTag("type", "?", {}); newline();
                }
                if(isDotted) {
                  valueTagSelfClosing("dot", {}); newline();
                }
                valueTag("voice", "1", {}); newline();
                if(!tieMode) {
                  if(duration > 0) {
                    // still more left to write.
                    // begin tie.

                    valueTagSelfClosing("tie", {"type": "start"});
                    beginTag("notations",{});
                    valueTagSelfClosing("tied", {"type": "start"});
                    endTag("notations");

                    tieMode = true;
                  }
                }
                else {
                  if(duration > 0) {
                    // still more left to write.
                    // continue tie.

                    // not sure if this is even correct lmao

                    valueTagSelfClosing("tie", {});
                    beginTag("notations",{});
                    valueTagSelfClosing("tied", {});
                    endTag("notations");
                  }
                  else {
                    valueTagSelfClosing("tie", {"type": "stop"});
                    beginTag("notations",{});
                    valueTagSelfClosing("tied", {"type": "stop"});
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
              var writeDurInternal = writeDur;
              var isDotted = false;

              if(!divisionToNoteType.containsKey(writeDur.toDouble())) {
                if(writeDur % 2 != 0) {
                  // make dotted note
                  writeDurInternal = writeDurInternal - 1;
                  isDotted = true;
                }
                
                if(divisionToNoteType.containsKey(writeDur.toDouble())) {
                  // problem solved!
                }
                else if((writeDur % 2 == 0) && divisionToNoteType.containsKey((writeDur / 2).toDouble())) {
                  writeDurInternal = writeDurInternal / 2;
                }
                else {
                  // give up
                }
              }

              curBeat += writeDur / lastDivision;
              beatsRemaining = max(0,curMeasureNum * lastBeats - curBeat);
              duration = duration - writeDur;
              
              beginTag("note",{});
                valueTag("duration", writeDur.toStringAsFixed(0), {}); newline();
                if(divisionToNoteType.containsKey(writeDurInternal.toDouble())) {
                  valueTag("type", divisionToNoteType[writeDurInternal.toDouble()], {}); newline();
                }
                else {
                  // we gave up
                  // valueTag("type", "?", {}); newline();
                }
                if(isDotted) {
                  valueTagSelfClosing("dot", {}); newline();
                }
                valueTag("voice", "1", {}); newline();
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

                    valueTagSelfClosing("tie", {"type": "start"});
                    beginTag("notations",{});
                    valueTagSelfClosing("tied", {"type": "start"});
                    endTag("notations");

                    tieMode = true;
                  }
                }
                else {
                  if(duration > 0) {
                    // still more left to write.
                    // continue tie.

                    // not sure if this is even correct lmao

                    valueTagSelfClosing("tie", {});
                    beginTag("notations",{});
                    valueTagSelfClosing("tied", {});
                    endTag("notations");
                  }
                  else {
                    valueTagSelfClosing("tie", {"type": "stop"});
                    beginTag("notations",{});
                    valueTagSelfClosing("tied", {"type": "stop"});
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

MusicXML getDefaultFile() {
  return parseFile("E:\\Work\\Neutrino\\NEUTRINO\\score\\musicxml\\9_mochistu.musicxml");
}

void main() {
  final document = parseFile('7_kokoro.musicxml');

  // for(final event in document.events) {
  //   print(event.absoluteTime.toString());
  //   if(event is MusicXMLEventNote) {
  //     print(event.lyric);
  //     print(event.pitch?.note);
  //   }
  // }
}
