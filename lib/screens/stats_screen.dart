import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/providers/filter_provider.dart';
import 'package:ouroboros_mobile/widgets/charts/geral_performance_chart.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/widgets/charts/evolucao_tempo_chart.dart';
import 'package:ouroboros_mobile/widgets/charts/horas_estudo_chart.dart';
import 'package:ouroboros_mobile/widgets/charts/disciplinas_horas_chart.dart';
import 'package:ouroboros_mobile/widgets/charts/category_hours_chart.dart';
import 'package:ouroboros_mobile/widgets/charts/disciplinas_desempenho_chart.dart';
import 'package:ouroboros_mobile/widgets/topic_performance_table.dart';

// --- Helper for time formatting ---
String formatTime(int milliseconds) {
  if (milliseconds.isNaN || milliseconds < 0) {
    return '0h 0m';
  }
  final int totalSeconds = (milliseconds / 1000).floor();
  final int hours = (totalSeconds / 3600).floor();
  final int minutes = ((totalSeconds % 3600) / 60).floor();
  return '${hours}h ${minutes}m';
}

Duration _parseDuration(String timeStr) {
  final parts = timeStr.split(':').map(int.parse).toList();
  if (parts.length == 3) {
    return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
  }
  return Duration.zero;
}

// --- Data classes from edital_screen.dart ---
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

