import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert'; // Necessário para jsonEncode/jsonDecode

import 'package:ouroboros_mobile/models/data_models.dart'; // Para ReminderNote
import 'package:ouroboros_mobile/providers/reminders_provider.dart'; // Para RemindersProvider

class RemindersSection extends StatefulWidget {
  const RemindersSection({Key? key}) : super(key: key);

  @override
  State<RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends State<RemindersSection> {
  late TextEditingController _newNoteController;

  @override
  void initState() {
    super.initState();
    _newNoteController = TextEditingController();
  }

  @override
  void dispose() {
    _newNoteController.dispose();
    super.dispose();
  }

  void _addNote(BuildContext context) {
    final remindersProvider = Provider.of<RemindersProvider>(context, listen: false);
    if (_newNoteController.text.trim().isNotEmpty) {
      remindersProvider.addNote(_newNoteController.text.trim());
      _newNoteController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lembretes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newNoteController,
                    decoration: const InputDecoration(
                      hintText: 'Adicionar novo lembrete...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                    ),
                    onSubmitted: (_) => _addNote(context),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  child: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _addNote(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal, // Definir a cor de fundo como teal
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20), // Rounded corners
                    ),
                    padding: const EdgeInsets.all(12), // Adjust padding for icon only
                    minimumSize: Size.zero, // Remove default minimum size
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<RemindersProvider>(
              builder: (context, remindersProvider, child) {
                if (remindersProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Colors.teal));
                }

                final notes = remindersProvider.notes;

                if (notes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text('Nenhum lembrete adicionado ainda.'),
                    ),
                  );
                }

                return Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return ReminderNoteWidget(
                          note: note,
                          onToggle: () => remindersProvider.toggleNoteCompletion(note.id),
                          onDelete: () => remindersProvider.deleteNote(note.id),
                          onUpdate: (newText) => remindersProvider.updateNote(note.id, newText),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ReminderNoteWidget extends StatefulWidget {
  final ReminderNote note;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Function(String) onUpdate;

  const ReminderNoteWidget({
    Key? key,
    required this.note,
    required this.onToggle,
    required this.onDelete,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<ReminderNoteWidget> createState() => _ReminderNoteWidgetState();
}

class _ReminderNoteWidgetState extends State<ReminderNoteWidget> {
  late TextEditingController _textController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.note.text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSaveEdit() {
    if (_textController.text.trim().isNotEmpty) {
      widget.onUpdate(_textController.text.trim());
    } else {
      // If text is empty, delete the note
      widget.onDelete();
    }
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: widget.note.completed ? Colors.grey.shade300 : Colors.amber.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Checkbox(
              value: widget.note.completed,
              onChanged: (_) => widget.onToggle(),
              activeColor: Colors.amber.shade700,
            ),
            Expanded(
              child: _isEditing
                  ? TextField(
                      controller: _textController,
                      autofocus: true,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: TextStyle(
                        color: widget.note.completed ? Colors.grey.shade500 : Colors.grey.shade800,
                        decoration: widget.note.completed ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                      onSubmitted: (_) => _handleSaveEdit(),
                      onEditingComplete: _handleSaveEdit,
                    )
                  : Text(
                      widget.note.text,
                      style: TextStyle(
                        color: widget.note.completed ? Colors.grey.shade500 : Colors.grey.shade800,
                        decoration: widget.note.completed ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            if (!_isEditing)
              IconButton(
                icon: Icon(Feather.edit, color: Colors.grey.shade500, size: 18),
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
              ),
            IconButton(
              icon: Icon(Feather.trash_2, color: Colors.red.shade400, size: 18),
              onPressed: () => widget.onDelete(),
            ),
          ],
        ),
      ),
    );
  }
}
