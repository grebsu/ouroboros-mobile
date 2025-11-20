import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class AddSubjectModal extends StatefulWidget {
  final Function(String subjectName, List<Topic> topics, String color) onSave;
  final Subject? initialSubjectData;

  const AddSubjectModal({
    super.key,
    required this.onSave,
    this.initialSubjectData,
  });

  @override
  State<AddSubjectModal> createState() => _AddSubjectModalState();
}

// Helper class for the stack, defined at the file level
class _StackItem {
  final int level;
  final Topic topic;
  _StackItem(this.level, this.topic);
}

class _AddSubjectModalState extends State<AddSubjectModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _topicsController;
  late String _selectedColor;

  // Full color palette from the desktop version
  final List<String> _colors = [
    '#EF4444', '#F87171', '#DC2626', '#B91C1C',
    '#F97316', '#FB923C', '#EA580C', '#C2410C',
    '#F59E0B', '#FBBF24', '#D97706', '#B45309',
    '#84CC16', '#A3E635', '#65A30D', '#4D7C0F',
    '#22C55E', '#4ADE80', '#16A34A', '#15803D',
    '#FFD700', '#DAA520', '#B8860B', '#A52A2A',
    '#0EA5E9', '#38BDF8', '#0284C7', '#0369A1',
    '#3B82F6', '#60A5FA', '#2563EB', '#1D4ED8',
    '#8B5CF6', '#A78BFA', '#7C3AED', '#6D28D9',
    '#A855F7', '#C084FC', '#9333EA', '#7E22CE',
    '#EC4899', '#F472B6', '#DB2777', '#BE185D',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialSubjectData?.subject ?? '');
    _topicsController = TextEditingController(text: _formatTopics(widget.initialSubjectData?.topics ?? []));
    _selectedColor = widget.initialSubjectData?.color ?? _colors[0];
  }

  String _formatTopics(List<Topic> topics, [int level = 0]) {
    return topics.map((topic) {
      final indent = '  ' * level;
      final prefix = topic.is_grouping_topic ?? false ? '* ' : '';
      final subTopicsStr = (topic.sub_topics != null && topic.sub_topics!.isNotEmpty)
          ? '\n${_formatTopics(topic.sub_topics!, level + 1)}'
          : '';
      return '$indent$prefix${topic.topic_text}$subTopicsStr';
    }).join('\n');
  }

  List<Topic> _parseTopics(String content, String subjectId) {
    final lines = content.split('\n');
    final List<Topic> rootTopics = [];
    
    final List<_StackItem> stack = [];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final leadingSpaces = line.length - line.trimLeft().length;
      final level = (leadingSpaces / 2).floor();
      var topicText = line.trim();

      final isGroupingTopic = topicText.startsWith('*');
      if (isGroupingTopic) {
        topicText = topicText.substring(1).trim();
      }

      final newTopic = Topic(
        subject_id: subjectId,
        topic_text: topicText,
        sub_topics: [], // Inicializa vazio, será preenchido se houver sub-tópicos
        is_grouping_topic: isGroupingTopic,
        question_count: null, // Não extraído do input do usuário
      );

      while (stack.isNotEmpty && level <= stack.last.level) {
        stack.removeLast();
      }

      if (stack.isNotEmpty) {
        final parent = stack.last.topic;
        parent.sub_topics ??= [];
        parent.sub_topics!.add(newTopic);
      } else {
        rootTopics.add(newTopic);
      }

      stack.add(_StackItem(level, newTopic));
    }
    return rootTopics;
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final subjectId = widget.initialSubjectData?.id ?? 'placeholder_id';
      final topics = _parseTopics(_topicsController.text, subjectId);
      widget.onSave(
        _nameController.text,
        topics,
        _selectedColor,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: AppBar(
        title: Text(widget.initialSubjectData == null ? 'Nova Disciplina' : 'Editar Disciplina'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: _handleSave,
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome da Disciplina',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              Text('Selecione uma Cor', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _colors.map((color) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: _selectedColor == color
                            ? Border.all(color: Theme.of(context).primaryColor, width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _topicsController,
                decoration: InputDecoration(
                  labelText: 'Tópicos',
                  hintText: 'Ex:\n* Direito Administrativo\n  Origem, Conceito e Fontes\n  * Regime Jurídico\n    Princípios expressos',
                  helperText: "Use 2 espaços para subtópicos e '*' para agrupar.",
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                  ),
                  helperStyle: const TextStyle(color: Colors.grey),
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                maxLines: 8,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
