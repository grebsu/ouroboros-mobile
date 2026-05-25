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

  double get performance =>
      totalQuestions > 0 ? (correctQuestions / totalQuestions) * 100 : 0.0;
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
  _OverallStats({
    required this.total,
    required this.completed,
    required this.progress,
  });
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
        print(
          'EditalScreen Consumer: subjectsProvider.isLoading=${subjectsProvider.isLoading}, historyProvider.isLoading=${historyProvider.isLoading}',
        );
        if (subjectsProvider.isLoading || historyProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.teal),
          );
        }

        // Filter subjects and records based on the active plan
        final activePlanId = activePlanProvider.activePlanId;
        print('EditalScreen Consumer: activePlanId=$activePlanId');

        final subjectsToDisplay = activePlanId == null
            ? subjectsProvider.subjects
            : subjectsProvider.subjects
                  .where((s) => s.plan_id == activePlanId)
                  .toList();

        final recordsToDisplay = activePlanProvider.activePlanId == null
            ? historyProvider.records
            : historyProvider.records
                  .where((r) => r.plan_id == activePlanId)
                  .toList();

        print(
          'EditalScreen Consumer: subjectsToDisplay.length=${subjectsToDisplay.length}, recordsToDisplay.length=${recordsToDisplay.length}',
        );

        final computedSubjects = _computeSubjectStats(
          subjectsToDisplay,
          recordsToDisplay,
        );
        final overallStats = _computeOverallStats(computedSubjects);

        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildOverallProgress(
                    context,
                    overallStats.completed,
                    overallStats.total,
                    overallStats.progress,
                  ),
                  const SizedBox(height: 24),
                  ...computedSubjects
                      .map(
                        (subject) => _SubjectCard(
                          subject: subject,
                          onToggleCompletion: (subjectId, topicText, planId) {
                            context.read<HistoryProvider>().toggleTopicCompletion(
                              subjectId: subjectId,
                              topicText: topicText,
                              planId: planId,
                            );
                          },
                          onRegisterStudy: (topic) {
                            _showStudyRegisterModalForTopic(
                              context,
                              subject.originalSubject,
                              topic,
                              activePlanProvider,
                            );
                          },
                        ),
                      )
                      .toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showStudyRegisterModalForTopic(
    BuildContext context,
    Subject subject,
    _ComputedTopic topic,
    ActivePlanProvider activePlanProvider,
  ) {
    final historyProvider = Provider.of<HistoryProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final initialRecord = StudyRecord(
      id: Uuid().v4(),
      userId: authProvider.currentUser!.name,
      plan_id: activePlanProvider.activePlan!.id,
      date: DateTime.now().toIso8601String(),
      subject_id: subject.id,
      topicsProgress: [
        TopicProgress(
          topicId: topic.originalTopic.id.toString(),
          topicText: topic.originalTopic.topic_text,
          isTheoryFinished: topic.isCompleted,
          questions: {
            'correct': topic.correctQuestions,
            'total': topic.totalQuestions,
          },
        ),
      ],
      study_time: 0,
      category: 'teoria',
      review_periods: [],
      count_in_planning: true,
      lastModified: DateTime.now().millisecondsSinceEpoch,
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

  List<_ComputedSubject> _computeSubjectStats(
    List<Subject> allSubjects,
    List<StudyRecord> allRecords,
  ) {
    List<_ComputedSubject> computedList = [];

    for (final subject in allSubjects) {
      _ComputedTopic processTopic(Topic topic, int level) {
        // Coleta todos os TopicProgress para este tópico específico
        final topicProgresses = allRecords
            .where((r) => r.subject_id == subject.id)
            .expand((r) => r.topicsProgress)
            .where((tp) => tp.topicText == topic.topic_text)
            .toList();

        int correct = 0;
        int total = 0;
        bool completed = false;

        for (final tp in topicProgresses) {
          correct += tp.questions['correct'] ?? 0;
          total += tp.questions['total'] ?? 0;
          if (tp.isTheoryFinished) {
            completed = true;
          }
        }

        final computed = _ComputedTopic(
          originalTopic: topic,
          level: level,
          correctQuestions: correct,
          totalQuestions: total,
          isCompleted: completed,
          subTopics: (topic.sub_topics ?? [])
              .map((st) => processTopic(st, level + 1))
              .toList(),
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

      computedList.add(
        _ComputedSubject(
          originalSubject: subject,
          topics: topicTree,
          totalLeafTopics: leafCounts.total,
          completedLeafTopics: leafCounts.completed,
        ),
      );
    }
    return computedList;
  }

  Widget _buildOverallProgress(
    BuildContext context,
    int completed,
    int total,
    double progress,
  ) {
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
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$completed de $total Tópicos concluídos'),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
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
    double subjectCompletion = subject.totalLeafTopics > 0
        ? (subject.completedLeafTopics / subject.totalLeafTopics)
        : 0.0;
    final subjectColor = Color(
      int.parse(subject.originalSubject.color.replaceFirst('#', '0xFF')),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(subject.originalSubject.id), // Persiste o estado de expansão
        initiallyExpanded: false, // Garante que inicia colapsado
        leading: Container(width: 8, color: subjectColor),
        title: Text(
          subject.originalSubject.subject,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
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
              Text(
                '${(subjectCompletion * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        children: _buildTopicTree(context, subject.topics),
      ),
    );
  }

  List<Widget> _buildTopicTree(BuildContext context, List<_ComputedTopic> topics) {
    return topics.map((topic) => _TopicTile(
      topic: topic,
      subjectColor: Color(int.parse(subject.originalSubject.color.replaceFirst('#', '0xFF'))),
      onToggleCompletion: (t) => onToggleCompletion(
        t.originalTopic.subject_id!,
        t.originalTopic.topic_text,
        subject.originalSubject.plan_id,
      ),
      onRegisterStudy: (t) => onRegisterStudy(t),
    )).toList();
  }
}

class _TopicTile extends StatelessWidget {
  final _ComputedTopic topic;
  final Color subjectColor;
  final Function(_ComputedTopic) onToggleCompletion;
  final Function(_ComputedTopic) onRegisterStudy;

  const _TopicTile({
    required this.topic,
    required this.subjectColor,
    required this.onToggleCompletion,
    required this.onRegisterStudy,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasSubtopics = topic.isGroupingTopic;
    final double leftPadding = 16.0 + (topic.level * 16.0);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 700;

    Color getPerformanceColor(double percentage) {
      if (percentage >= 80) return Colors.green;
      if (percentage >= 60) return Colors.amber;
      return Colors.red;
    }

    Widget buildStatsRow() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSmallStat(topic.correctQuestions.toString(), Colors.green, isWideScreen),
          Text(' / ', style: TextStyle(fontSize: isWideScreen ? 12 : 10, color: Colors.grey)),
          _buildSmallStat(topic.totalQuestions.toString(), Colors.blue, isWideScreen),
          SizedBox(width: isWideScreen ? 16 : 8),
          SizedBox(
            width: isWideScreen ? 80 : 40,
            height: isWideScreen ? 6 : 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: topic.performance / 100,
                backgroundColor: Colors.grey[200],
                color: getPerformanceColor(topic.performance),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${topic.performance.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: isWideScreen ? 13 : 10,
              fontWeight: FontWeight.bold,
              color: getPerformanceColor(topic.performance),
            ),
          ),
        ],
      );
    }

    if (hasSubtopics) {
      return ExpansionTile(
        key: PageStorageKey(topic.originalTopic.id), // Persiste o estado do tópico
        initiallyExpanded: false, // Garante que inicia colapsado
        tilePadding: EdgeInsets.only(left: leftPadding, right: 8),
        leading: Icon(Icons.folder_open, size: isWideScreen ? 24 : 20, color: Colors.teal),
        title: Text(
          topic.originalTopic.topic_text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isWideScreen ? 16 : 14,
          ),
        ),
        trailing: buildStatsRow(),
        children: topic.subTopics.map((sub) => _TopicTile(
          topic: sub,
          subjectColor: subjectColor,
          onToggleCompletion: onToggleCompletion,
          onRegisterStudy: onRegisterStudy,
        )).toList(),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: leftPadding,
        right: 8,
        top: isWideScreen ? 8 : 4,
        bottom: isWideScreen ? 8 : 4,
      ),
      child: Row(
        children: [
          SizedBox(
            width: isWideScreen ? 28 : 24,
            height: isWideScreen ? 28 : 24,
            child: Checkbox(
              value: topic.isCompleted,
              onChanged: (_) => onToggleCompletion(topic),
              activeColor: Colors.teal,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              topic.originalTopic.topic_text,
              style: TextStyle(fontSize: isWideScreen ? 15 : 14),
            ),
          ),
          buildStatsRow(),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.add_circle_outline, size: isWideScreen ? 24 : 20, color: Colors.teal),
            onPressed: () => onRegisterStudy(topic),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Registrar Estudo',
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String value, Color color, bool isWide) {
    return Text(
      value,
      style: TextStyle(
        fontSize: isWide ? 13 : 11,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}
