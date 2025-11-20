import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/review_provider.dart';
import 'package:ouroboros_mobile/widgets/study_register_modal.dart'; // Import StudyRegisterModal
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:uuid/uuid.dart'; // Import Uuid

// Data classes to hold computed stats for the UI
class _ComputedTopic {
  final Topic originalTopic;
  final int level;
  bool isCompleted;
  int correctQuestions;
  int totalQuestions;
  List<_ComputedTopic> subTopics;

  _ComputedTopic({
    required this.originalTopic,
    required this.level,
    this.isCompleted = false,
    this.correctQuestions = 0,
    this.totalQuestions = 0,
    this.subTopics = const [],
  });

  double get performance => totalQuestions > 0 ? (correctQuestions / totalQuestions) * 100 : 0.0;
  bool get isGroupingTopic => subTopics.isNotEmpty;
}

class _ComputedSubject {
  final Subject originalSubject;
  final List<_ComputedTopic> topics;
  final int totalLeafTopics;
  final int completedLeafTopics;

  _ComputedSubject({
    required this.originalSubject,
    required this.topics,
    required this.totalLeafTopics,
    required this.completedLeafTopics,
  });
}

class _OverallStats {
  final int total;
  final int completed;
  final double progress;
  _OverallStats({required this.total, required this.completed, required this.progress});
}

class _LeafTopicCount {
  final int total;
  final int completed;
  _LeafTopicCount({required this.total, required this.completed});
}

