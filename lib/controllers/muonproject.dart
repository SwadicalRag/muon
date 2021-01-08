import 'dart:async';
import "dart:io";
import 'dart:math';
import 'package:muon/actions/base.dart';
import 'package:muon/editor.dart';
import "package:synaps_flutter/synaps_flutter.dart";
import "package:dart_midi/dart_midi.dart";
import "package:muon/controllers/muonnote.dart";
import "package:muon/controllers/muonvoice.dart";
import "package:muon/serializable/muon.dart";
import "package:muon/logic/musicxml.dart";
import "package:path/path.dart" as p;

part "muonproject.g.dart";

/// 
/// The main class where the muon project is stored.
/// Has reactive getters/setters with the aid of synaps
/// 
@Controller()
class MuonProjectController with WeakEqualityController {
  /// The directory path of this project
  @Observable()
  String projectDir = "";

  /// The file name of this project (with file extension)
  @Observable()
  String projectFileName = "project.json";

  /// The file name of this project (without file extension)
  String get projectFileNameNoExt => p.basenameWithoutExtension(projectFileName);

  /// Beats per minute
  @Observable()
  double bpm = 120.0;
  
  /// Internal time units per beat (for internal subdivision)
  @Observable()
  int timeUnitsPerBeat = 1;

  /// Beats per measure (numerator)
  @Observable()
  int beatsPerMeasure = 4;

  /// Beat value (denominator), is a power of two
  /// 4 = quarter notes, 8 = eighth notes, etc.
  @Observable()
  int beatValue = 4;

  /// The list of all of the voices in this proejct
  @Observable()
  List<MuonVoiceController> voices = [];

  /// The index of the voice being currently edited/selected
  @Observable()
  int currentVoiceID = 0;

  /// A list of all selected notes in this project (i.e. control A/mouse select)
  @Observable()
  final selectedNotes = Map<MuonNoteController,bool>();

  /// Current time value of where the playhead is in beats
  @Observable()
  double playheadTime = 0.0;

  /// Internally used for Control+C/X/V
  List<MuonNote> copiedNotes = [];

  /// Internally used for Control+C/X/V
  List<MuonVoiceController> copiedNotesVoices = [];

  /// Can be "idle" | "compiling" | "compiling_nsf" | "playing"
  /// Used by the UI to figure out if certain actions are valid
  @Observable()
  String internalStatus = "idle";
  
  /// Current number of visible subdivisions
  int currentSubdivision = 1;

  /// Number of time units per subdivision
  int get timeUnitsPerSubdivision => timeUnitsPerBeat ~/ currentSubdivision;

  /// Actions undertaken in this project
  @Observable()
  List<MuonAction> actions = [];
  
  /// Next action ID
  @Observable()
  int nextActionPos = 0;

  /// Internal timer registered by this class to track the playhead
  /// TODO: this should be removed once FFI is complete
  Timer playbackTimer;

  void dispose() {
    if(playbackTimer != null) {
      playbackTimer.cancel();
      playbackTimer = null;
    }
  }

  // ACTIONS HELPERS

  /// Register an action
  void addAction(MuonAction action) {
    if(actions.length > nextActionPos) {
      actions.removeRange(nextActionPos, actions.length);
    }
    actions.add(action);
    nextActionPos++;
  }

  /// Undo an action
  void undoAction() {
    if(nextActionPos > 0) {
      nextActionPos--;
      actions[nextActionPos].undo();
    }
  }

  /// Redo an action
  void redoAction() {
    if(nextActionPos < actions.length) {
      actions[nextActionPos].perform();
      nextActionPos++;
    }
  }

  /// Undo until an index
  void undoUntilIndex(int index) {
    if(index == -1) {return;}

    index = max(0,index);
    while(nextActionPos > index) {
      undoAction();
    }
  }

  /// Undo until an action
  void undoUntilAction(MuonAction action) {
    undoUntilIndex(actions.indexOf(action));
  }

  /// Undo until an index
  void redoUntilIndex(int index) {
    if(index == -1) {return;}

    while(index >= nextActionPos) {
      redoAction();
    }
  }

  /// Undo until an action
  void redoUntilAction(MuonAction action) {
    redoUntilIndex(actions.indexOf(action));
  }

  // MISCELLANEOUS METHODS

  /// Helper method to concatenate this project's filepath
  /// with a given subtree path
  String getProjectFilePath(String filePath) {
    return p.absolute(projectDir + "/" + filePath);
  }

