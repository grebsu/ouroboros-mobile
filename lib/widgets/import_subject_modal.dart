import 'package:flutter/material.dart';

class ImportSubjectModal extends StatefulWidget {
  final Function(String) onImport;

  const ImportSubjectModal({super.key, required this.onImport});

  @override
  State<ImportSubjectModal> createState() => _ImportSubjectModalState();
}

class _ImportSubjectModalState extends State<ImportSubjectModal> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Importar Matéria do TEC Concursos', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal)),
      content: TextField(
        controller: _controller,
        style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: 'URL da Matéria',
          labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
          hintText: 'https://www.tecconcursos.com.br/materias/...',
          hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.teal),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal,
          ),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              widget.onImport(_controller.text);
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Importar'),
        ),
      ],
    );
  }
}
