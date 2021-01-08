import 'dart:math';

import 'package:muon/actions/base.dart';
import 'package:muon/controllers/muonnote.dart';

class RenameNoteAction extends MuonAction {
  String get title {
    if(newLyrics.length > 1) {
      return "Rename ${newLyrics.length} note lyrics";
    }
    else {
      return "Rename note lyric";
    }
  }
  String get subtitle {
    return "to $textInput";
  }

  final Map<MuonNoteController,String> newLyrics;
  final Map<MuonNoteController,String> oldLyrics;
  final String textInput;

  RenameNoteAction(this.newLyrics,this.oldLyrics,this.textInput);

  void perform() {
    for(final note in newLyrics.keys) {
      note.lyric = newLyrics[note];
    }
  }

  void undo() {
    for(final note in oldLyrics.keys) {
      note.lyric = oldLyrics[note];
    }
  }
}