  /// Helper method to add a voice. Also updates the voice's project reference.
  void addVoice(MuonVoiceController voice) {
    voice.project = this;
    voices.add(voice);
  }

  /// Returns the number of milliseconds until the first phoneme label
  int getLabelMillisecondOffset() {
    return (this.beatsPerMeasure / (this.bpm / 60) * 1000 * (4 / this.beatValue)).round();
  }

  /// updates the contents of this controller with the input controller
  void updateWith(MuonProjectController controller) {
    this.projectFileName = controller.projectFileName;
    this.projectDir = controller.projectDir;
    this.bpm = controller.bpm;
    this.timeUnitsPerBeat = controller.timeUnitsPerBeat;
    this.beatsPerMeasure = controller.beatsPerMeasure;
    this.beatValue = controller.beatValue;
    this.currentSubdivision = controller.currentSubdivision;
    this.actions = controller.actions;
    this.currentVoiceID = controller.currentVoiceID;
    this.internalStatus = "idle";
    this.nextActionPos = controller.nextActionPos;
    this.playheadTime = controller.playheadTime;

    for(final voice in this.voices) {
      if(voice.audioPlayer != null) {
        voice.audioPlayer.dispose();
        voice.audioPlayer = null;
      }
    }
    this.voices.clear();
    for(final voice in controller.voices) {this.addVoice(voice);}

    this.selectedNotes.clear();
    for(final selectedNoteKey in controller.selectedNotes.keys) {
      this.selectedNotes[selectedNoteKey] = controller.selectedNotes[selectedNoteKey];
    }

    this.copiedNotes.clear();
    this.copiedNotesVoices.clear();
  }

  void setupPlaybackTimers() {
    // NB: this is temporary.
    // It is my hope that I can get rid of these ugly async calls
    // once we move to FFI for managing audio
    playbackTimer = Timer.periodic(Duration(milliseconds: 1),(Timer t) async {
      if(this.voices.length > this.currentVoiceID) {
        if(this.internalStatus == "playing") {
          MuonVoiceController longestVoice;

          for(final voice in this.voices) {
            if(voice.audioPlayer != null) {
              if(voice.audioPlayerDuration != null) {
                if(longestVoice != null) {
                  if(voice.audioPlayerDuration > longestVoice.audioPlayerDuration) {
                    longestVoice = voice;
                  }
                }
                else {
                  longestVoice = voice;
                }
              }
            }
          }

          if(longestVoice != null) {
            dynamic posDur = await longestVoice.audioPlayer.getPosition();
            if(posDur is Duration) {
              int curPos = posDur.inMilliseconds;

              if(curPos >= longestVoice.audioPlayerDuration) {
                this.playheadTime = 0;
                this.internalStatus = "idle";
              }
              else {
                int voicePos = curPos - this.getLabelMillisecondOffset();
                this.playheadTime = voicePos / 1000 * (this.bpm / 60);
              }
            }
          }
        }
      }
    });
  }

  // DEFAULT PROJECT

  static MuonProjectController defaultProject() {
    final out = MuonProjectController().ctx();

    out.projectDir = "startup";

    final baseVoice = MuonVoiceController().ctx();
    baseVoice.addNote(
      MuonNoteController().ctx()
        ..startAtTime = 0
        ..duration = 1
        ..note = "C"
        ..octave = 4
        ..lyric = "ら"
    );
    baseVoice.addNote(
      MuonNoteController().ctx()
        ..startAtTime = 1
        ..duration = 1
        ..note = "D"
        ..octave = 4
        ..lyric = "ら"
    );
    baseVoice.addNote(
      MuonNoteController().ctx()
        ..startAtTime = 2
        ..duration = 1
        ..note = "E"
        ..octave = 4
        ..lyric = "ら"
    );
    baseVoice.addNote(
      MuonNoteController().ctx()
        ..startAtTime = 3
        ..duration = 1
        ..note = "F"
        ..octave = 4
        ..lyric = "ら"
    );
    out.addVoice(baseVoice);

    out.setSubdivision(4);

    return out;
  }

  // TIME UNIT MANAGEMENT

  void setSubdivision(int subdivision) {
    factorTimeUnitsPerBeat();
    setTimeUnitsPerBeat(timeUnitsPerBeat * subdivision);
    currentSubdivision = subdivision;
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

    currentSubdivision = 1;
  }

  // IMPORTING/EXPORTING VOICES