// --- Main Screen Widget ---
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _subjectSortOrder = 'desc';

  @override
  Widget build(BuildContext context) {
    return Consumer<FilterProvider>(
      builder: (context, filterProvider, child) {
        return Scaffold(
          body: Consumer2<HistoryProvider, AllSubjectsProvider>(
            builder: (context, historyProvider, allSubjectsProvider, child) {
              if (historyProvider.isLoading || allSubjectsProvider.isLoading) {
                return const Center(child: CircularProgressIndicator(color: Colors.teal));
              }

              final filteredRecords = historyProvider.allStudyRecords.where((record) {
                // Date filter
                if (filterProvider.statsStartDate != null && DateTime.parse(record.date).isBefore(filterProvider.statsStartDate!)) {
                  return false;
                }
                if (filterProvider.statsEndDate != null && DateTime.parse(record.date).isAfter(filterProvider.statsEndDate!)) {
                  return false;
                }

                // Duration filter
                if (filterProvider.statsMinDuration != null && record.study_time < filterProvider.statsMinDuration! * 60000) { // convert minutes to ms
                  return false;
                }
                if (filterProvider.statsMaxDuration != null && record.study_time > filterProvider.statsMaxDuration! * 60000) {
                  return false;
                }

                // Performance filter
                final correct = record.questions['correct'] ?? 0;
                final total = record.questions['total'] ?? 0;
                final performance = total > 0 ? (correct / total) * 100 : 0.0;
                if (filterProvider.statsMinPerformance != null && performance < filterProvider.statsMinPerformance!) {
                  return false;
                }
                if (filterProvider.statsMaxPerformance != null && performance > filterProvider.statsMaxPerformance!) {
                  return false;
                }

                // Category filter
                if (filterProvider.statsSelectedCategories.isNotEmpty && !filterProvider.statsSelectedCategories.contains(record.category)) {
                  return false;
                }

                // Subject filter
                if (filterProvider.statsSelectedSubjects.isNotEmpty) {
                  final subject = allSubjectsProvider.subjects.firstWhere((s) => s.id == record.subject_id, orElse: () => Subject(id: '', plan_id: '', subject: '', topics: [], color: ''));
                  if (subject.id.isEmpty || !filterProvider.statsSelectedSubjects.contains(subject.subject)) {
                    return false;
                  }
                }

                // Topic filter
                if (filterProvider.statsSelectedTopics.isNotEmpty && !filterProvider.statsSelectedTopics.contains(record.topic)) {
                  return false;
                }

                return true;
              }).toList();

              final records = filteredRecords;
              final subjects = allSubjectsProvider.subjects;

              // Calculations
              final int totalStudyTime = records.fold(0, (sum, record) => sum + record.study_time);
              final int totalPagesRead = records.fold(0, (sum, record) {
                return sum + record.pages.fold(0, (pageSum, page) {
                  final int start = (page['start'] ?? 0) as int;
                  final int end = (page['end'] ?? 0) as int;
                  return pageSum + (end - start);
                });
              });
              final int totalVideoTime = records.fold(0, (sum, record) {
                return sum + record.videos.fold(0, (videoSum, video) {
                  final start = _parseDuration(video['start'] ?? '00:00:00');
                  final end = _parseDuration(video['end'] ?? '00:00:00');
                  return videoSum + (end - start).inMilliseconds;
                });
              });

              final uniqueStudyDays = records.map((r) => r.date.split('T')[0]).toSet().length;
              final firstRecordDate = records.isNotEmpty ? DateTime.parse(records.map((r) => r.date).min) : DateTime.now();
              final totalDaysSinceFirstRecord = DateTime.now().difference(firstRecordDate).inDays + 1;
              final failedStudyDays = totalDaysSinceFirstRecord - uniqueStudyDays;
              final studyConsistencyPercentage = totalDaysSinceFirstRecord > 0 ? (uniqueStudyDays / totalDaysSinceFirstRecord) * 100 : 0.0;

              // Edital Progress Calculation
              final computedSubjects = _computeSubjectStats(subjects, records);
              final overallStats = _computeOverallStats(computedSubjects);

              final int totalCorrectQuestions = records.fold(0, (sum, record) => sum + (record.questions['correct'] ?? 0));
              final int totalQuestions = records.fold(0, (sum, record) => sum + (record.questions['total'] ?? 0));

              // Daily Stats for EvolucaoTempoChart
              final dailyStats = <DateTime, Map<String, int>>{};
              for (var record in records) {
                final date = DateTime.parse(record.date.split('T')[0]);
                final correct = record.questions['correct'] ?? 0;
                final total = record.questions['total'] ?? 0;
                final incorrect = total - correct;

                dailyStats.update(
                  date,
                  (value) => {
                    'correct': (value['correct'] ?? 0) + correct,
                    'incorrect': (value['incorrect'] ?? 0) + incorrect,
                  },
                  ifAbsent: () => {
                    'correct': correct,
                    'incorrect': incorrect,
                  },
                );
              }

              // Daily Hours for HorasEstudoChart
              final dailyHours = <DateTime, double>{};
              for (var record in records) {
                final date = DateTime.parse(record.date.split('T')[0]);
                final hours = record.study_time / 3600000; // Convert ms to hours

                dailyHours.update(
                  date,
                  (value) => value + hours,
                  ifAbsent: () => hours,
                );
              }

                        // Subject Hours for DisciplinasHorasChart

                        final subjectHours = <Subject, double>{};

                        for (var subject in subjects) {

                          final subjectRecords = records.where((r) => r.subject_id == subject.id);

                          final totalHours = subjectRecords.fold(0.0, (sum, record) => sum + (record.study_time / 3600000));

                          if (totalHours > 0) {

                            subjectHours[subject] = totalHours;

                          }

                        }

              

                        // Category Hours for CategoryHoursChart

                        final categoryHours = <String, double>{};

                        for (var record in records) {

                          final hours = record.study_time / 3600000; // Convert ms to hours

                          categoryHours.update(

                            record.category,

                            (value) => value + hours,

                            ifAbsent: () => hours,

                          );

                        }

              

                        // Subject Performance for DisciplinasDesempenhoChart

                        final Map<Subject, SubjectPerformanceData> subjectPerformanceData = {};

                        for (var computedSubject in computedSubjects) {

                          int totalQuestions = 0;

                          int correctQuestions = 0;

              

                          // Agrega as questões de todos os tópicos da disciplina

                          for (var topic in computedSubject.topics) {

                            totalQuestions += topic.totalQuestions;

                            correctQuestions += topic.correctQuestions;

                          }

              

                          // Só adiciona a disciplina ao mapa se houver questões registradas

                          if (totalQuestions > 0) {

                            subjectPerformanceData[computedSubject.originalSubject] = SubjectPerformanceData(

                              subject: computedSubject.originalSubject,

                              correctQuestions: correctQuestions,

                              totalQuestions: totalQuestions,

                            );

                          }

                        }

              

                        final topicPerformanceData = _buildTopicPerformanceData(computedSubjects);

              

                        return SingleChildScrollView(

                          padding: const EdgeInsets.all(16.0),

                          child: Column(

                            crossAxisAlignment: CrossAxisAlignment.stretch,

                            children: [

                              const SizedBox(height: 24),

                              _buildTopSummarySection(

                                context,

                                totalStudyTime,

                                uniqueStudyDays,

                                totalPagesRead,

                                totalVideoTime,

                                studyConsistencyPercentage,

                                totalDaysSinceFirstRecord,

                                failedStudyDays,

                                overallStats,

                                totalCorrectQuestions,

                                totalQuestions,

                              ),

                              const SizedBox(height: 24),

                              Card(

                                elevation: 2,

                                child: Padding(

                                  padding: const EdgeInsets.all(16.0),

                                  child: Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      const Text('Evolução no Tempo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                                      const SizedBox(height: 16),

                                      EvolucaoTempoChart(dailyStats: dailyStats),

                                    ],

                                  ),

                                ),

                              ),

                              const SizedBox(height: 16),

                              Card(

                                elevation: 2,

                                child: Padding(

                                  padding: const EdgeInsets.all(16.0),

                                  child: Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      const Text('HORAS DE ESTUDO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                                      const SizedBox(height: 16),

                                      HorasEstudoChart(dailyHours: dailyHours),

                                    ],

                                  ),

                                ),

                              ),

                              const SizedBox(height: 16),

                              _buildSubjectHoursAndCategoryChart(context, subjectHours, categoryHours),

                              const SizedBox(height: 16),

                                              Card(

                                elevation: 2,

                                child: Padding(

                                  padding: const EdgeInsets.all(16.0),

                                  child: Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      const Text('DISCIPLINAS x DESEMPENHO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                                      const SizedBox(height: 16),

                                      DisciplinasDesempenhoChart(subjectPerformanceData: subjectPerformanceData),

                                    ],

                                  ),

                                ),

                              ),

                              const SizedBox(height: 16),

                              Card(

                                elevation: 2,

                                child: Padding(

                                  padding: const EdgeInsets.all(16.0),

                                  child: Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      const Text('TÓPICO X DESEMPENHO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                                      const SizedBox(height: 16),

                                      TopicPerformanceTable(data: topicPerformanceData),

                                    ],

                                  ),

                                ),

                              ),

                            ],

                          ),

                        );

                      },

                    ),

                  );
      },
    );
            }

          

            List<HierarchicalPerformanceNode> _buildTopicPerformanceData(List<_ComputedSubject> computedSubjects) {

              final List<HierarchicalPerformanceNode> subjectNodes = [];

          

              HierarchicalPerformanceNode convertTopic(_ComputedTopic computedTopic) {

                return HierarchicalPerformanceNode(

                  id: '${computedTopic.originalTopic.id}',

                  name: computedTopic.originalTopic.topic_text,

                  acertos: computedTopic.correctQuestions,

                  erros: computedTopic.totalQuestions - computedTopic.correctQuestions,

                  total: computedTopic.totalQuestions,

                  percentualAcerto: computedTopic.performance,

                  isGroupingTopic: computedTopic.isGroupingTopic,

                  level: computedTopic.level + 1, // Indent topics under subjects

                  children: computedTopic.subTopics.map(convertTopic).toList(),

                );

              }

          

              for (final computedSubject in computedSubjects) {

                int totalQuestions = 0;

                int correctQuestions = 0;

                for (var topic in computedSubject.topics) {

                  totalQuestions += topic.totalQuestions;

                  correctQuestions += topic.correctQuestions;

                }

          

                if (totalQuestions > 0) {

                  subjectNodes.add(

                    HierarchicalPerformanceNode(

                      id: computedSubject.originalSubject.id,

                      name: computedSubject.originalSubject.subject,

                      acertos: correctQuestions,

                      erros: totalQuestions - correctQuestions,

                      total: totalQuestions,

                      percentualAcerto: totalQuestions > 0 ? (correctQuestions / totalQuestions) * 100 : 0.0,

                      isGroupingTopic: true,

                      level: 0,

                      children: computedSubject.topics.map(convertTopic).toList(),

                    )

                  );

                }

              }

              return subjectNodes;

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

          

            Widget _buildTopSummarySection(

              BuildContext context,

              int totalStudyTime,

              int uniqueStudyDays,

              int totalPagesRead,

              int totalVideoTime,

              double studyConsistencyPercentage,

              int totalDaysSinceFirstRecord,

              int failedStudyDays,

              _OverallStats overallStats,

              int totalCorrectQuestions,

              int totalQuestions,

            ) {

              return Column(

                                children: [

                                  // Linha 1

                                                                    IntrinsicHeight(

                                                                      child: Row(

                                                                        crossAxisAlignment: CrossAxisAlignment.start,

                                                                        children: [

                                                                          Expanded(

                                                                            child: Card(

                                                                              elevation: 2,

                                                                              child: Padding(

                                                                                padding: const EdgeInsets.all(16.0),

                                                                                child: Column(

                                                                                  crossAxisAlignment: CrossAxisAlignment.start,

                                                                                  children: [

                                                                                    const Text('Desempenho Geral', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                                                                                    const SizedBox(height: 16),

                                                                                    GeralPerformanceChart(

                                                                                      correctPercentage: totalQuestions > 0 ? (totalCorrectQuestions / totalQuestions) * 100 : 0,

                                                                                      totalCorrectQuestions: totalCorrectQuestions,

                                                                                      totalQuestions: totalQuestions,

                                                                                    ),

                                                                                  ],

                                                                                ),

                                                                              ),

                                                                            ),

                                                                          ),

                                                                          const SizedBox(width: 16),

                                                                          Expanded(

                                                                            child: _buildSummaryCard(

                                                                              title: 'Tempo Total de Estudo',

                                                                              value: formatTime(totalStudyTime),

                                                                              subtitle1: '${formatTime(uniqueStudyDays > 0 ? (totalStudyTime / uniqueStudyDays).round() : 0)} por dia estudado (média)',

                                                                              subtitle2: 'Total de $uniqueStudyDays dias estudados',

                                                                            ),

                                                                          ),

                                                                        ],

                                                                      ),

                                                                    ),

                                  const SizedBox(height: 16),

                                  // Linha 2

                                                                    IntrinsicHeight(

                                                                      child: Row(

                                                                        crossAxisAlignment: CrossAxisAlignment.start,

                                                                        children: [

                                                                          Expanded(

                                                                            child: _buildSummaryCard(

                                                                              title: 'Páginas Lidas',

                                                                              value: totalPagesRead.toString(),

                                                                              subtitle1: '${(totalPagesRead / (totalStudyTime > 0 ? totalStudyTime / 3600000 : 1)).toStringAsFixed(1)} páginas/hora',

                                                                            ),

                                                                          ),

                                                                          const SizedBox(width: 16),

                                                                          Expanded(

                                                                            child: _buildSummaryCard(

                                                                              title: 'Tempo Total de Videoaulas',

                                                                              value: formatTime(totalVideoTime),

                                                                            ),

                                                                          ),

                                                                        ],

                                                                      ),

                                                                    ),

                                  const SizedBox(height: 16),

                                  // Linha 3

                                  Row(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      Expanded(

                                        child: _buildSummaryCard(

                                          title: 'Constância nos Estudos',

                                          value: '${studyConsistencyPercentage.toStringAsFixed(1)}%',

                                          subtitle1: '$uniqueStudyDays dias estudados de $totalDaysSinceFirstRecord dias',

                                          subtitle2: '($failedStudyDays dias falhados)',

                                        ),

                                      ),

                                      const SizedBox(width: 16),

                                      Expanded(

                                        child: _buildSummaryCard(

                                          title: 'Progresso no Edital',

                                          value: '${(overallStats.progress * 100).toStringAsFixed(1)}%',

                                          subtitle1: '${overallStats.completed} tópicos concluídos de ${overallStats.total}',

                                          subtitle2: '(${overallStats.total - overallStats.completed} tópicos pendentes)',

                                        ),

                                      ),

                                    ],

                                  ),

                                ],

              );

            }

          

            Widget _buildSummaryCard({

              required String title,

              required String value,

              String? subtitle1,

              String? subtitle2,

            }) {

              return Card(

                elevation: 2,

                child: Padding(

                  padding: const EdgeInsets.all(16.0),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                                            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),

                                            const SizedBox(height: 8),

                                            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),

                                            if (subtitle1 != null) Text(subtitle1, style: TextStyle(color: Colors.grey[600])),

                                            if (subtitle2 != null) Text(subtitle2, style: TextStyle(color: Colors.grey[600])),

                                          ],

                                        ),

                                      ),

                                    );

                                  }

                      

                                  Widget _buildChartCard(String title, String chartPlaceholderText) {

                                    return Card(

                                      elevation: 2,

                                      child: Padding(

                                        padding: const EdgeInsets.all(16.0),

                                        child: Column(

                                          crossAxisAlignment: CrossAxisAlignment.start,

                                          children: [

                                            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                                            const SizedBox(height: 16),

                                            Container(

                                              height: 200,

                                              color: Colors.grey[200],

                                              child: Center(child: Text(chartPlaceholderText)),

                                            ),

                                          ],

                                        ),

                                      ),

                                    );

                                  }

                      

                                  Widget _buildSubjectHoursAndCategoryChart(BuildContext context, Map<Subject, double> subjectHours, Map<String, double> categoryHours) {

                                    return Column(

                                      children: [

                                        Card(

                                            elevation: 2,

                                            child: Padding(

                                              padding: const EdgeInsets.all(16.0),

                                              child: Column(

                                                crossAxisAlignment: CrossAxisAlignment.start,

                                                children: [

                                                  Row(

                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                                                    children: [

                                                      const Expanded(

                                                        child: Text('DISCIPLINAS x HORAS DE ESTUDO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                                                      ),

                                                      Row(

                                                        children: [

                                                          IconButton(

                                                            icon: const Icon(Icons.arrow_downward),

                                                            onPressed: () => setState(() => _subjectSortOrder = 'desc'),

                                                            color: _subjectSortOrder == 'desc' ? Colors.teal : Colors.grey,

                                                          ),

                                                          IconButton(

                                                            icon: const Icon(Icons.arrow_upward),

                                                            onPressed: () => setState(() => _subjectSortOrder = 'asc'),

                                                            color: _subjectSortOrder == 'asc' ? Colors.teal : Colors.grey,

                                                          ),

                                                          IconButton(

                                                            icon: const Icon(Icons.sort_by_alpha),

                                                            onPressed: () => setState(() => _subjectSortOrder = 'alpha'),

                                                            color: _subjectSortOrder == 'alpha' ? Colors.teal : Colors.grey,

                                                          ),

                                                        ],

                                                      ),

                                                    ],

                                                  ),

                                                  const SizedBox(height: 16),

                                                  DisciplinasHorasChart(subjectHours: subjectHours, sortOrder: _subjectSortOrder),

                                                ],

                                              ),

                                            ),

                                          ),

                                        const SizedBox(height: 16),

                                        Card(

                                          elevation: 2,

                                          child: Padding(

                                            padding: const EdgeInsets.all(16.0),

                                            child: CategoryHoursChart(categoryHours: categoryHours),

                                          ),

                                        ),

                                      ],

                                    );

                                  }

                                }

          