class EditalScreen extends StatelessWidget {
  const EditalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print('EditalScreen: build chamado.');
    return Consumer3<ActivePlanProvider, AllSubjectsProvider, HistoryProvider>(
      builder: (context, activePlanProvider, subjectsProvider, historyProvider, child) {
        print('EditalScreen Consumer: subjectsProvider.isLoading=${subjectsProvider.isLoading}, historyProvider.isLoading=${historyProvider.isLoading}');
        if (subjectsProvider.isLoading || historyProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }

        // Filter subjects and records based on the active plan
        final activePlanId = activePlanProvider.activePlanId;
        print('EditalScreen Consumer: activePlanId=$activePlanId');
        
        final subjectsToDisplay = activePlanId == null
            ? subjectsProvider.subjects
            : subjectsProvider.subjects.where((s) => s.plan_id == activePlanId).toList();

        final recordsToDisplay = activePlanProvider.activePlanId == null
            ? historyProvider.records
            : historyProvider.records.where((r) => r.plan_id == activePlanId).toList();

        print('EditalScreen Consumer: subjectsToDisplay.length=${subjectsToDisplay.length}, recordsToDisplay.length=${recordsToDisplay.length}');

        final computedSubjects = _computeSubjectStats(subjectsToDisplay, recordsToDisplay);
        final overallStats = _computeOverallStats(computedSubjects);

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildOverallProgress(
                context,
                overallStats.completed,
                overallStats.total,
                overallStats.progress,
              ),
              const SizedBox(height: 24),
              ...computedSubjects.map((subject) => _SubjectCard(
                    subject: subject,
                    onToggleCompletion: (subjectId, topicText, planId) {
                      context.read<HistoryProvider>().toggleTopicCompletion(
                            subjectId: subjectId,
                            topicText: topicText,
                            planId: planId,
                          );
                    },
                    onRegisterStudy: (topic) {
                      _showStudyRegisterModalForTopic(context, subject.originalSubject, topic, activePlanProvider);
                    },
                  )).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showStudyRegisterModalForTopic(BuildContext context, Subject subject, _ComputedTopic topic, ActivePlanProvider activePlanProvider) {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final initialRecord = StudyRecord(
      id: Uuid().v4(),
      userId: authProvider.currentUser!.name,
      plan_id: activePlanProvider.activePlan!.id,
      date: DateTime.now().toIso8601String(),
      subject_id: subject.id,
      topic: topic.originalTopic.topic_text,
      study_time: 0,
      category: 'teoria',
      questions: {},
      review_periods: [],
      teoria_finalizada: false,
      count_in_planning: true,
      pages: [],
      videos: [],
    );

    showDialog(
      context: context,
      builder: (ctx) => StudyRegisterModal(
        planId: initialRecord.plan_id,
        initialRecord: initialRecord,
        onSave: (newRecord) {
          historyProvider.addStudyRecord(newRecord);
        },
      ),
    );
  }

  _OverallStats _computeOverallStats(List<_ComputedSubject> subjects) {
    int total = 0;
    int completed = 0;
    for (var subject in subjects) {
      total += subject.totalLeafTopics;
      completed += subject.completedLeafTopics;
    }
    return _OverallStats(
      total: total,
      completed: completed,
      progress: total > 0 ? completed / total : 0.0,
    );
  }

  List<_ComputedSubject> _computeSubjectStats(List<Subject> allSubjects, List<StudyRecord> allRecords) {
    List<_ComputedSubject> computedList = [];

    for (final subject in allSubjects) {
      _ComputedTopic processTopic(Topic topic, int level) {
        final recordsForTopic = allRecords.where((r) => r.subject_id == subject.id && r.topic == topic.topic_text).toList();
        
        int correct = 0;
        int total = 0;
        bool completed = false;

        for (final record in recordsForTopic) {
          correct += record.questions['correct'] ?? 0;
          total += record.questions['total'] ?? 0;
          if (record.teoria_finalizada) {
            completed = true;
          }
        }

        final computed = _ComputedTopic(
          originalTopic: topic,
          level: level,
          correctQuestions: correct,
          totalQuestions: total,
          isCompleted: completed,
          subTopics: (topic.sub_topics ?? []).map((st) => processTopic(st, level + 1)).toList(),
        );

        if (computed.isGroupingTopic) {
          int subCorrect = 0;
          int subTotal = 0;
          bool subCompleted = true;
          for (final sub in computed.subTopics) {
            subCorrect += sub.correctQuestions;
            subTotal += sub.totalQuestions;
            if (!sub.isCompleted) subCompleted = false;
          }
          computed.correctQuestions = subCorrect;
          computed.totalQuestions = subTotal;
          computed.isCompleted = subCompleted;
        }
        
        return computed;
      }

      final topicTree = subject.topics.map((t) => processTopic(t, 0)).toList();
      
      _LeafTopicCount _countLeafTopics(List<_ComputedTopic> topics) {
        int total = 0;
        int completed = 0;
        for (final topic in topics) {
          if (!topic.isGroupingTopic) {
            total++;
            if (topic.isCompleted) completed++;
          } else {
            final subCounts = _countLeafTopics(topic.subTopics);
            total += subCounts.total;
            completed += subCounts.completed;
          }
        }
        return _LeafTopicCount(total: total, completed: completed);
      }

      final leafCounts = _countLeafTopics(topicTree);

      computedList.add(_ComputedSubject(
        originalSubject: subject,
        topics: topicTree,
        totalLeafTopics: leafCounts.total,
        completedLeafTopics: leafCounts.completed,
      ));
    }
    return computedList;
  }

  Widget _buildOverallProgress(BuildContext context, int completed, int total, double progress) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROGRESSO GERAL NO EDITAL',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$completed de $total Tópicos concluídos'),
                Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final _ComputedSubject subject;
  final Function(String, String, String) onToggleCompletion;
  final Function(_ComputedTopic) onRegisterStudy; // New callback

  const _SubjectCard({
    required this.subject,
    required this.onToggleCompletion,
    required this.onRegisterStudy, // New required parameter
  });

  @override
  Widget build(BuildContext context) {
    double subjectCompletion = subject.totalLeafTopics > 0 ? (subject.completedLeafTopics / subject.totalLeafTopics) : 0.0;
    final subjectColor = Color(int.parse(subject.originalSubject.color.replaceFirst('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(width: 8, color: subjectColor),
        title: Text(subject.originalSubject.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: subjectCompletion,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(subjectColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(subjectCompletion * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        children: [_buildTopicsTable(context)],
      ),
    );
  }

  Widget _buildTopicsTable(BuildContext context) {
    return DataTable(
      columnSpacing: 2, // Reduced spacing
      dataRowMinHeight: 40,
      dataRowMaxHeight: double.infinity, // Allow rows to expand vertically
      columns: const [
        DataColumn(label: Text('')), // New column for checkbox
        DataColumn(label: Expanded(child: Text('Tópico', style: TextStyle(fontWeight: FontWeight.bold)))),
        DataColumn(label: Icon(Icons.check_circle, color: Colors.green), tooltip: 'Corretas'),
        DataColumn(label: Icon(Icons.cancel, color: Colors.red), tooltip: 'Erradas'),
        DataColumn(label: Icon(Icons.functions, color: Colors.blue), tooltip: 'Total'),
        DataColumn(label: Text('%', style: TextStyle(fontWeight: FontWeight.bold)), tooltip: 'Performance'),
        DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: _buildTopicRows(context, subject.topics),
    );
  }

  List<DataRow> _buildTopicRows(BuildContext context, List<_ComputedTopic> topics) {
    List<DataRow> rows = [];

    Color getPerformanceColor(double percentage) {
      if (percentage >= 80) return Colors.green;
      if (percentage >= 60) return Colors.amber;
      return Colors.red;
    }

    for (var topic in topics) {
      rows.add(
        DataRow(
          cells: [
            DataCell( // New DataCell for checkbox
              !topic.isGroupingTopic
                  ? Checkbox(
                      value: topic.isCompleted,
                      onChanged: (val) {
                        onToggleCompletion(topic.originalTopic.subject_id!, topic.originalTopic.topic_text, subject.originalSubject.plan_id);
                      },
                      activeColor: Colors.teal, // Adicionado para mudar a cor para teal
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Make checkbox more compact
                    )
                  : const SizedBox.shrink(),
            ),
            DataCell(
              Row(
                children: [
                  SizedBox(width: 20.0 * topic.level),
                  if (topic.isGroupingTopic) const Icon(Icons.folder, color: Colors.teal, size: 18),
                  if (topic.isGroupingTopic) const SizedBox(width: 4),
                  Expanded(child: Text(topic.originalTopic.topic_text, style: TextStyle(fontWeight: topic.isGroupingTopic ? FontWeight.bold : FontWeight.normal))),
                ],
              ),
            ),
            DataCell(Center(child: Text(topic.correctQuestions.toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))),
            DataCell(Center(child: Text((topic.totalQuestions - topic.correctQuestions).toString(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
            DataCell(Center(child: Text(topic.totalQuestions.toString(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))),
            DataCell(
              Row(
                children: [
                  SizedBox(
                    width: 50, // Largura da barra de progresso
                    child: LinearProgressIndicator(
                      value: topic.performance / 100,
                      backgroundColor: Colors.grey[300],
                      color: getPerformanceColor(topic.performance),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${topic.performance.toStringAsFixed(0)}%'),
                ],
              ),
            ),
            DataCell(
              Row(
                children: [
                  if (!topic.isGroupingTopic) IconButton(icon: const Icon(Icons.add_circle), onPressed: () => onRegisterStudy(topic), tooltip: 'Registrar Estudo'),
                ],
              ),
            ),
          ],
        ),
      );
      if (topic.isGroupingTopic) {
        rows.addAll(_buildTopicRows(context, topic.subTopics));
      }
    }
    return rows;
  }
}