  bool importVoiceFromMIDIFile(String midiFilePath,bool importTimeMetadata) {
    var midiFile = File(midiFilePath);

    if(midiFile.existsSync()) {
      var midiParser = MidiParser();
      MidiFile midi = midiParser.parseMidiFromFile(midiFile);

      if(midi.header.format == 0) {
        var voice = MuonVoiceController().ctx()..project = this;

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
                var note = MuonNoteController().ctx();
                note.note = midiNotes[lastNoteOn.noteNumber % 12];
                note.octave = (lastNoteOn.noteNumber / 12).floor() - 1;
                note.startAtTime = lastNoteOnTime.toInt() * timeUnitMulFactor;
                note.duration = (curTime - lastNoteOnTime) * timeUnitMulFactor;
                note.lyric = "";
                voice.addNote(note);

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
                  var note = MuonNoteController().ctx();
                  note.note = midiNotes[lastNoteOn.noteNumber % 12];
                  note.octave = (lastNoteOn.noteNumber / 12).floor() - 1;
                  note.startAtTime = lastNoteOnTime.toInt() * timeUnitMulFactor;
                  note.duration = (curTime - lastNoteOnTime) * timeUnitMulFactor;
                  note.lyric = "";
                  voice.addNote(note);

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

        this.addVoice(voice);

        factorTimeUnitsPerBeat();

        return true;
      }
    }

    return false;
  }

  void importVoiceFromMusicXML(MusicXML musicXML,bool importTimeMetadata) {
    var voice = MuonVoiceController().ctx()..project = this;

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
        var note = MuonNoteController().ctx();
        note.note = event.pitch.note;
        note.octave = event.pitch.octave;
        note.startAtTime = event.time.toInt() * timeUnitMulFactor;
        note.duration = event.duration.toInt() * timeUnitMulFactor;
        note.lyric = event.lyric;
        voice.addNote(note);
      }
    }

    voice.sortNotesByTime();

    this.addVoice(voice);

    factorTimeUnitsPerBeat();
  }

  MusicXML exportVoiceToMusicXML(MuonVoiceController voice) {
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

    musicXML.rest((this.beatsPerMeasure * divEvent.divisions).toDouble(),1);
    var lastNoteEndTime = 0;
    for(int i=0;i < voice.notes.length;i++) {
      final note = voice.notes[i];

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

      lastNoteEndTime = note.startAtTime + note.duration;

      if(i != (voice.notes.length - 1)) {
        final nextNote = voice.notes[i + 1];
        if(nextNote.startAtTime < lastNoteEndTime) {
          // someone has been naughty and stacked notes on top of each other
          // so we will lop the end off the last note

          if(note != null) {
            noteEvent.duration -= lastNoteEndTime - nextNote.startAtTime;
            musicXML.recalculateAbsoluteTime();
          }
        }
      }

      musicXML.addEvent(noteEvent);
    }
    musicXML.rest((this.beatsPerMeasure * divEvent.divisions).toDouble(),1);

    return musicXML;
  }

  // SAVING/LOADING

  void save() {
    final serializable = this.toSerializable();
    serializable.save();
  }

  static MuonProjectController loadFromDir(String projectDir,String projectFileName) {
    final serializable = MuonProject.loadFromDir(projectDir,projectFileName);
    return MuonProjectController.fromSerializable(serializable);
  }

  static MuonProjectController loadFromFile(String projectFile) {
    final serializable = MuonProject.loadFromFile(projectFile);
    return MuonProjectController.fromSerializable(serializable);
  }

  // SERIALIZATION INTERFACE

  MuonProject toSerializable() {
    final out = MuonProject();
    out.projectDir = this.projectDir;
    out.projectFileName = this.projectFileName;
    out.bpm = this.bpm;
    out.timeUnitsPerBeat = this.timeUnitsPerBeat;
    out.beatsPerMeasure = this.beatsPerMeasure;
    out.beatValue = this.beatValue;
    for(final voice in voices) {
      out.voices.add(voice.toSerializable(out));
    }
    return out;
  }

  static MuonProjectController fromSerializable(MuonProject obj) {
    final out = MuonProjectController().ctx();
    out.projectDir = obj.projectDir;
    out.projectFileName = obj.projectFileName;
    out.bpm = obj.bpm;
    out.timeUnitsPerBeat = obj.timeUnitsPerBeat;
    out.beatsPerMeasure = obj.beatsPerMeasure;
    out.beatValue = obj.beatValue;
    for(final voice in obj.voices) {
      out.addVoice(MuonVoiceController.fromSerializable(voice,out));
    }
    return out;
  }
}
