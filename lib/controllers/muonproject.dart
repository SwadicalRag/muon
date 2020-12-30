import 'dart:io';
import 'package:get/get.dart';
import 'package:dart_midi/dart_midi.dart';
import 'package:muon/controllers/muonnote.dart';
import 'package:muon/controllers/muonvoice.dart';
import 'package:muon/serializable/muon.dart';
import 'package:muon/logic/musicxml.dart';

class MuonProjectController extends GetxController {
  final projectDir = "".obs;

  // tempo
  final bpm = 120.0.obs;
  final timeUnitsPerBeat = 1.obs;

  // time signature
  final beatsPerMeasure = 4.obs;
  final beatValue = 4.obs;

  final voices = RxList<MuonVoiceController>([]);

  // other
  final selectedNotes = Map<MuonNoteController,bool>().obs;
  
  // subdivision manager
  final currentSubdivision = 1.obs;

  void setSubdivision(int subdivision) {
    factorTimeUnitsPerBeat();
    setTimeUnitsPerBeat(timeUnitsPerBeat.value * subdivision);
    currentSubdivision.value = subdivision;
  }

  void updateWith(MuonProjectController controller) {
    this.projectDir.value = controller.projectDir.value;
    this.bpm.value = controller.bpm.value;
    this.timeUnitsPerBeat.value = controller.timeUnitsPerBeat.value;
    this.beatsPerMeasure.value = controller.beatsPerMeasure.value;
    this.beatValue.value = controller.beatValue.value;
    this.currentSubdivision.value = controller.currentSubdivision.value;

    this.voices.clear();
    for(final voice in controller.voices) {this.voices.add(voice);}

    this.selectedNotes.clear();
    for(final selectedNoteKey in controller.selectedNotes.keys) {
      this.selectedNotes[selectedNoteKey] = controller.selectedNotes[selectedNoteKey];
    }
  }

  static MuonProjectController defaultProject() {
    final out = MuonProjectController();

    print("make");

    out.projectDir.value = "startup";

    final baseVoice = MuonVoiceController();
    baseVoice.notes.add(
      MuonNoteController()
        ..startAtTime.value = 0
        ..duration.value = 1
        ..note.value = "C"
        ..octave.value = 4
        ..lyric.value = "ら"
    );
    baseVoice.notes.add(
      MuonNoteController()
        ..startAtTime.value = 1
        ..duration.value = 1
        ..note.value = "D"
        ..octave.value = 4
        ..lyric.value = "ら"
    );
    baseVoice.notes.add(
      MuonNoteController()
        ..startAtTime.value = 2
        ..duration.value = 1
        ..note.value = "E"
        ..octave.value = 4
        ..lyric.value = "ら"
    );
    baseVoice.notes.add(
      MuonNoteController()
        ..startAtTime.value = 3
        ..duration.value = 1
        ..note.value = "F"
        ..octave.value = 4
        ..lyric.value = "ら"
    );
    out.voices.add(baseVoice);

    out.setSubdivision(4);

    return out;
  }

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

