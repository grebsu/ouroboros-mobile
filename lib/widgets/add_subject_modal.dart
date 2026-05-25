import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/services/database_service.dart';

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
  late String _selectedColor;
  List<MasterSubject> _masterSubjects = [];
  MasterSubject? _selectedMasterSubject;
  bool _isLoadingSubjects = true;
  List<Topic> _currentTopics = [];
  bool _isColorPickerExpanded = false;
  final ScrollController _scrollController = ScrollController();

  // Full color palette from the desktop version
  final List<String> _colors = [
    '#EF4444',
    '#F87171',
    '#DC2626',
    '#B91C1C',
    '#F97316',
    '#FB923C',
    '#EA580C',
    '#C2410C',
    '#F59E0B',
    '#FBBF24',
    '#D97706',
    '#B45309',
    '#84CC16',
    '#A3E635',
    '#65A30D',
    '#4D7C0F',
    '#22C55E',
    '#4ADE80',
    '#16A34A',
    '#15803D',
    '#FFD700',
    '#DAA520',
    '#B8860B',
    '#A52A2A',
    '#0EA5E9',
    '#38BDF8',
    '#0284C7',
    '#0369A1',
    '#3B82F6',
    '#60A5FA',
    '#2563EB',
    '#1D4ED8',
    '#8B5CF6',
    '#A78BFA',
    '#7C3AED',
    '#6D28D9',
    '#A855F7',
    '#C084FC',
    '#9333EA',
    '#7E22CE',
    '#EC4899',
    '#F472B6',
    '#DB2777',
    '#BE185D',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialSubjectData?.subject ?? '',
    );
    _currentTopics = widget.initialSubjectData?.topics ?? [];
    _selectedColor = widget.initialSubjectData?.color ?? _colors[0];
    if (widget.initialSubjectData == null) {
      _fetchMasterSubjects();
    } else {
      _isLoadingSubjects = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMasterSubjects() async {
    setState(() => _isLoadingSubjects = true);
    try {
      final subjects = await DatabaseService.instance.readAllMasterSubjects();
      setState(() {
        _masterSubjects = subjects;
        _isLoadingSubjects = false;
      });
    } catch (e) {
      // Handle error
      setState(() => _isLoadingSubjects = false);
    }
  }

  Future<void> _onMasterSubjectSelected(MasterSubject? selectedSubject) async {
    if (selectedSubject == null) {
      setState(() {
        _selectedMasterSubject = null;
        _nameController.text = '';
        _currentTopics = [];
      });
      return;
    }
    setState(() {
      _isLoadingSubjects = true;
      _selectedMasterSubject = selectedSubject;
      _nameController.text = selectedSubject.name;
    });
    try {
      final topics = await DatabaseService.instance.readMasterTopicsForSubject(
        selectedSubject.id,
      );
      setState(() {
        _currentTopics = topics;
        _isLoadingSubjects = false;
      });
    } catch (e) {
      setState(() => _isLoadingSubjects = false);
    }
  }

  void _handleUpdateTopic(Topic topic, String newName) {
    setState(() {
      _recursiveTopicUpdate(
        _currentTopics,
        topic,
        (t) => t.copyWith(
          topic_text: newName,
          isEditing: false,
          lastModified: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
  }

  void _handleToggleEdit(Topic topic) {
    setState(() {
      _recursiveTopicUpdate(
        _currentTopics,
        topic,
        (t) => t.copyWith(isEditing: !t.isEditing),
      );
    });
  }

  void _handleToggleExpanded(Topic topic) {
    setState(() {
      _recursiveTopicUpdate(
        _currentTopics,
        topic,
        (t) => t.copyWith(isExpanded: !t.isExpanded),
      );
    });
  }

  void _handleDeleteTopic(Topic topic) {
    setState(() {
      _recursiveTopicDelete(_currentTopics, topic);
    });
  }

  void _handleAddTopic({Topic? parent}) {
    final newTopic = Topic(
      topic_text: '',
      isEditing: true,
      isExpanded: true, // Expande ao adicionar
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() {
      if (parent == null) {
        _currentTopics.add(newTopic);
      } else {
        _recursiveTopicUpdate(_currentTopics, parent, (t) {
          t.sub_topics ??= [];
          t.sub_topics!.add(newTopic);
          t.isExpanded = true; // Garante que o pai esteja aberto para ver o novo item
          return t;
        });
      }
    });
  }

  void _handleToggleSelected(Topic topic, bool isSelected) {
    setState(() {
      _recursiveTopicUpdate(_currentTopics, topic, (t) {
        t.isSelected = isSelected;
        if (t.sub_topics != null) {
          _setSubTopicsSelected(t.sub_topics!, isSelected);
        }
        return t;
      });
    });
  }

  void _setSubTopicsSelected(List<Topic> topics, bool isSelected) {
    for (var topic in topics) {
      topic.isSelected = isSelected;
      if (topic.sub_topics != null) {
        _setSubTopicsSelected(topic.sub_topics!, isSelected);
      }
    }
  }

  bool _recursiveTopicUpdate(
    List<Topic> topics,
    Topic target,
    Topic Function(Topic) update,
  ) {
    for (int i = 0; i < topics.length; i++) {
      if (topics[i] == target) {
        topics[i] = update(topics[i]);
        return true;
      }
      if (topics[i].sub_topics != null &&
          _recursiveTopicUpdate(topics[i].sub_topics!, target, update)) {
        return true;
      }
    }
    return false;
  }

  bool _recursiveTopicDelete(List<Topic> topics, Topic target) {
    for (int i = 0; i < topics.length; i++) {
      if (topics[i] == target) {
        topics.removeAt(i);
        return true;
      }
      if (topics[i].sub_topics != null &&
          _recursiveTopicDelete(topics[i].sub_topics!, target)) {
        return true;
      }
    }
    return false;
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Filtra apenas os tópicos selecionados
      final selectedTopics = _filterSelectedTopics(_currentTopics);
      widget.onSave(_nameController.text, selectedTopics, _selectedColor);
      Navigator.of(context).pop();
    }
  }

  List<Topic> _filterSelectedTopics(List<Topic> topics) {
    List<Topic> filtered = [];
    for (var topic in topics) {
      if (topic.isSelected) {
        List<Topic> filteredSubTopics = [];
        if (topic.sub_topics != null) {
          filteredSubTopics = _filterSelectedTopics(topic.sub_topics!);
        }
        // Adiciona o tópico pai mesmo que não tenha sub-tópicos selecionados,
        // mas seus sub-tópicos serão a lista filtrada.
        filtered.add(topic.copyWith(sub_topics: filteredSubTopics));
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: AppBar(
        title: Text(
          widget.initialSubjectData == null
              ? 'Nova Disciplina'
              : 'Editar Disciplina',
        ),
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.initialSubjectData == null) ...[
                    DropdownButtonFormField<MasterSubject?>(
                      value: _selectedMasterSubject,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Carregar do Catálogo',
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),
                      hint: const Text('Selecione uma matéria...'),
                      onChanged: _isLoadingSubjects
                          ? null
                          : _onMasterSubjectSelected,
                      items: [
                        const DropdownMenuItem<MasterSubject?>(
                          value: null,
                          child: Text('Selecione uma matéria'),
                        ),
                        ..._masterSubjects.map((subject) {
                          return DropdownMenuItem<MasterSubject?>(
                            value: subject,
                            child: Text(subject.name),
                          );
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nameController,
                    readOnly:
                        _selectedMasterSubject != null &&
                        widget.initialSubjectData == null,
                    decoration: InputDecoration(
                      labelText: 'Nome da Disciplina',
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2.0,
                        ),
                      ),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Campo obrigatório'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecione uma Cor',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isColorPickerExpanded = !_isColorPickerExpanded;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Color(
                                        int.parse(
                                          _selectedColor.replaceFirst(
                                            '#',
                                            '0xFF',
                                          ),
                                        ),
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedColor,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                _isColorPickerExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isColorPickerExpanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _colors.map((color) {
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedColor = color;
                                  _isColorPickerExpanded =
                                      false; // Collapse on selection
                                }),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(
                                        color.replaceFirst('#', '0xFF'),
                                      ),
                                    ),
                                    shape: BoxShape.circle,
                                    border: _selectedColor == color
                                        ? Border.all(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            width: 3,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tópicos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.teal),
                        onPressed: () => _handleAddTopic(),
                        tooltip: 'Adicionar Tópico na Raiz',
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildTopicTree(_currentTopics, 0),
                ],
              ),
            ),
          ),
          if (_isLoadingSubjects)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicTree(List<Topic> topics, int level) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: topics.map((topic) {
        final hasChildren = topic.sub_topics != null && topic.sub_topics!.isNotEmpty;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.only(left: level * 16.0),
              child: _TopicCard(
                topic: topic,
                onToggleSelected: (isSelected) =>
                    _handleToggleSelected(topic, isSelected),
                onUpdate: (newName) => _handleUpdateTopic(topic, newName),
                onDelete: () => _handleDeleteTopic(topic),
                onToggleEdit: () => _handleToggleEdit(topic),
                onAddChild: () => _handleAddTopic(parent: topic),
                onToggleExpanded: () => _handleToggleExpanded(topic),
              ),
            ),
            if (hasChildren && topic.isExpanded)
              _buildTopicTree(topic.sub_topics!, level + 1),
          ],
        );
      }).toList(),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final Topic topic;
  final ValueChanged<bool> onToggleSelected;
  final ValueChanged<String> onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onToggleEdit;
  final VoidCallback onAddChild;
  final VoidCallback onToggleExpanded;

  const _TopicCard({
    required this.topic,
    required this.onToggleSelected,
    required this.onUpdate,
    required this.onDelete,
    required this.onToggleEdit,
    required this.onAddChild,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasChildren = topic.sub_topics != null && topic.sub_topics!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
        color: topic.isExpanded && hasChildren ? Colors.teal.withOpacity(0.03) : null,
      ),
      child: Row(
        children: [
          // Ícone de expansão
          if (hasChildren)
            IconButton(
              icon: Icon(
                topic.isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 20,
              ),
              onPressed: onToggleExpanded,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 24), // Espaço vazio para alinhar com os pais

          Checkbox(
            value: topic.isSelected,
            onChanged: (value) => onToggleSelected(value ?? false),
            visualDensity: VisualDensity.compact,
            activeColor: Colors.teal,
          ),
          Expanded(
            child: GestureDetector(
              onTap: hasChildren ? onToggleExpanded : null,
              child: topic.isEditing
                  ? IntrinsicWidth(
                      child: TextFormField(
                        initialValue: topic.topic_text,
                        autofocus: true,
                        style: textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onFieldSubmitted: (newName) {
                          if (newName.isNotEmpty) {
                            onUpdate(newName);
                          } else {
                            onDelete(); // Deleta se o nome for vazio
                          }
                        },
                        onTapOutside: (_) {
                          if (topic.topic_text.isNotEmpty) {
                            onToggleEdit(); // Salva ao clicar fora
                          } else {
                            onDelete();
                          }
                        },
                      ),
                    )
                  : Text(
                      topic.topic_text,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: hasChildren ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 20, color: Colors.green),
            onPressed: onAddChild,
            tooltip: 'Adicionar Subtópico',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(
              topic.isEditing ? Icons.done : Icons.edit,
              size: 20,
              color: Colors.blueAccent,
            ),
            onPressed: onToggleEdit,
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: Colors.redAccent,
            ),
            onPressed: onDelete,
            tooltip: 'Deletar',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
