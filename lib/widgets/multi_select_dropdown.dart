import 'package:flutter/material.dart';

class MultiSelectDropdown extends StatefulWidget {
  final List<String> options;
  final List<String> selectedOptions;
  final Function(List<String>) onSelectionChanged;
  final String placeholder;

  const MultiSelectDropdown({
    super.key,
    required this.options,
    required this.selectedOptions,
    required this.onSelectionChanged,
    required this.placeholder,
  });

  @override
  _MultiSelectDropdownState createState() => _MultiSelectDropdownState();
}

class _MultiSelectDropdownState extends State<MultiSelectDropdown> {
  void _showOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          title: Text(widget.placeholder, style: Theme.of(context).textTheme.titleLarge),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.options.length,
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final isSelected = widget.selectedOptions.contains(option);
                return CheckboxListTile(
                  title: Text(option, style: Theme.of(context).textTheme.bodyMedium),
                  value: isSelected,
                  onChanged: (bool? selected) {
                    setState(() {
                      if (selected == true) {
                        widget.onSelectionChanged([...widget.selectedOptions, option]);
                      } else {
                        widget.onSelectionChanged(widget.selectedOptions.where((o) => o != option).toList());
                      }
                    });
                    Navigator.pop(context); // Fecha o diálogo após a seleção
                    _showOptions(context); // Reabre o diálogo para continuar a seleção
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.teal),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showOptions(context),
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        ),
        child: Wrap(
          spacing: 6.0,
          runSpacing: 6.0,
          children: widget.selectedOptions.isNotEmpty
              ? widget.selectedOptions.map((option) {
                  return Chip(
                    label: Text(option, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    deleteIconColor: Colors.teal,
                    onDeleted: () {
                      widget.onSelectionChanged(widget.selectedOptions.where((o) => o != option).toList());
                    },
                  );
                }).toList()
              : [Text(widget.placeholder)],
        ),
      ),
    );
  }
}
