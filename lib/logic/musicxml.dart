import 'dart:io';

import 'package:universal_html/html.dart' as html show Node,Element;
import 'package:universal_html/parsing.dart' as html show parseXmlDocument;

class MusicXMLEvent {
  double absoluteTime;
  double absoluteDuration = 0;
}

class MusicXMLEventDivision extends MusicXMLEvent {
  int divisions;
}


class MusicXMLEventTempo extends MusicXMLEvent {
  double tempo;
}

class MusicXMLEventTimeSignature extends MusicXMLEvent {
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

class MusicXMLEventNote extends MusicXMLEvent {
  String lyric;

  MusicXMLPitch pitch;

  int voice;

  bool compoundNote = false;
  bool compoundNoteResolved = false;
}

class MusicXML {
  List<MusicXMLEvent> events = [];
  double absoluteDuration = 0;
  MusicXMLEventTempo lastTempo;
  MusicXMLEventTimeSignature lastTimeSignature;
  MusicXMLEventDivision lastDivision;
  MusicXMLEventNote lastNote;

  void addEvent(MusicXMLEvent event) {
    event.absoluteTime = absoluteDuration;
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
    int beatType = 4;

    if(lastDivision != null) {
      divisions = lastDivision.divisions;
    }

    if(lastTimeSignature != null) {
      beatType = lastTimeSignature.beatType;
    }

    return (noteDuration / divisions) / beatType;
  }

  void rest(double time) {
    absoluteDuration += time;
  }

  void mergeNote(MusicXMLEventNote noteEvent,bool resolve) {
    if(lastNote != null) {
      if(lastNote.compoundNote && !lastNote.compoundNoteResolved) {
        if(lastNote.pitch == noteEvent.pitch) {
          lastNote.absoluteDuration += noteEvent.absoluteDuration;
          absoluteDuration += noteEvent.absoluteDuration;

          lastNote.compoundNoteResolved = resolve;

          return;
        }
      }
    }

    noteEvent.compoundNote = true;
    noteEvent.compoundNoteResolved = resolve;
    addEvent(noteEvent);
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
                var timeSigEvent = MusicXMLEventTimeSignature();
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
                var divEvent = MusicXMLEventDivision();
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
                var tempoEvent = MusicXMLEventTempo();
                tempoEvent.tempo = double.parse(directionData.getAttribute("tempo"));
                out.addEvent(tempoEvent);
              }
            }
          }
          break;
        }
        case "sound": {
          var tempoEvent = MusicXMLEventTempo();
          tempoEvent.tempo = double.parse(el.getAttribute("tempo"));
          out.addEvent(tempoEvent);
          break;
        }
        case "note": {
          var duration = _getChildElement(el,"duration");
          if(duration == null) {continue;}

          var durationVal = double.parse(duration.text);
          var durationAbs = out.noteDurationToAbsoluteTime(durationVal);

          var rest = _getChildElement(el,"rest");
          if(rest != null) {
            out.rest(durationAbs);
          }
          else {
            var noteEvent = MusicXMLEventNote();
            
            noteEvent.absoluteDuration = durationAbs;
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
