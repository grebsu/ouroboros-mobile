import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ouroboros_mobile/widgets/multi_select_dropdown.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/filter_provider.dart';

class FilterModal extends StatefulWidget {
  final List<String> availableCategories;
  final List<Subject> availableSubjects;
  final FilterScreen screen;

  const FilterModal({
    super.key,
    required this.availableCategories,
    required this.availableSubjects,
    required this.screen,
  });

  @override
  _FilterModalState createState() => _FilterModalState();
}

class _FilterModalState extends State<FilterModal> {
  late FilterProvider _filterProvider;

  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _minDurationController = TextEditingController();
  final TextEditingController _maxDurationController = TextEditingController();
  final TextEditingController _minPerformanceController = TextEditingController();
  final TextEditingController _maxPerformanceController = TextEditingController();
  List<String> _selectedCategories = [];
  List<String> _selectedSubjects = [];
  List<String> _selectedTopics = [];

  final Map<String, IconData> _categoryIcons = {
    'Jurisprudência': Icons.gavel_rounded,
    'Leitura de lei': Icons.menu_book,
    'Questões': Icons.quiz,
    'Revisão': Icons.refresh,
    'Teoria': Icons.book_rounded, // Changed from Icons.edit_note
  };

  @override
  void initState() {
    super.initState();
    _filterProvider = Provider.of<FilterProvider>(context, listen: false);
    final filters = widget.screen == FilterScreen.history
        ? _filterProvider.historyFilters
        : _filterProvider.statsFilters;

    _startDate = filters['startDate'];
    _endDate = filters['endDate'];
    _minDurationController.text = filters['minDuration']?.toString() ?? '';
    _maxDurationController.text = filters['maxDuration']?.toString() ?? '';
    _minPerformanceController.text = filters['minPerformance']?.toString() ?? '';
    _maxPerformanceController.text = filters['maxPerformance']?.toString() ?? '';
    _selectedCategories = List.from(filters['categories'] ?? []);
    _selectedSubjects = List.from(filters['subjects'] ?? []);
    _selectedTopics = List.from(filters['topics'] ?? []);
  }

  List<String> get _topicsForSelectedSubjects {
    if (_selectedSubjects.isEmpty) {
      return [];
    }
    final topics = widget.availableSubjects
        .where((subject) => _selectedSubjects.contains(subject.subject))
        .expand((subject) => subject.topics.map((topic) => topic.topic_text))
        .toSet()
        .toList();
    topics.sort();
    return topics;
  }

  void _clearFilters() {
    _filterProvider.clearFilters(widget.screen);
    Navigator.of(context).pop();
  }

  void _applyFilters() {
    final filters = {
      'startDate': _startDate,
      'endDate': _endDate,
      'minDuration': int.tryParse(_minDurationController.text),
      'maxDuration': int.tryParse(_maxDurationController.text),
      'minPerformance': double.tryParse(_minPerformanceController.text),
      'maxPerformance': double.tryParse(_maxPerformanceController.text),
      'categories': _selectedCategories,
      'subjects': _selectedSubjects,
      'topics': _selectedTopics,
    };
    _filterProvider.setFilters(widget.screen, filters);
    Navigator.of(context).pop();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.teal,
              brightness: Theme.of(context).brightness,
            ).copyWith(
              onPrimary: Colors.white,
              onSurface: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) {
        return Material(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).dialogBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filtros Avançados', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.close, color: Theme.of(context).iconTheme.color),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildSectionTitle('Período'),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Data de Início',
                                labelStyle: TextStyle(color: Colors.teal),
                              ),
                              child: Text(_startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Selecione'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Data de Fim',
                                labelStyle: TextStyle(color: Colors.teal),
                              ),
                              child: Text(_endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'Selecione'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Duração (minutos)'),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_minDurationController, 'Mínimo')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_maxDurationController, 'Máximo')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Desempenho (%)'),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_minPerformanceController, 'Mínimo')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_maxPerformanceController, 'Máximo')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Categoria'),
                    Center(
                      child: Wrap(
                        spacing: 12.0, // Increased horizontal spacing
                        runSpacing: 12.0, // Added vertical spacing
                        children: widget.availableCategories.map((category) {
                                                  return FilterChip(
                                                    avatar: Icon(_categoryIcons[category] ?? Icons.category, color: Colors.teal),
                                                    label: Text(
                                                      category,
                                                      style: TextStyle(
                                                        fontSize: _selectedCategories.contains(category) ? 20 : 18, // Larger when selected
                                                        color: Theme.of(context).textTheme.bodyMedium?.color,
                                                      ),
                                                    ),
                                                    selected: _selectedCategories.contains(category),
                                                    backgroundColor: Colors.teal.withOpacity(0.1),
                                                    selectedColor: Colors.teal.withOpacity(0.2),
                                                    showCheckmark: false, // Remove checkmark
                                                    padding: _selectedCategories.contains(category)
                                                        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12) // Larger padding when selected
                                                        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                    onSelected: (selected) {
                                                      setState(() {
                                                        if (selected) {
                                                          _selectedCategories.add(category);
                                                        } else {
                                                          _selectedCategories.remove(category);
                                                        }
                                                      });
                                                    },
                                                  );                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Disciplina e Tópico'),
                    MultiSelectDropdown(
                      options: widget.availableSubjects.map((s) => s.subject).toList(),
                      selectedOptions: _selectedSubjects,
                      onSelectionChanged: (selected) {
                        setState(() {
                          _selectedSubjects = selected;
                          _selectedTopics.clear(); // Limpa os tópicos ao mudar a disciplina
                        });
                      },
                      placeholder: 'Selecione as Disciplinas',
                    ),
                    const SizedBox(height: 16),
                    MultiSelectDropdown(
                      options: _topicsForSelectedSubjects,
                      selectedOptions: _selectedTopics,
                      onSelectionChanged: (selected) {
                        setState(() {
                          _selectedTopics = selected;
                        });
                      },
                      placeholder: 'Selecione os Tópicos',
                    ),
                  ],
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _clearFilters,
                      style: TextButton.styleFrom(foregroundColor: Colors.teal),
                      child: const Text('Limpar'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.teal),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.teal, width: 2.0),
        ),
      ),
    );
  }
}