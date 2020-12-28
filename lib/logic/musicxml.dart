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

MusicXML getDefaultFile() {
  return parseFile("lib/logic/7_kokoro.musicxml");
}

void main() {
  final document = parseFile('7_kokoro.musicxml');

  for(final event in document.events) {
    print(event.absoluteTime.toString());
    if(event is MusicXMLEventNote) {
      print(event.lyric);
      print(event.pitch?.note);
    }
  }
}