    if(newTimeUnitsPerBeat != timeUnitsPerBeat.value) {
      setTimeUnitsPerBeat(newTimeUnitsPerBeat);
    }
  }
  
  void setTimeUnitsPerBeat(int newTimeUnitsPerBeat) {
    // Potentially lossy

    for(final voice in voices) {
      for(final note in voice.notes) {
        note.startAtTime.value = (note.startAtTime / timeUnitsPerBeat.value * newTimeUnitsPerBeat).round();
        note.duration.value = (note.duration / timeUnitsPerBeat.value * newTimeUnitsPerBeat).round();
      }
    }

    timeUnitsPerBeat.value = newTimeUnitsPerBeat;

    currentSubdivision.value = 1;
  }

  bool importVoiceFromMIDIFile(String midiFilePath,bool importTimeMetadata) {
    var midiFile = File(midiFilePath);

    if(midiFile.existsSync()) {
      var midiParser = MidiParser();
      MidiFile midi = midiParser.parseMidiFromFile(midiFile);

      if(midi.header.format == 0) {
        var voice = MuonVoiceController()..project = this;
        voice.modelName.value = "KIRITAN";

        int timeUnitMulFactor = 1;
        if(this.timeUnitsPerBeat.value != midi.header.ticksPerBeat) {
          timeUnitMulFactor = this.timeUnitsPerBeat.value;
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

                this.bpm.value = 60 / (tempoEvent.microsecondsPerBeat / 1000);
              }
              break;
            }
            case "timeSignature": {
              if(importTimeMetadata) {
                TimeSignatureEvent timeSigEvent = midiEvent;

                this.beatsPerMeasure.value = timeSigEvent.numerator;
                this.beatValue.value = timeSigEvent.denominator;
              }
              break;
            }
            case "noteOn": {
              if(lastNoteOn != null) {
                var note = MuonNoteController();
                note.note.value = midiNotes[lastNoteOn.noteNumber % 12];
                note.octave.value = (lastNoteOn.noteNumber / 12).floor() - 1;
                note.startAtTime.value = lastNoteOnTime.toInt() * timeUnitMulFactor;
                note.duration.value = (curTime - lastNoteOnTime) * timeUnitMulFactor;
                note.lyric.value = "";
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
                  var note = MuonNoteController();
                  note.note.value = midiNotes[lastNoteOn.noteNumber % 12];
                  note.octave.value = (lastNoteOn.noteNumber / 12).floor() - 1;
                  note.startAtTime.value = lastNoteOnTime.toInt() * timeUnitMulFactor;
                  note.duration.value = (curTime - lastNoteOnTime) * timeUnitMulFactor;
                  note.lyric.value = "";
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
    var voice = MuonVoiceController()..project = this;
    voice.modelName.value = "KIRITAN";

    int timeUnitMulFactor = 1;
    for(final event in musicXML.events) {
      if(event is MusicXMLEventTempo) {
        if(importTimeMetadata) {
          this.bpm.value = event.tempo;
        }
      }
      else if(event is MusicXMLEventDivision) {
        if(this.timeUnitsPerBeat.value != event.divisions) {
          timeUnitMulFactor = this.timeUnitsPerBeat.value;
          this.setTimeUnitsPerBeat(this.timeUnitsPerBeat * event.divisions);
        }
      }
      else if(event is MusicXMLEventTimeSignature) {
        if(importTimeMetadata) {
          this.beatsPerMeasure.value = event.beats;
          this.beatValue.value = event.beatType;
        }
      }
      else if(event is MusicXMLEventNote) {
        var note = MuonNoteController();
        note.note.value = event.pitch.note;
        note.octave.value = event.pitch.octave;
        note.startAtTime.value = event.time.toInt() * timeUnitMulFactor;
        note.duration.value = event.duration.toInt() * timeUnitMulFactor;
        note.lyric.value = event.lyric;
        voice.notes.add(note);
      }
    }

    voice.sortNotesByTime();

    this.voices.add(voice);

    factorTimeUnitsPerBeat();
  }

  MusicXML exportVoiceToMusicXML(MuonVoiceController voice) {
    MusicXML musicXML = MusicXML();

    var timeSigEvent = MusicXMLEventTimeSignature(musicXML);
    timeSigEvent.beats = this.beatsPerMeasure.value;
    timeSigEvent.beatType = this.beatValue.value;
    musicXML.addEvent(timeSigEvent);

    var divEvent = MusicXMLEventDivision(musicXML);
    divEvent.divisions = this.timeUnitsPerBeat.value;
    musicXML.addEvent(divEvent);

    var tempoEvent = MusicXMLEventTempo(musicXML);
    tempoEvent.tempo = this.bpm.value;
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
      noteEvent.lyric = note.lyric.value;

      var pitch = MusicXMLPitch();
      pitch.note = note.note.value;
      pitch.octave = note.octave.value;
      noteEvent.pitch = pitch;

      musicXML.addEvent(noteEvent);

      lastNoteEndTime = note.startAtTime.value + note.duration.value;
    }

    return musicXML;
  }

  void save() {
    final serializable = this.toSerializable();
    serializable.save();
  }

  static MuonProjectController loadFromDir(String projectDir) {
    final serializable = MuonProject.loadFromDir(projectDir);
    return MuonProjectController.fromSerializable(serializable);
  }

  MuonProject toSerializable() {
    final out = MuonProject();
    out.projectDir = this.projectDir.value;
    out.bpm = this.bpm.value;
    out.timeUnitsPerBeat = this.timeUnitsPerBeat.value;
    out.beatsPerMeasure = this.beatsPerMeasure.value;
    out.beatValue = this.beatValue.value;
    for(final voice in voices) {
      out.voices.add(voice.toSerializable(out));
    }
    return out;
  }

  static MuonProjectController fromSerializable(MuonProject obj) {
    final out = MuonProjectController();
    out.projectDir.value = obj.projectDir;
    out.bpm.value = obj.bpm;
    out.timeUnitsPerBeat.value = obj.timeUnitsPerBeat;
    out.beatsPerMeasure.value = obj.beatsPerMeasure;
    out.beatValue.value = obj.beatValue;
    for(final voice in obj.voices) {
      out.voices.add(MuonVoiceController.fromSerializable(voice,out));
    }
    return out;
  }
}

void testProject() {
  final originalProject = MuonProjectController();
  originalProject.projectDir.value = "testproject";

  final musicXML = parseFile("E:\\Work\\Neutrino\\NEUTRINO\\score\\musicxml\\9_mochistu.musicxml");

  originalProject.importVoiceFromMusicXML(musicXML, true);
  originalProject.importVoiceFromMIDIFile("E:\\Work\\Neutrino\\NEUTRINO\\score\\musicxml\\9 mochistu.mid", true);

  originalProject.save();

  final loadedProject = MuonProjectController.loadFromDir("testproject");
  final voiceMusicXML = loadedProject.voices[0].exportVoiceToMusicXML();

  final serializedMusicXML = serializeMusicXML(voiceMusicXML);

  final outFile = File("testproject/out.musicxml");
  outFile.writeAsStringSync(serializedMusicXML);

  // print(serializedMusicXML);
}
