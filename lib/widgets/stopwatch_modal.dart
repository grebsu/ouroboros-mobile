import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/providers/review_provider.dart';
import 'package:ouroboros_mobile/providers/stopwatch_provider.dart';
import 'package:ouroboros_mobile/widgets/number_picker_wheel.dart';
import 'package:collection/collection.dart';

class StopwatchModal extends StatefulWidget {
  const StopwatchModal({
    super.key,
  });

  @override
  State<StopwatchModal> createState() => _StopwatchModalState();
}

class _StopwatchModalState extends State<StopwatchModal> with SingleTickerProviderStateMixin {
  late AnimationController _barberPoleController;
  late Animation<double> _barberPoleAnimation;

  void _handleGetRecommendation() {
    final planningProvider = Provider.of<PlanningProvider>(context, listen: false);
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context, listen: false);
    final stopwatchProvider = Provider.of<StopwatchProvider>(context, listen: false);

    final recommendation = planningProvider.getRecommendedSession(
      studyRecords: historyProvider.allStudyRecords,
      subjects: allSubjectsProvider.subjects,
      reviewRecords: Provider.of<ReviewProvider>(context, listen: false).allReviewRecords,
    );

    final recommendedTopic = recommendation['recommendedTopic'] as Topic?;
    final nextSession = recommendation['nextSession'] as StudySession?;

