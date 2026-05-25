import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class TopicTreeWidget extends StatelessWidget {
  final List<Topic> topics;
  final int level;
  final ValueChanged<Topic> onToggleTopicSelection;
  final Set<Topic> selectedTopics;

  const TopicTreeWidget({
    super.key,
    required this.topics,
    required this.level,
    required this.onToggleTopicSelection,
    required this.selectedTopics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<Widget> items = [];
    for (var topic in topics) {
      final isGrouping =
          (topic.sub_topics?.isNotEmpty ?? false) ||
          (topic.is_grouping_topic ?? false);

      if (isGrouping) {
        items.add(
          Padding(
            padding: EdgeInsets.only(left: level * 16.0),
            child: ExpansionTile(
              leading: const Icon(Icons.folder, color: Colors.teal),
              title: Text(
                topic.topic_text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              children: [
                TopicTreeWidget(
                  topics: topic.sub_topics ?? [],
                  level: level + 1,
                  onToggleTopicSelection: onToggleTopicSelection,
                  selectedTopics: selectedTopics,
                ),
              ],
              tilePadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              iconColor: Colors.teal,
              collapsedIconColor: Colors.teal,
            ),
          ),
        );
      } else {
        items.add(
          Padding(
            padding: EdgeInsets.only(
              left: level * 16.0 + 4.0,
              right: 4.0,
              top: 2.0,
              bottom: 2.0,
            ),
            child: ListTile(
              leading: Checkbox(
                value: selectedTopics.contains(topic),
                onChanged: (bool? value) {
                  onToggleTopicSelection(topic);
                },
                activeColor: Colors.teal,
              ),
              title: Text(
                topic.topic_text,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () => onToggleTopicSelection(topic),
              selected: selectedTopics.contains(topic),
              selectedTileColor: Colors.teal.withOpacity(0.1),
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }
}

class TopicSelectionSheet extends StatefulWidget {
  final List<Topic> topics;
  final ScrollController scrollController;
  final ValueChanged<List<Topic>> onTopicsSelected;
  final List<String> initialSelectedTopicIds;

  const TopicSelectionSheet({
    super.key,
    required this.topics,
    required this.scrollController,
    required this.onTopicsSelected,
    this.initialSelectedTopicIds = const [],
  });

  @override
  State<TopicSelectionSheet> createState() => _TopicSelectionSheetState();
}

class _TopicSelectionSheetState extends State<TopicSelectionSheet> {
  final Set<Topic> _selectedTopics = {};

  @override
  void initState() {
    super.initState();
    for (String id in widget.initialSelectedTopicIds) {
      final topic = _findTopicById(widget.topics, id);
      if (topic != null) {
        _selectedTopics.add(topic);
      }
    }
  }

  Topic? _findTopicById(List<Topic> topics, String id) {
    for (var topic in topics) {
      if (topic.id.toString() == id) {
        return topic;
      }
      if (topic.sub_topics != null) {
        final found = _findTopicById(topic.sub_topics!, id);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  void _toggleTopicSelection(Topic topic) {
    setState(() {
      if (_selectedTopics.contains(topic)) {
        _selectedTopics.remove(topic);
      } else {
        _selectedTopics.add(topic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Selecione os Tópicos',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onTopicsSelected(_selectedTopics.toList());
            },
            child: Text(
              'Confirmar (${_selectedTopics.length})',
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbColor: MaterialStateProperty.all(Colors.teal),
          radius: const Radius.circular(10),
          thickness: MaterialStateProperty.all(8),
        ),
        child: Scrollbar(
          thumbVisibility: true,
          controller: widget.scrollController,
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(right: 16.0),
            children: [
              TopicTreeWidget(
                topics: widget.topics,
                level: 0,
                onToggleTopicSelection: _toggleTopicSelection,
                selectedTopics: _selectedTopics,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
