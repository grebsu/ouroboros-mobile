import 'package:flutter/material.dart';

class ImportGuideModal extends StatefulWidget {
  final Function(String guideUrl) onImport;

  const ImportGuideModal({
    super.key,
    required this.onImport,
  });

  @override
  State<ImportGuideModal> createState() => _ImportGuideModalState();
}

class _ImportGuideModalState extends State<ImportGuideModal> {
  final _formKey = GlobalKey<FormState>();
  String _guideUrl = '';
  bool _isLoading = false;

  void _handleImport() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });
      try {
        await widget.onImport(_guideUrl);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        // Erro já tratado na função onImport
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar Guia do Tec Concursos'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'URL do Guia',
                  labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.teal),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.teal),
                  ),
                ),
                keyboardType: TextInputType.url,
                onSaved: (value) => _guideUrl = value ?? '',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a URL do guia.';
                  }
                  if (!(Uri.tryParse(value)?.hasAbsolutePath ?? false)) {
                    return 'URL inválida.';
                  }
                  return null;
                },
              ),
            ],
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
          onPressed: _isLoading ? null : _handleImport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                )
              : const Text('Importar'),
        ),
      ],
    );
  }
}
