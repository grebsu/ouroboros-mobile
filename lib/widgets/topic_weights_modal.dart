import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';

class TopicWeightsModal extends StatefulWidget {
  final Subject subject;

  const TopicWeightsModal({Key? key, required this.subject}) : super(key: key);

  @override
  _TopicWeightsModalState createState() => _TopicWeightsModalState();
}

class _TopicWeightsModalState extends State<TopicWeightsModal> {
  late Map<int, int> _topicWeights;

  @override
  void initState() {
    super.initState();
    _topicWeights = {};
    _extractWeights(widget.subject.topics);
  }

  void _extractWeights(List<Topic> topics) {
    for (var topic in topics) {
      if (topic.id != null) {
        _topicWeights[topic.id!] = topic.userWeight ?? 3;
      }
      if (topic.sub_topics != null) {
        _extractWeights(topic.sub_topics!);
      }
    }
  }

  void _handleWeightChange(int topicId, int weight) {
    setState(() {
      _topicWeights[topicId] = weight;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ajustar Relevância: ${widget.subject.subject}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: widget.subject.topics.isEmpty
            ? const Center(child: Text('Nenhum tópico encontrado para esta matéria.'))
            : Scrollbar( // Adicionado Scrollbar
                thumbVisibility: true,


                child: ListView(
                  children: widget.subject.topics.map((topic) {
                    return _buildTopicRow(topic, 0);
                  }).toList(),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);
            allSubjectsProvider.updateTopicWeights(_topicWeights);
            Navigator.of(context).pop();
          },
          child: const Text('Salvar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  Widget _buildTopicRow(Topic topic, int level) {
    final isGroupingTopic = topic.is_grouping_topic == true || (topic.sub_topics != null && topic.sub_topics!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: level * 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isGroupingTopic ? '* ${topic.topic_text}' : topic.topic_text,
                style: TextStyle(fontWeight: isGroupingTopic ? FontWeight.bold : FontWeight.normal),
              ),
              if (!isGroupingTopic && topic.id != null)
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: (_topicWeights[topic.id!] ?? 3).toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: (_topicWeights[topic.id!] ?? 3).toString(),
                        onChanged: (value) {
                          _handleWeightChange(topic.id!, value.round());
                        },
                      ),
                    ),
                    Text((_topicWeights[topic.id!] ?? 3).toString()),
                  ],
                ),
            ],
          ),
        ),
        if (topic.sub_topics != null)
          ...topic.sub_topics!.map((subTopic) => _buildTopicRow(subTopic, level + 1)),
      ],
    );
  }
}