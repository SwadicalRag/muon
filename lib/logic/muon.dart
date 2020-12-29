import 'dart:io';

import 'package:dart_midi/dart_midi.dart';
import 'package:muon/logic/musicxml.dart';

import 'package:juicer/juicer_vm.dart';
import 'package:juicer/metadata.dart';

@juiced
class MuonNote {
  String note;
  int octave;
  String lyric;

  // timing
  int startAtTime;
  int duration;
}

@juiced
class MuonVoice {
  @Property(ignore: true)
  MuonProject project;

  // voice metadata
  String modelName;
  bool randomiseTiming = false;

  // notes
  List<MuonNote> notes = [];

  MusicXML exportVoiceToMusicXML() {
    return project.exportVoiceToMusicXML(this);
  }

  void sortNotesByTime() {
    notes.sort((a,b) => a.startAtTime.compareTo(b.startAtTime));
  }

  // synthesised data
  // TODO: F0, Aperiodicity, Spectral Envelope
}

@juiced
class MuonProject {
  // project metadata
  @Property(ignore: true)
  String projectDir;

  // tempo
  double bpm = 120;
  int timeUnitsPerBeat = 1;

  // time signature
  int beatsPerMeasure = 4;
  int beatValue = 4;

  List<MuonVoice> voices = [];

  void factorTimeUnitsPerBeat() {
    int gcd(int a,int b) => (b == 0) ? a : gcd(b, a % b);
    int gcdArray(List<int> a) {
      if(a.length == 0) {return 1;}
      int result = a[0];
      for(int i = 1; i < a.length; i++){
        result = gcd(result, a[i]);
      }
      return result;
    }

    List<int> allTimeValues = [];
    for(final voice in voices) {
      for(final note in voice.notes) {
        if(note.duration.floor() != 0) {
          allTimeValues.add(note.duration.floor());
        }
        
        if(note.startAtTime.floor() != 0) {
          allTimeValues.add(note.startAtTime.floor());
        }
      }
    }

    var gcdTimeValue = gcdArray(allTimeValues);
    var newTimeUnitsPerBeat = (timeUnitsPerBeat / gcdTimeValue).floor();

    if(newTimeUnitsPerBeat != timeUnitsPerBeat) {
      setTimeUnitsPerBeat(newTimeUnitsPerBeat);
    }
  }

  void setTimeUnitsPerBeat(int newTimeUnitsPerBeat) {
    // Potentially lossy

    for(final voice in voices) {
      for(final note in voice.notes) {
        note.startAtTime = (note.startAtTime / timeUnitsPerBeat * newTimeUnitsPerBeat).round();
        note.duration = (note.duration / timeUnitsPerBeat * newTimeUnitsPerBeat).round();
      }
    }

    timeUnitsPerBeat = newTimeUnitsPerBeat;
  }

  bool importVoiceFromMIDIFile(String midiFilePath,bool importTimeMetadata) {
    var midiFile = File(midiFilePath);

    if(midiFile.existsSync()) {
      var midiParser = MidiParser();
      MidiFile midi = midiParser.parseMidiFromFile(midiFile);

      if(midi.header.format == 0) {
        var voice = MuonVoice()..project = this;
        voice.modelName = "KIRITAN";

        int timeUnitMulFactor = 1;
        if(this.timeUnitsPerBeat != midi.header.ticksPerBeat) {
          timeUnitMulFactor = this.timeUnitsPerBeat;
          this.setTimeUnitsPerBeat(this.timeUnitsPerBeat * midi.header.ticksPerBeat);
        }

        final midiNotes = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];

        var curTime = 0;
        var lastNoteOnTime = 0;
        NoteOnEvent lastNoteOn;
        for(final midiEvent in midi.tracks[0]) {
          curTime += midiEvent.deltaTime;

          switch(midiEvent.type) {
            case "setTempo": {
              if(importTimeMetadata) {
                SetTempoEvent tempoEvent = midiEvent;

                this.bpm = 60 / (tempoEvent.microsecondsPerBeat / 1000);
              }
              break;
            }
            case "timeSignature": {
              if(importTimeMetadata) {
                TimeSignatureEvent timeSigEvent = midiEvent;

                this.beatsPerMeasure = timeSigEvent.numerator;
                this.beatValue = timeSigEvent.denominator;
              }
              break;
            }
            case "noteOn": {
              if(lastNoteOn != null) {
                var note = MuonNote();
                note.note = midiNotes[lastNoteOn.noteNumber % 12];
                note.octave = (lastNoteOn.noteNumber / 12).floor() - 1;
                note.startAtTime = lastNoteOnTime.toInt() * timeUnitMulFactor;
                note.duration = (curTime - lastNoteOnTime) * timeUnitMulFactor;
                note.lyric = "";
                voice.notes.add(note);

                lastNoteOn = null;
              }

              NoteOnEvent noteOnEvent = midiEvent;
              lastNoteOn = noteOnEvent;
              lastNoteOnTime = curTime;

              break;
            }
            case "endOfTrack":
            case "noteOff": {
              if(lastNoteOn != null) {
                if(midiEvent.type == "endOfTrack" || ((midiEvent as NoteOffEvent).noteNumber == lastNoteOn.noteNumber)) {
                  var note = MuonNote();
                  note.note = midiNotes[lastNoteOn.noteNumber % 12];
                  note.octave = (lastNoteOn.noteNumber / 12).floor() - 1;
                  note.startAtTime = lastNoteOnTime.toInt() * timeUnitMulFactor;
                  note.duration = (curTime - lastNoteOnTime) * timeUnitMulFactor;
                  note.lyric = "";
                  voice.notes.add(note);

                  lastNoteOn = null;
                }
              }

              break;
            }
            default: {
              break;
            }
          }
        }

        voice.sortNotesByTime();

        this.voices.add(voice);

        factorTimeUnitsPerBeat();

        return true;
      }
    }