    if (nextSession != null) {
      stopwatchProvider.setContext(
        planId: stopwatchProvider.planId!,
        subjectId: nextSession.subjectId,
        topic: recommendedTopic,
        durationMinutes: nextSession.duration,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(recommendation['justification'] ?? 'Não há mais sessões no ciclo.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _barberPoleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _barberPoleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_barberPoleController);
  }

  @override
  void dispose() {
    _barberPoleController.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<int>> _buildTopicDropdownItems(List<Topic> topics, {int level = 0}) {
    List<DropdownMenuItem<int>> items = [];
    for (var topic in topics) {
      final isGroupingTopic = topic.sub_topics != null && topic.sub_topics!.isNotEmpty;
      if (topic.id != null) {
        items.add(DropdownMenuItem<int>(
          value: topic.id,
          enabled: !isGroupingTopic,
          child: Padding(
            padding: EdgeInsets.only(left: level * 16.0),
            child: Text(
              topic.topic_text,
              style: TextStyle(
                fontWeight: isGroupingTopic ? FontWeight.bold : FontWeight.normal,
                color: isGroupingTopic ? Colors.grey : null,
              ),
            ),
          ),
        ));
      }
      if (isGroupingTopic) {
        items.addAll(_buildTopicDropdownItems(topic.sub_topics!, level: level + 1));
      }
    }
    return items;
  }

  Topic? _findTopicById(List<Topic> topics, int id) {
    for (var topic in topics) {
      if (topic.id == id) {
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

  @override
  Widget build(BuildContext context) {
    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context);
    final stopwatchProvider = Provider.of<StopwatchProvider>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16.0),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D2938) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: stopwatchProvider.selectedSubjectId,
                            hint: Text('Matéria', style: TextStyle(color: Theme.of(context).hintColor)),
                            onChanged: (value) {
                              stopwatchProvider.setSubject(value);
                            },
                            items: allSubjectsProvider.subjects.map((subject) {
                              return DropdownMenuItem(
                                value: subject.id,
                                child: Text(
                                  subject.subject,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                                ),
                              );
                            }).toList(),
                            dropdownColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                            iconEnabledColor: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D2938) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: stopwatchProvider.selectedTopic?.id,
                            hint: Text('Tópico', style: TextStyle(color: Theme.of(context).hintColor)),
                            onChanged: (value) {
                              if (value != null) {
                                final subjectTopics = allSubjectsProvider.subjects
                                    .firstWhereOrNull((s) => s.id == stopwatchProvider.selectedSubjectId)?.topics ?? [];
                                final topic = _findTopicById(subjectTopics, value);
                                if (topic != null) {
                                  stopwatchProvider.setTopic(topic);
                                }
                              }
                            },
                            items: stopwatchProvider.selectedSubjectId != null
                                ? _buildTopicDropdownItems(
                                    allSubjectsProvider.subjects
                                        .firstWhereOrNull((s) => s.id == stopwatchProvider.selectedSubjectId)?.topics ?? [])
                                : [],
                            dropdownColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                            iconEnabledColor: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                SizedBox(
                  height: 20,
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          stopwatchProvider.selectedSubjectId != null
                              ? allSubjectsProvider.subjects.firstWhereOrNull((s) => s.id == stopwatchProvider.selectedSubjectId)?.subject ?? 'Sessão de Estudo'
                              : 'Sessão de Estudo',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          stopwatchProvider.isTimerMode ? _formatProgressText(stopwatchProvider.timerDuration.inMilliseconds - stopwatchProvider.stopwatch.elapsed.inMilliseconds, stopwatchProvider.timerDuration.inMilliseconds) : '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4.0),
                Container(
                  height: 24.0,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: stopwatchProvider.isTimerMode
                        ? LinearProgressIndicator(
                            value: stopwatchProvider.timerDuration.inMilliseconds > 0
                                ? (stopwatchProvider.timerDuration.inMilliseconds - stopwatchProvider.stopwatch.elapsed.inMilliseconds) / stopwatchProvider.timerDuration.inMilliseconds
                                : 0,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                            backgroundColor: Colors.transparent,
                          )
                        : AnimatedBuilder(
                            animation: _barberPoleAnimation,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: BarberPolePainter(animationValue: _barberPoleAnimation.value, isRunning: stopwatchProvider.isRunning),
                                child: Container(),
                              );
                            },
                          ),
                  ),
                ),
                if (stopwatchProvider.selectedTopic != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Center(
                      child: Text(
                        stopwatchProvider.selectedTopic!.topic_text,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                const SizedBox(height: 24.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (stopwatchProvider.isTimerMode && !stopwatchProvider.isRunning)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: NumberPickerWheel(
                                minValue: 0,
                                maxValue: 23,
                                initialValue: stopwatchProvider.timerDuration.inHours,
                                onChanged: (value) {
                                  final current = stopwatchProvider.timerDuration;
                                  stopwatchProvider.setTimerDuration(Duration(hours: value, minutes: current.inMinutes % 60, seconds: current.inSeconds % 60));
                                },
                                textStyle: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal),
                                itemExtent: 60.0,
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              ),
                            ),
                            const Text(':', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal)),
                            Expanded(
                              child: NumberPickerWheel(
                                minValue: 0,
                                maxValue: 59,
                                initialValue: stopwatchProvider.timerDuration.inMinutes % 60,
                                onChanged: (value) {
                                  final current = stopwatchProvider.timerDuration;
                                  stopwatchProvider.setTimerDuration(Duration(hours: current.inHours, minutes: value, seconds: current.inSeconds % 60));
                                },
                                textStyle: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal),
                                itemExtent: 60.0,
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              ),
                            ),
                            const Text(':', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal)),
                            Expanded(
                              child: NumberPickerWheel(
                                minValue: 0,
                                maxValue: 59,
                                initialValue: stopwatchProvider.timerDuration.inSeconds % 60,
                                onChanged: (value) {
                                  final current = stopwatchProvider.timerDuration;
                                  stopwatchProvider.setTimerDuration(Duration(hours: current.inHours, minutes: current.inMinutes % 60, seconds: value));
                                },
                                textStyle: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal),
                                itemExtent: 60.0,
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          stopwatchProvider.result,
                          style: const TextStyle(fontSize: 48, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.teal),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(width: 16.0),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => stopwatchProvider.toggleMode(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !stopwatchProvider.isTimerMode ? Colors.teal : Colors.grey[300],
                            foregroundColor: !stopwatchProvider.isTimerMode ? Colors.white : Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('CRONÔMETRO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8.0),
                        ElevatedButton(
                          onPressed: () => stopwatchProvider.toggleMode(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: stopwatchProvider.isTimerMode ? Colors.teal : Colors.grey[300],
                            foregroundColor: stopwatchProvider.isTimerMode ? Colors.white : Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('TIMER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16.0),
                  ],
                ),
                const SizedBox(height: 24.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 64.0,
                      icon: const Icon(Icons.auto_awesome),
                      color: Colors.teal,
                      onPressed: _handleGetRecommendation,
                      tooltip: 'Sugerir Próximo Estudo',
                    ),
                    const SizedBox(width: 24.0),
                    IconButton(
                      iconSize: 64.0,
                      icon: Icon(stopwatchProvider.isRunning ? Icons.pause_circle_filled : Icons.play_circle_filled),
                      color: Colors.teal,
                      onPressed: stopwatchProvider.isRunning ? stopwatchProvider.stop : stopwatchProvider.start,
                    ),
                    const SizedBox(width: 24.0),
                    if (stopwatchProvider.stopwatch.elapsed.inMilliseconds > 0)
                      IconButton(
                        iconSize: 64.0,
                        icon: const Icon(Icons.refresh),
                        color: Colors.teal,
                        onPressed: stopwatchProvider.reset,
                      ),
                    const SizedBox(width: 24.0),
                    IconButton(
                      iconSize: 64.0,
                      icon: const Icon(Icons.save),
                      color: Colors.teal,
                      onPressed: () {
                        if (stopwatchProvider.selectedSubjectId == null || stopwatchProvider.selectedTopic == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor, selecione uma matéria e um tópico.')),
                          );
                          return;
                        }
                        Navigator.of(context).pop({
                          'time': stopwatchProvider.getElapsedMilliseconds(),
                          'subjectId': stopwatchProvider.selectedSubjectId,
                          'topic': stopwatchProvider.selectedTopic,
                        });
                        stopwatchProvider.reset();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  String _formatProgressText(int currentMs, int initialTargetMs) {
    if (currentMs < 0) currentMs = 0;
    final currentMinutes = (currentMs / (1000 * 60)).floor();
    final currentHours = (currentMinutes ~/ 60).toString().padLeft(2, '0');
    final remainingMinutes = (currentMinutes % 60).toString().padLeft(2, '0');

    final targetMinutes = (initialTargetMs / (1000 * 60)).floor();
    final targetHours = (targetMinutes ~/ 60).toString().padLeft(2, '0');
    final targetMins = (targetMinutes % 60).toString().padLeft(2, '0');

    return '${currentHours}h${remainingMinutes} / ${targetHours}h${targetMins}';
  }
}

class BarberPolePainter extends CustomPainter {
  final double animationValue;
  final bool isRunning;

  BarberPolePainter({required this.animationValue, required this.isRunning});

  @override
  void paint(Canvas canvas, Size size) {
    final List<Color> colors = [
      Colors.teal.shade200,
      Colors.teal.shade300,
      Colors.teal.shade100,
    ];
    final double singleStripeWidth = 20.0;
    final double totalPatternWidth = singleStripeWidth * colors.length;
    final double diagonalLength = size.height + size.width;
    final double offset = isRunning ? animationValue * totalPatternWidth : 0;

    for (int colorIndex = 0; colorIndex < colors.length; colorIndex++) {
      final Paint paint = Paint()
        ..color = colors[colorIndex]
        ..style = PaintingStyle.fill;

      for (double i = -diagonalLength; i < diagonalLength; i += totalPatternWidth) {
        final double startX = i + (singleStripeWidth * colorIndex) + offset;
        final double endX = startX + singleStripeWidth;

        canvas.drawPath(
          Path()
            ..moveTo(startX, 0)
            ..lineTo(endX, 0)
            ..lineTo(endX + size.height / 2, size.height)
            ..lineTo(startX + size.height / 2, size.height)
            ..close(),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BarberPolePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isRunning != isRunning;
  }
}
