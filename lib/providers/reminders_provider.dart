import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class RemindersProvider with ChangeNotifier {
  List<ReminderNote> _notes = [];
  bool _isLoading = false;
  static const String _prefsKey = 'reminderNotes';

  List<ReminderNote> get notes => _notes;
  bool get isLoading => _isLoading;

  RemindersProvider() {
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final notesString = prefs.getString(_prefsKey);

    if (notesString != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(notesString) as List<dynamic>;
        _notes = decodedList
            .map((item) => ReminderNote.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error decoding reminder notes: $e');
        _notes = [];
      }
    } else {
      _notes = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesString = jsonEncode(
      _notes.map((note) => note.toJson()).toList(),
    );
    await prefs.setString(_prefsKey, notesString);
  }

  void addNote(String text) {
    if (text.trim().isEmpty) return;
    final newNote = ReminderNote(
      id: const Uuid().v4(),
      text: text.trim(),
      completed: false,
    );
    _notes.add(newNote);
    _saveNotes();
    notifyListeners();
  }

  void toggleNoteCompletion(String id) {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index != -1) {
      final updatedNote = ReminderNote(
        id: _notes[index].id,
        text: _notes[index].text,
        completed: !_notes[index].completed,
      );
      _notes[index] = updatedNote;
      _saveNotes();
      notifyListeners();
    }
  }

  void deleteNote(String id) {
    _notes.removeWhere((note) => note.id == id);
    _saveNotes();
    notifyListeners();
  }

  void updateNote(String id, String newText) {
    if (newText.trim().isEmpty) {
      deleteNote(id);
      return;
    }
    final index = _notes.indexWhere((note) => note.id == id);
    if (index != -1) {
      final updatedNote = ReminderNote(
        id: _notes[index].id,
        text: newText.trim(),
        completed: _notes[index].completed,
      );
      _notes[index] = updatedNote;
      _saveNotes();
      notifyListeners();
    }
  }
}