    return false;
  }

  void importVoiceFromMusicXML(MusicXML musicXML,bool importTimeMetadata) {
    var voice = MuonVoice()..project = this;
    voice.modelName = "KIRITAN";

    int timeUnitMulFactor = 1;
    for(final event in musicXML.events) {
      if(event is MusicXMLEventTempo) {
        if(importTimeMetadata) {
          this.bpm = event.tempo;
        }
      }
      else if(event is MusicXMLEventDivision) {
        if(this.timeUnitsPerBeat != event.divisions) {
          timeUnitMulFactor = this.timeUnitsPerBeat;
          this.setTimeUnitsPerBeat(this.timeUnitsPerBeat * event.divisions);
        }
      }
      else if(event is MusicXMLEventTimeSignature) {
        if(importTimeMetadata) {
          this.beatsPerMeasure = event.beats;
          this.beatValue = event.beatType;
        }
      }
      else if(event is MusicXMLEventNote) {
        var note = MuonNote();
        note.note = event.pitch.note;
        note.octave = event.pitch.octave;
        note.startAtTime = event.time.toInt() * timeUnitMulFactor;
        note.duration = event.duration.toInt() * timeUnitMulFactor;
        note.lyric = event.lyric;
        voice.notes.add(note);
      }
    }

    voice.sortNotesByTime();

    this.voices.add(voice);

    factorTimeUnitsPerBeat();
  }

  MusicXML exportVoiceToMusicXML(MuonVoice voice) {
    MusicXML musicXML = MusicXML();

    var timeSigEvent = MusicXMLEventTimeSignature(musicXML);
    timeSigEvent.beats = this.beatsPerMeasure;
    timeSigEvent.beatType = this.beatValue;
    musicXML.addEvent(timeSigEvent);

    var divEvent = MusicXMLEventDivision(musicXML);
    divEvent.divisions = this.timeUnitsPerBeat;
    musicXML.addEvent(divEvent);

    var tempoEvent = MusicXMLEventTempo(musicXML);
    tempoEvent.tempo = this.bpm;
    musicXML.addEvent(tempoEvent);

    voice.sortNotesByTime();

    var lastNoteEndTime = 0;
    for(final note in voice.notes) {
      if(note.startAtTime > lastNoteEndTime) {
        musicXML.rest((note.startAtTime - lastNoteEndTime).toDouble(),1);
      }

      var noteEvent = MusicXMLEventNote(musicXML);

      noteEvent.voice = 1;
      noteEvent.duration = note.duration.toDouble();
      noteEvent.lyric = note.lyric;

      var pitch = MusicXMLPitch();
      pitch.note = note.note;
      pitch.octave = note.octave;
      noteEvent.pitch = pitch;

      musicXML.addEvent(noteEvent);

      lastNoteEndTime = note.startAtTime + note.duration;
    }

    return musicXML;
  }

  static MuonProject loadFromDir(String projectDir) {
    if(Directory(projectDir).existsSync()) {
      final file = new File(projectDir + "/project.json");

      if(file.existsSync()) {
        Juicer juicer = juiceClasses([MuonProject,MuonVoice,MuonNote]);

        var fileContents = file.readAsStringSync();

        MuonProject project = juicer.decodeJson(fileContents,(_) => MuonProject());

        for(final voice in project.voices) {
          voice.project = project;
        }

        project.projectDir = projectDir;

        return project;
      }
    }

    return null;
  }

  void save() {
    if(!Directory(projectDir).existsSync()) {
      Directory(projectDir).createSync();
    }

    Juicer juicer = juiceClasses([MuonProject,MuonVoice,MuonNote]);

    String fileContents = juicer.encodeJson(this);

    final file = new File(projectDir + "/project.json");
    file.writeAsStringSync(fileContents);
  }
}

void main() {
  final originalProject = MuonProject();
  originalProject.projectDir = "testproject";

  final musicXML = parseFile("E:\\Work\\Neutrino\\NEUTRINO\\score\\musicxml\\9_mochistu.musicxml");

  originalProject.importVoiceFromMusicXML(musicXML, true);
  originalProject.importVoiceFromMIDIFile("E:\\Work\\Neutrino\\NEUTRINO\\score\\musicxml\\9 mochistu.mid", true);

  originalProject.save();

  final loadedProject = MuonProject.loadFromDir("testproject");
  final voiceMusicXML = loadedProject.voices[0].exportVoiceToMusicXML();

  final serializedMusicXML = serializeMusicXML(voiceMusicXML);

  final outFile = File("out.musicxml");
  outFile.writeAsStringSync(serializedMusicXML);

  // print(serializedMusicXML);
}
