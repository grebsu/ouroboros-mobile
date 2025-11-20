import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/plans_provider.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/widgets/study_consistency_grid.dart';
import 'package:ouroboros_mobile/widgets/performance_table.dart';
import 'package:ouroboros_mobile/widgets/weekly_bar_chart.dart';
import 'package:ouroboros_mobile/widgets/revisions_section.dart';
import 'package:ouroboros_mobile/widgets/planning_section.dart';
import 'package:ouroboros_mobile/widgets/last_activities_section.dart';
import 'package:ouroboros_mobile/widgets/daily_study_section.dart';
import 'package:ouroboros_mobile/widgets/reminders_section.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';

enum ChartView { time, questions }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ChartView _chartView = ChartView.time;
  DateTime _consistencyEndDate = DateTime.now();

  void _handleConsistencyNav(int direction) {
    setState(() {
      _consistencyEndDate =
          _consistencyEndDate.add(Duration(days: direction * 30));
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<HistoryProvider>();
    final activePlanProvider = context.watch<ActivePlanProvider>();
    final allSubjectsProvider = context.watch<AllSubjectsProvider>();
    final planningProvider = context.watch<PlanningProvider>();

    if (historyProvider.isLoading ||
        allSubjectsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    final allRecords = historyProvider.allStudyRecords;

    // Find the oldest study record date
    DateTime? oldestStudyRecordDate;
    if (allRecords.isNotEmpty) {
      oldestStudyRecordDate = allRecords
          .map((record) => DateTime.parse(record.date).toLocal())
          .reduce((minDate, date) => date.isBefore(minDate) ? date : minDate);
      oldestStudyRecordDate = DateTime(oldestStudyRecordDate.year,
          oldestStudyRecordDate.month, oldestStudyRecordDate.day);
    }

    // Calculate Total Study Time
    final totalMs =
        allRecords.fold<int>(0, (sum, record) => sum + record.study_time);
    final totalStudyTime = Duration(milliseconds: totalMs);

    // Calculate Daily Average
    Duration dailyAverage = Duration.zero;
    if (allRecords.isNotEmpty) {
      final Map<DateTime, int> dailyTotals = {};
      for (var record in allRecords) {
        try {
          final date = DateTime.parse(record.date).toLocal();
          final day = DateTime(date.year, date.month, date.day);
          dailyTotals[day] = (dailyTotals[day] ?? 0) + record.study_time;
        } catch (e) {
          print('Invalid date format in record: ${record.id}');
        }
      }
      if (dailyTotals.isNotEmpty) {
        final averageMs = totalMs / dailyTotals.length;
        dailyAverage = Duration(milliseconds: averageMs.round());
      }
    }

    // Calculate Performance
    int totalQuestions = 0;
    int correctQuestions = 0;
    for (var record in allRecords) {
      if (record.questions.containsKey('total') &&
          record.questions['total'] is int) {
        totalQuestions += record.questions['total'] as int;
      }
      if (record.questions.containsKey('correct') &&
          record.questions['correct'] is int) {
        correctQuestions += record.questions['correct'] as int;
      }
    }
    final performance =
        totalQuestions > 0 ? (correctQuestions / totalQuestions) * 100 : 0.0;

    // Calculate Syllabus Progress
    double progress = 0.0;
    final activePlanId = activePlanProvider.activePlanId;
    if (activePlanId != null) {
      final subjectsInPlan = allSubjectsProvider.subjects
          .where((s) => s.plan_id == activePlanId)
          .toList();
      final totalTopics = subjectsInPlan.fold<int>(
          0, (sum, subject) => sum + (subject.total_topics_count ?? 0));

      final studiedTopics = <String>{};
      for (var record in allRecords.where((r) => r.plan_id == activePlanId)) {
        studiedTopics.add(record.topic);
      }

      progress =
          totalTopics > 0 ? (studiedTopics.length / totalTopics) * 100 : 0.0;
    }

    // Calculate Studied Days and Streak
    Set<DateTime> studiedDays = {};
    int studyStreak = 0;
    if (allRecords.isNotEmpty) {
      final uniqueStudyDays = allRecords.map((record) {
        try {
          final date = DateTime.parse(record.date).toLocal();
          return DateTime(date.year, date.month, date.day);
        } catch (e) {
          return null;
        }
      }).where((d) => d != null).cast<DateTime>().toSet();
      studiedDays = uniqueStudyDays;

      // Calculate streak
      var checkDate = DateTime.now();
      var today = DateTime(checkDate.year, checkDate.month, checkDate.day);

      if (!uniqueStudyDays.contains(today)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      while (uniqueStudyDays
          .contains(DateTime(checkDate.year, checkDate.month, checkDate.day))) {
        studyStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    }

    // Calculate consistency data for the grid
    final today = DateTime.now();
    final todayWithoutTime = DateTime(today.year, today.month, today.day);
    final endDate = DateTime(_consistencyEndDate.year,
        _consistencyEndDate.month, _consistencyEndDate.day);
    final startDate = endDate.subtract(const Duration(days: 29));

    final studyDaysPlanning = planningProvider.studyDays;
    final dayFormatter = DateFormat('EEEE', 'pt_BR');

    final List<Map<String, dynamic>> consistencyData = [];
    for (int i = 0; i < 30; i++) {
      final date = startDate.add(Duration(days: i));
      final dayName = dayFormatter.format(date);
      final isStudied = studiedDays.contains(date);
      final isStudyDay = studyDaysPlanning
          .any((d) => dayName.toLowerCase().startsWith(d.toLowerCase()));
      final isRestDay = !isStudyDay;

      String status;
      if (oldestStudyRecordDate != null && date.isBefore(oldestStudyRecordDate)) {
        status = 'inactive';
      } else if (isStudied) {
        status = 'studied';
      } else if (isRestDay) {
        status = 'rest_day';
      } else {
        status = 'not_studied';
      }

      consistencyData.add({
        'date': date,
        'status': status,
        'active': date.isBefore(todayWithoutTime) ||
            date.isAtSameMomentAs(todayWithoutTime),
      });
    }

    // Calculate Performance Data per Subject
    final Map<String, Map<String, int>> subjectPerformance = {};
    final Map<String, int> subjectStudyTimeMs = {};

    for (var record in allRecords) {
      final subjectId = record.subject_id;
      if (subjectId != null) {
        subjectPerformance.putIfAbsent(
            subjectId, () => {'total': 0, 'correct': 0});
        subjectStudyTimeMs.update(
            subjectId, (value) => value + record.study_time,
            ifAbsent: () => record.study_time);

        if (record.questions.containsKey('total') &&
            record.questions['total'] is int) {
          subjectPerformance[subjectId]!['total'] =
              (subjectPerformance[subjectId]!['total'] ?? 0) +
                  (record.questions['total'] as int);
        }
        if (record.questions.containsKey('correct') &&
            record.questions['correct'] is int) {
          subjectPerformance[subjectId]!['correct'] =
              (subjectPerformance[subjectId]!['correct'] ?? 0) +
                  (record.questions['correct'] as int);
        }
      }
    }

    List<PerformanceData> performanceData = [];
    for (var entry in subjectPerformance.entries) {
      final subject = allSubjectsProvider.subjects.firstWhere(
          (s) => s.id == entry.key,
          orElse: () => Subject(
              id: '',
              plan_id: '',
              subject: 'Desconhecido',
              color: '#808080',
              topics: [],
              total_topics_count: 0));
      final total = entry.value['total'] ?? 0;
      final correct = entry.value['correct'] ?? 0;
      final perf = total > 0 ? (correct / total) * 100 : 0.0;
      final studyTime =
          Duration(milliseconds: subjectStudyTimeMs[entry.key] ?? 0);

      performanceData.add(PerformanceData(
        subject: subject,
        totalQuestions: total,
        correctQuestions: correct,
        performance: perf,
        studyTime: studyTime,
      ));
    }
    performanceData.sort((a, b) => a.performance.compareTo(b.performance));

    // Calculate Weekly Data
    List<Duration> weeklyData = List.filled(7, Duration.zero);
    List<int> weeklyQuestionsData = List.filled(7, 0);
    final weekStartDate = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    for (var record in allRecords) {
      try {
        final recordDate = DateTime.parse(record.date).toLocal();
        if (recordDate.isAfter(weekStartDate.subtract(const Duration(days: 1)))) {
          final dayIndex = recordDate.difference(weekStartDate).inDays;
          if (dayIndex >= 0 && dayIndex < 7) {
            weeklyData[dayIndex] += Duration(milliseconds: record.study_time);
            if (record.questions.containsKey('total') &&
                record.questions['total'] is int) {
              weeklyQuestionsData[dayIndex] +=
                  record.questions['total'] as int;
            }
          }
        }
      } catch (e) {
        // ignore
      }
    }

    // Calculate Daily Subject Study Time
    Map<String, Map<String, int>> dailySubjectStudyTime = {};
    for (var record in allRecords) {
      try {
        final dateKey =
            DateTime.parse(record.date).toLocal().toIso8601String().split('T')[0];
        final subjectName = allSubjectsProvider.subjects
            .firstWhere((s) => s.id == record.subject_id,
                orElse: () => Subject(
                    id: '',
                    plan_id: '',
                    subject: 'Desconhecido',
                    color: '#808080',
                    topics: []))
            .subject;
        dailySubjectStudyTime.putIfAbsent(dateKey, () => {});
        dailySubjectStudyTime[dateKey]!.update(
            subjectName, (value) => value + record.study_time,
            ifAbsent: () => record.study_time);
      } catch (e) {
        print('Error calculating daily subject study time: $e');
      }
    }

    // Populate Subject Colors
    final subjectColors = allSubjectsProvider.subjects;

    // Calculate Weekly Goals
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    Duration weeklyHours = Duration.zero;
    int weeklyQuestions = 0;

    for (var record in allRecords) {
      try {
        final recordDate = DateTime.parse(record.date).toLocal();
        if (recordDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            recordDate.isBefore(endOfWeek.add(const Duration(days: 1)))) {
          weeklyHours += Duration(milliseconds: record.study_time);
          if (record.questions.containsKey('total') &&
              record.questions['total'] is int) {
            weeklyQuestions += record.questions['total'] as int;
          }
        }
      } catch (e) {
        // ignore
      }
    }

    final goalHours =
        Duration(hours: int.tryParse(planningProvider.studyHours) ?? 0);
    final goalQuestions =
        int.tryParse(planningProvider.weeklyQuestionsGoal) ?? 0;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = constraints.maxWidth > 600;
                if (isLandscape) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: SummaryCard(
                        icon: MaterialCommunityIcons.clock_time_three_outline,
                        title: 'Tempo de Estudo',
                        value: _formatDuration(totalStudyTime),
                        color: Colors.teal,
                        iconColor: Colors.teal,
                        isLandscape: true,
                      )),
                      const SizedBox(width: 16),
                      Expanded(
                          child: SummaryCard(
                        icon: MaterialCommunityIcons.calendar_today,
                        title: 'Média Diária',
                        value: _formatDuration(dailyAverage),
                        color: Colors.teal,
                        iconColor: const Color(0xFF3182F7),
                        isLandscape: true,
                      )),
                      const SizedBox(width: 16),
                      Expanded(
                          child: SummaryCard(
                        icon: MaterialCommunityIcons.bullseye_arrow,
                        title: 'Desempenho',
                        value: '${performance.toStringAsFixed(1)}%',
                        color: Colors.teal,
                        iconColor: const Color(0xFFF55343),
                        isLandscape: true,
                      )),
                      const SizedBox(width: 16),
                      Expanded(
                          child: SummaryCard(
                        icon: MaterialCommunityIcons.file_document_outline,
                        title: 'Progresso Edital',
                        value: '${progress.toStringAsFixed(1)}%',
                        color: Colors.teal,
                        iconColor: const Color(0xFFAA67F8),
                        isLandscape: true,
                      )),
                    ],
                  );
                } else {
                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.9,
                    children: [
                      SummaryCard(
                        icon: MaterialCommunityIcons.clock_time_three_outline,
                        title: 'Tempo de Estudo',
                        value: _formatDuration(totalStudyTime),
                        color: Colors.teal,
                        iconColor: Colors.teal,
                      ),
                      SummaryCard(
                        icon: MaterialCommunityIcons.calendar_today,
                        title: 'Média Diária',
                        value: _formatDuration(dailyAverage),
                        color: Colors.teal,
                        iconColor: const Color(0xFF3182F7),
                      ),
                      SummaryCard(
                        icon: MaterialCommunityIcons.bullseye_arrow,
                        title: 'Desempenho',
                        value: '${performance.toStringAsFixed(1)}%',
                        color: Colors.teal,
                        iconColor: const Color(0xFFF55343),
                      ),
                      SummaryCard(
                        icon: MaterialCommunityIcons.file_document_outline,
                        title: 'Progresso Edital',
                        value: '${progress.toStringAsFixed(1)}%',
                        color: Colors.teal,
                        iconColor: const Color(0xFFAA67F8),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 24),

            // Study Consistency Tracker
            if (allRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CONSTÂNCIA NOS ESTUDOS',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Nenhum registro de estudo ainda. Comece a estudar para ver sua consistência!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              StudyConsistencyTracker(
                studyStreak: studyStreak,
                daysData: consistencyData,
                startDate:
                    _consistencyEndDate.subtract(const Duration(days: 29)),
                endDate: _consistencyEndDate,
                onPrev: () => _handleConsistencyNav(-1),
                onNext: () => _handleConsistencyNav(1),
              ),
            const SizedBox(height: 24),

            // Performance Panel and Goals
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: PerformancePanel(
                            performanceData: performanceData),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            WeeklyStudyGoals(
                              currentHours: weeklyHours,
                              goalHours: goalHours,
                              currentQuestions: weeklyQuestions,
                              goalQuestions: goalQuestions,
                            ),
                            SizedBox(height: 24),
                            WeeklyStudyChart(
                              weeklyData: weeklyData,
                              weeklyQuestionsData: weeklyQuestionsData,
                              currentView: _chartView,
                              onViewModeChanged: (view) {
                                setState(() {
                                  _chartView = view;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      PerformancePanel(performanceData: performanceData),
                      SizedBox(height: 24),
                      WeeklyStudyGoals(
                        currentHours: weeklyHours,
                        goalHours: goalHours,
                        currentQuestions: weeklyQuestions,
                        goalQuestions: goalQuestions,
                      ),
                      SizedBox(height: 24),
                      WeeklyStudyChart(
                        weeklyData: weeklyData,
                        weeklyQuestionsData: weeklyQuestionsData,
                        currentView: _chartView,
                        onViewModeChanged: (view) {
                          setState(() {
                            _chartView = view;
                          });
                        },
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 24),

            // Additional Sections
            const RevisionsSection(),
            const SizedBox(height: 24),
            const PlanningSection(),
            const SizedBox(height: 24),
            const LastActivitiesSection(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DailyStudySection(
                      dailySubjectStudyTime: dailySubjectStudyTime,
                      subjectColors: subjectColors),
                ),
                const SizedBox(width: 24), // Spacing between sections
                Expanded(
                  child: const RemindersSection(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final Color iconColor; // New property for icon color
  final bool isLandscape;

  const SummaryCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.iconColor, // Required in constructor
    this.isLandscape = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isLandscape ? 8.0 : 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: isLandscape ? 24 : 32, color: iconColor), // Use iconColor here
            ),
            SizedBox(width: isLandscape ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.white, fontSize: isLandscape ? 14 : 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isLandscape ? 20 : 24,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudyConsistencyTracker extends StatelessWidget {
  final int studyStreak;
  final List<Map<String, dynamic>> daysData;
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const StudyConsistencyTracker({
    Key? key,
    required this.studyStreak,
    required this.daysData,
    required this.startDate,
    required this.endDate,
    required this.onPrev,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isNextDisabled = endDate.isAfter(DateTime.now()) || 
                           DateTime(endDate.year, endDate.month, endDate.day) == 
                           DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONSTÂNCIA NOS ESTUDOS',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text('Você está há $studyStreak dias sem falhar!'),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: onPrev,
                    ),
                    Text(
                      '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: isNextDisabled ? null : onNext,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            StudyConsistencyGrid(daysData: daysData),
          ],
        ),
      ),
    );
  }
}

class PerformancePanel extends StatelessWidget {
  final List<PerformanceData> performanceData;

  const PerformancePanel({Key? key, required this.performanceData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Painel de Desempenho',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            PerformanceTable(performanceData: performanceData),
          ],
        ),
      ),
    );
  }
}

class WeeklyStudyGoals extends StatelessWidget {
  final Duration currentHours;
  final Duration goalHours;
  final int currentQuestions;
  final int goalQuestions;

  const WeeklyStudyGoals({
    Key? key,
    required this.currentHours,
    required this.goalHours,
    required this.currentQuestions,
    required this.goalQuestions,
  }) : super(key: key);

  String _formatHours(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}h${minutes.toString().padLeft(2, '0')}min';
  }

  Color _getBarColor(double percentage) {
    if (percentage >= 100) return Colors.teal.shade500;
    if (percentage > 80) return Colors.amber.shade400;
    if (percentage > 40) return Colors.orange.shade400;
    return Colors.red.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final hoursPercentage = goalHours.inMilliseconds > 0 ? (currentHours.inMilliseconds / goalHours.inMilliseconds) * 100 : 0.0;
    final questionsPercentage = goalQuestions > 0 ? (currentQuestions / goalQuestions) * 100 : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'METAS DE ESTUDO SEMANAL',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildGoalBar(
              title: 'Horas de Estudo',
              currentValue: _formatHours(currentHours),
              goalValue: _formatHours(goalHours),
              percentage: hoursPercentage,
              barColor: _getBarColor(hoursPercentage),
            ),
            const SizedBox(height: 16),
            _buildGoalBar(
              title: 'Questões',
              currentValue: currentQuestions.toString(),
              goalValue: goalQuestions > 0 ? goalQuestions.toString() : 'N/A',
              percentage: questionsPercentage,
              barColor: _getBarColor(questionsPercentage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalBar({
    required String title,
    required String currentValue,
    required String goalValue,
    required double percentage,
    required Color barColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text('$currentValue / $goalValue', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6.0), // Half of minHeight for rounded ends
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade300,
            color: barColor,
            minHeight: 12,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: barColor, // Use the bar's color
              fontWeight: FontWeight.bold, // Make it bold
            ),
          ),
        ),
      ],
    );
  }
}

class WeeklyStudyChart extends StatelessWidget {
  final List<Duration> weeklyData;
  final List<int> weeklyQuestionsData;
  final ChartView currentView;
  final ValueChanged<ChartView> onViewModeChanged;

  const WeeklyStudyChart({
    Key? key,
    required this.weeklyData,
    required this.weeklyQuestionsData,
    required this.currentView,
    required this.onViewModeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'ESTUDO SEMANAL',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ToggleButtons(
                  isSelected: [
                    currentView == ChartView.time,
                    currentView == ChartView.questions,
                  ],
                  onPressed: (int index) {
                    if (index == 0) {
                      onViewModeChanged(ChartView.time);
                    } else {
                      onViewModeChanged(ChartView.questions);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  selectedColor: Colors.white,
                  fillColor: Colors.teal,
                  color: Colors.grey, // Color for unselected items
                  borderColor: Colors.grey, // Border for unselected items
                  selectedBorderColor: Colors.teal,
                  constraints: const BoxConstraints(minHeight: 32.0, minWidth: 64.0),
                  children: const <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('TEMPO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('QUESTÕES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            WeeklyBarChart(
              weeklyData: weeklyData,
              weeklyQuestionsData: weeklyQuestionsData,
              currentView: currentView,
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder Widgets for other sections






