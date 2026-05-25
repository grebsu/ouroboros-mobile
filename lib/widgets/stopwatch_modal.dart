import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/providers/review_provider.dart';
import 'package:ouroboros_mobile/providers/stopwatch_provider.dart';
import 'package:ouroboros_mobile/providers/mentoria_provider.dart';
import 'package:ouroboros_mobile/widgets/number_picker_wheel.dart';
import 'package:ouroboros_mobile/widgets/topic_selection_sheet.dart';
import 'package:collection/collection.dart';

class StopwatchModal extends StatefulWidget {
  const StopwatchModal({super.key});

  @override
  State<StopwatchModal> createState() => _StopwatchModalState();
}

class _StopwatchModalState extends State<StopwatchModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _barberPoleController;
  late Animation<double> _barberPoleAnimation;
  bool _isClosing = false;

  // This method is used to get the next recommended study session.
  // It fetches necessary providers and uses them to determine the next study plan.
  void _handleGetRecommendation() {
    final planningProvider = Provider.of<PlanningProvider>(
      context,
      listen: false,
    );
    final historyProvider = Provider.of<HistoryProvider>(
      context,
      listen: false,
    );
    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(
      context,
      listen: false,
    );
    final stopwatchProvider = Provider.of<StopwatchProvider>(
      context,
      listen: false,
    );
    final mentoriaProvider = Provider.of<MentoriaProvider>(
      context,
      listen: false,
    );

    final recommendation = planningProvider.getRecommendedSession(
      studyRecords: historyProvider.allStudyRecords,
      subjects: allSubjectsProvider.subjects,
      reviewRecords: Provider.of<ReviewProvider>(
        context,
        listen: false,
      ).allReviewRecords,
    );

    final recommendedTopics = recommendation['recommendedTopics'] as List<TopicWithTime>?;
    final nextSession = recommendation['nextSession'] as StudySession?;

    if (nextSession != null && recommendedTopics != null && recommendedTopics.isNotEmpty) {
      stopwatchProvider.setContext(
        planId: stopwatchProvider.planId!,
        subjectId: nextSession.subjectId,
        recommendedTopics: recommendedTopics,
        onSessionCompleteCallback: (planId) {
          if (mentoriaProvider.automaticProgressionToNextSubject) {
            _handleGetRecommendation(); // Automatically get next recommendation
          } else {
            // Show completion message and ask user to manually get next session
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sessão concluída! Clique em Sugerir Próximo Estudo para continuar.'),
              ),
            );
          }
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (recommendation['justification'] as String?) ?? 'Não há mais sessões no ciclo.',
          ),
        ),
      );
    }
  }

  // This method shows a modal bottom sheet for selecting topics.
  // It retrieves topics for the selected subject and allows the user to pick them.
  void _showTopicSelector() async {
    final stopwatchProvider = Provider.of<StopwatchProvider>(
      context,
      listen: false,
    );
    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(
      context,
      listen: false,
    );

    if (stopwatchProvider.selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione uma matéria primeiro.'),
        ),
      );
      return;
    }

    final subject = allSubjectsProvider.subjects.firstWhereOrNull(
      (s) => s.id == stopwatchProvider.selectedSubjectId,
    );

    if (subject == null) return;

    final selectedTopics = await showModalBottomSheet<List<Topic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (BuildContext context, ScrollController scrollController) {
            return TopicSelectionSheet(
              topics: subject.topics,
              scrollController: scrollController,
              onTopicsSelected: (topics) {
                Navigator.of(context).pop(topics);
              },
              initialSelectedTopicIds: stopwatchProvider.recommendedTopics
                  .map((t) => t.topic.id.toString())
                  .toList(),
            );
          },
        );
      },
    );

    if (selectedTopics != null) {
      stopwatchProvider.setManualTopics(selectedTopics);
    }
  }

  @override
  void initState() {
    super.initState();
    _barberPoleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _barberPoleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_barberPoleController);
  }

  @override
  void dispose() {
    _barberPoleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSubjectsProvider = Provider.of<AllSubjectsProvider>(context);
    final stopwatchProvider = Provider.of<StopwatchProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 500;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Container(
        width: isSmallScreen ? screenWidth * 0.9 : 550,
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1F2937)
              : Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra visual de fechamento (drag handle)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1D2938)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: stopwatchProvider.selectedSubjectId,
                          hint: Text(
                            'Matéria',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                          onChanged: (value) {
                            stopwatchProvider.setSubject(value);
                          },
                          items: allSubjectsProvider.subjects.map((
                            subject,
                          ) {
                            return DropdownMenuItem(
                              value: subject.id,
                              child: Text(
                                subject.subject,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                            );
                          }).toList(),
                          dropdownColor:
                              Theme.of(context).brightness ==
                                  Brightness.dark
                              ? Colors.grey[800]
                              : Colors.white,
                          iconEnabledColor: Colors.teal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    flex: 1,
                    child: InkWell(
                      onTap: _showTopicSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1D2938)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                stopwatchProvider.recommendedTopics.isEmpty
                                    ? 'Tópicos'
                                    : stopwatchProvider.recommendedTopics.length == 1
                                        ? stopwatchProvider.recommendedTopics.first.topic.topic_text
                                        : '${stopwatchProvider.recommendedTopics.length} tópicos selecionados',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: stopwatchProvider.recommendedTopics.isEmpty
                                      ? Theme.of(context).hintColor
                                      : Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.teal),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        stopwatchProvider.selectedSubjectId != null
                            ? allSubjectsProvider.subjects
                                      .firstWhereOrNull(
                                        (s) =>
                                            s.id ==
                                            stopwatchProvider.selectedSubjectId,
                                      )
                                      ?.subject ??
                                  'Sessão de Estudo'
                            : 'Sessão de Estudo',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: Theme.of(context).hintColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (stopwatchProvider.recommendedTopics.length > 1) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Avanço Automático',
                        child: InkWell(
                          onTap: () {
                            stopwatchProvider.setAutomaticTopicProgression(
                              !stopwatchProvider.automaticTopicProgression,
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Icon(
                            stopwatchProvider.automaticTopicProgression
                                ? Icons.redo_rounded
                                : Icons.redo_rounded,
                            size: 16,
                            color: stopwatchProvider.automaticTopicProgression
                                ? Colors.teal
                                : Colors.grey.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16.0),

              // Time Displays and Progress Bar Section
              if (stopwatchProvider.recommendedTopics.isNotEmpty ||
                  !stopwatchProvider.isTimerMode ||
                  stopwatchProvider.timerDuration.inMilliseconds > 0)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column( // Tempo Total
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tempo Total',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).hintColor,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              _formatDuration(stopwatchProvider.isTimerMode ? stopwatchProvider.timerDuration : stopwatchProvider.stopwatch.elapsed), // Display total session time
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (stopwatchProvider.isTimerMode && stopwatchProvider.recommendedTopics.isNotEmpty) ...[
                          const SizedBox(height: 12.0),
                          Column( // Tempo Relativo
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tempo Relativo',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).hintColor,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                _formatDuration(stopwatchProvider.currentTopicRemainingTime), // Show current topic time remaining
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 24.0),
                    // Progress Bar section
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final barWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : screenWidth * 0.8;
                          final totalAllocatedSeconds = stopwatchProvider.recommendedTopics.fold<double>(0, (sum, t) => sum + t.allocatedTimeSeconds);

                          return GestureDetector(
                            onHorizontalDragUpdate: (stopwatchProvider.isRunning || stopwatchProvider.recommendedTopics.isEmpty) ? null : (details) {
                              if (stopwatchProvider.recommendedTopics.length < 2) return;

                              final RenderBox box = context.findRenderObject() as RenderBox;
                              final Offset localOffset = box.globalToLocal(details.globalPosition);
                              final double relativeX = localOffset.dx.clamp(0, barWidth);

                              double cumulativeWidth = 0;
                              int boundaryIndex = -1;
                              double minDistance = 30.0;

                              for (int i = 0; i < stopwatchProvider.recommendedTopics.length - 1; i++) {
                                cumulativeWidth += (stopwatchProvider.recommendedTopics[i].allocatedTimeSeconds / totalAllocatedSeconds) * barWidth;
                                double distance = (relativeX - cumulativeWidth).abs();
                                if (distance < minDistance) {
                                  minDistance = distance;
                                  boundaryIndex = i;
                                }
                              }

                              if (boundaryIndex != -1) {
                                final newAllocationsSeconds = List<int>.from(stopwatchProvider.recommendedTopics.map((t) => t.allocatedTimeSeconds));

                                double totalSecondsPair = (newAllocationsSeconds[boundaryIndex] + newAllocationsSeconds[boundaryIndex + 1]).toDouble();

                                double pairStartWidth = 0;
                                for(int j=0; j < boundaryIndex; j++) {
                                  pairStartWidth += (newAllocationsSeconds[j] / totalAllocatedSeconds) * barWidth;
                                }

                                double newBoundaryX = relativeX - pairStartWidth;
                                double totalPairWidth = (totalSecondsPair / totalAllocatedSeconds) * barWidth;

                                double firstTopicRatio = (newBoundaryX / totalPairWidth).clamp(0.01, 0.99); // Min 1% per topic

                                newAllocationsSeconds[boundaryIndex] = (totalSecondsPair * firstTopicRatio).round();
                                newAllocationsSeconds[boundaryIndex + 1] = (totalSecondsPair - newAllocationsSeconds[boundaryIndex]).round();

                                if (newAllocationsSeconds[boundaryIndex] < 1) newAllocationsSeconds[boundaryIndex] = 1;
                                if (newAllocationsSeconds[boundaryIndex + 1] < 1) newAllocationsSeconds[boundaryIndex + 1] = 1;

                                stopwatchProvider.updateTopicAllocations(newAllocationsSeconds);
                              }
                            },
                            child: Container(
                              width: barWidth,
                              height: 12.0, // Reduced height for the bar itself
                              alignment: Alignment.center,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    height: 12.0,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF1F2937)
                                          : Colors.teal.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(6.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    foregroundDecoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6.0),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withOpacity(0.15),
                                          Colors.white.withOpacity(0.0),
                                          Colors.black.withOpacity(0.05),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6.0),
                                      child: Row(
                                        children: stopwatchProvider.recommendedTopics.isNotEmpty
                                          ? stopwatchProvider.recommendedTopics.map((topicWithTime) {
                                            final topicIndex = stopwatchProvider.recommendedTopics.indexOf(topicWithTime);
                                            final isCurrentTopic = topicIndex == stopwatchProvider.currentTopicIndex;
                                            final double flexValue = topicWithTime.allocatedTimeSeconds > 0 ? topicWithTime.allocatedTimeSeconds.toDouble() : 1.0;
                                            final double topicTotalMilliseconds = (flexValue * 1000).toDouble();
                                            final double topicElapsedMilliseconds = isCurrentTopic ? stopwatchProvider.stopwatch.elapsed.inMilliseconds.toDouble() :
                                                (topicIndex < stopwatchProvider.currentTopicIndex ? topicTotalMilliseconds : 0.0);

                                            double progressValue = topicTotalMilliseconds > 0 ? (topicElapsedMilliseconds / topicTotalMilliseconds).clamp(0.0, 1.0) : 0.0;

                                            if (stopwatchProvider.isTimerMode) {
                                              progressValue = (1.0 - progressValue).clamp(0.0, 1.0);
                                            }

                                            final List<Color> bgShades = [
                                              Colors.teal.withOpacity(0.15),
                                              Colors.teal.withOpacity(0.08),
                                              Colors.teal.withOpacity(0.12),
                                            ];
                                            final Color segmentBgColor = bgShades[topicIndex % bgShades.length];

                                            return Expanded(
                                              flex: flexValue.toInt(),
                                              child: ExcludeSemantics(
                                                child: RepaintBoundary(
                                                  child: AnimatedBuilder(
                                                    animation: _barberPoleAnimation,
                                                    builder: (context, child) {
                                                      return CustomPaint(
                                                        painter: SegmentedProgressPainter(
                                                          progress: progressValue.clamp(0.0, 1.0),
                                                          isRunning: stopwatchProvider.isRunning,
                                                          isCurrent: isCurrentTopic,
                                                          bgColor: segmentBgColor,
                                                          animationValue: _barberPoleAnimation.value,
                                                          alignRight: stopwatchProvider.isTimerMode,
                                                        ),
                                                        child: Container(
                                                          constraints: const BoxConstraints.expand(),
                                                          decoration: BoxDecoration(
                                                            // Add right border for separation if not the last segment
                                                            border: topicIndex < stopwatchProvider.recommendedTopics.length - 1
                                                                ? Border(
                                                                    right: Divider.createBorderSide(context, width: 1.0),
                                                                  )
                                                                : null,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList()
                                          : [ // Fallback para cronômetro ou timer sem tópicos
                                              Expanded(
                                                child: AnimatedBuilder(
                                                  animation: _barberPoleAnimation,
                                                  builder: (context, child) {
                                                    double progressValue = 1.0;
                                                    if (stopwatchProvider.isTimerMode && stopwatchProvider.timerDuration.inMilliseconds > 0) {
                                                      progressValue = (1.0 - (stopwatchProvider.stopwatch.elapsedMilliseconds / stopwatchProvider.timerDuration.inMilliseconds)).clamp(0.0, 1.0);
                                                      // Se estiver em modo timer, a barra esvazia conforme o tempo passa (decrescente)
                                                    }

                                                    return CustomPaint(
                                                      painter: SegmentedProgressPainter(
                                                        progress: progressValue,
                                                        isRunning: stopwatchProvider.isRunning,
                                                        isCurrent: true,
                                                        bgColor: Colors.teal.withOpacity(0.1),
                                                        animationValue: _barberPoleAnimation.value,
                                                        alignRight: stopwatchProvider.isTimerMode,
                                                      ),
                                                      child: Container(
                                                        constraints: const BoxConstraints.expand(),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                      ),
                                    ),
                                  ),
                                  // Adição dos cursores triangulares nos divisores
                                  ...() {
                                    if (stopwatchProvider.recommendedTopics.isEmpty) return <Widget>[];
                                    final List<Widget> markers = [];
                                    double currentCumulativeWidth = 0;
                                    final totalAllocatedSeconds = stopwatchProvider.recommendedTopics.fold<double>(0, (sum, t) => sum + t.allocatedTimeSeconds);
                                    
                                    for (int i = 0; i < stopwatchProvider.recommendedTopics.length - 1; i++) {
                                      currentCumulativeWidth += (stopwatchProvider.recommendedTopics[i].allocatedTimeSeconds / totalAllocatedSeconds) * barWidth;
                                      markers.add(
                                        Positioned(
                                          left: currentCumulativeWidth - 8,
                                          top: -12,
                                          child: const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: Colors.teal,
                                            size: 16,
                                          ),
                                        ),
                                      );
                                      markers.add(
                                        Positioned(
                                          left: currentCumulativeWidth - 8,
                                          bottom: -12,
                                          child: const Icon(
                                            Icons.arrow_drop_up_rounded,
                                            color: Colors.teal,
                                            size: 16,
                                          ),
                                        ),
                                      );
                                    }
                                    return markers;
                                  }(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (stopwatchProvider.isTimerMode && !stopwatchProvider.isRunning)
                    // Time Picker for Timer Mode
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
                                stopwatchProvider.setTimerDuration(
                                  Duration(
                                    hours: value,
                                    minutes: current.inMinutes % 60,
                                    seconds: current.inSeconds % 60,
                                  ),
                                );
                              },
                              textStyle: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                              itemExtent: 50.0,
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            ),
                          ),
                          const Text(
                            ':',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Expanded(
                            child: NumberPickerWheel(
                              minValue: 0,
                              maxValue: 59,
                              initialValue: stopwatchProvider.timerDuration.inMinutes % 60,
                              onChanged: (value) {
                                final current = stopwatchProvider.timerDuration;
                                stopwatchProvider.setTimerDuration(
                                  Duration(
                                    hours: current.inHours,
                                    minutes: value,
                                    seconds: current.inSeconds % 60,
                                  ),
                                );
                              },
                              textStyle: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                              itemExtent: 50.0,
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            ),
                          ),
                          const Text(
                            ':',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          Expanded(
                            child: NumberPickerWheel(
                              minValue: 0,
                              maxValue: 59,
                              initialValue: stopwatchProvider.timerDuration.inSeconds % 60,
                              onChanged: (value) {
                                final current = stopwatchProvider.timerDuration;
                                stopwatchProvider.setTimerDuration(
                                  Duration(
                                    hours: current.inHours,
                                    minutes: current.inMinutes % 60,
                                    seconds: value,
                                  ),
                                );
                              },
                              textStyle: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                              itemExtent: 50.0,
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Displayed Time for Stopwatch or Running Timer
                    Expanded(
                      child: Text(
                        stopwatchProvider.result,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 40 : 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
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
                          backgroundColor: !stopwatchProvider.isTimerMode
                              ? Colors.teal
                              : Colors.grey[300],
                          foregroundColor: !stopwatchProvider.isTimerMode
                              ? Colors.white
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('CRONÔMETRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8.0),
                      ElevatedButton(
                        onPressed: () => stopwatchProvider.toggleMode(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: stopwatchProvider.isTimerMode
                              ? Colors.teal
                              : Colors.grey[300],
                          foregroundColor: stopwatchProvider.isTimerMode
                              ? Colors.white
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('TIMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 56.0,
                    icon: const Icon(Icons.auto_awesome),
                    color: Colors.teal,
                    onPressed: _handleGetRecommendation,
                    tooltip: 'Sugerir Próximo Estudo',
                  ),
                  const SizedBox(width: 16.0),
                  IconButton(
                    iconSize: 56.0,
                    icon: Icon(
                      stopwatchProvider.isRunning
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                    ),
                    color: Colors.teal,
                    onPressed: stopwatchProvider.isRunning
                        ? stopwatchProvider.stop // Using stop() for pausing
                        : stopwatchProvider.start, // Using start() for starting
                  ),
                  const SizedBox(width: 16.0),
                  if (stopwatchProvider.stopwatch.elapsed.inMilliseconds > 0 || stopwatchProvider.timerDuration.inMilliseconds > 0) // Show reset only if timer/stopwatch has run
                    IconButton(
                      iconSize: 56.0,
                      icon: const Icon(Icons.refresh),
                      color: Colors.teal,
                      onPressed: stopwatchProvider.reset,
                    ),
                  const SizedBox(width: 16.0),
                  IconButton(
                    iconSize: 56.0,
                    icon: const Icon(Icons.save),
                    color: Colors.teal,
                    onPressed: () {
                      if (stopwatchProvider.selectedSubjectId == null ||
                          stopwatchProvider.selectedTopic == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Por favor, selecione uma matéria e um tópico.',
                            ),
                          ),
                        );
                        return;
                      }
                      if (_isClosing) return;
                      _isClosing = true;

                      final result = {
                        'time': stopwatchProvider.totalElapsedMilliseconds, // Tempo total real acumulado
                        'subjectId': stopwatchProvider.selectedSubjectId,
                        'topic': stopwatchProvider.selectedTopic,
                        'topics': stopwatchProvider.recommendedTopics, // TopicWithTime
                        'topicsElapsedMs': stopwatchProvider.topicsElapsedMs, // Tempos reais por tópico
                      };

                      stopwatchProvider.reset(); // Reset provider immediately
                      Navigator.of(context).pop(result);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The _formatDuration method is defined here, within the _StopwatchModalState class.
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  // This method is not directly used in the current UI but might be useful for progress display.
  String _formatProgressText(int currentMs, int initialTargetMs) {
    if (currentMs < 0) currentMs = 0;

    final currentTotalSeconds = (currentMs / 1000).floor();
    final currentH = (currentTotalSeconds ~/ 3600).toString().padLeft(2, '0');
    final currentM = ((currentTotalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final currentS = (currentTotalSeconds % 60).toString().padLeft(2, '0');

    final targetTotalSeconds = (initialTargetMs / 1000).floor();
    final targetH = (targetTotalSeconds ~/ 3600).toString().padLeft(2, '0');
    final targetM = ((targetTotalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final targetS = (targetTotalSeconds % 60).toString().padLeft(2, '0');

    return '${currentH}:${currentM}:${currentS} / ${targetH}:${targetM}:${targetS}';
  }
}

// Custom painter for the barber pole animation on the progress bar segments.
class BarberPolePainter extends CustomPainter {
  final double animationValue;
  final bool isRunning;
  final Color baseColor;
  final double progress;

  BarberPolePainter({
    required this.animationValue,
    required this.isRunning,
    required this.progress,
    this.baseColor = Colors.teal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final Paint paint = Paint()..style = PaintingStyle.fill;
    final double currentWidth = size.width * progress;
    final Rect rect = Rect.fromLTWH(0, 0, currentWidth, size.height);

    final double stripeWidth = 15.0;
    final double gap = 10.0;
    final double step = stripeWidth + gap;
    final double offset = isRunning ? animationValue * step : 0;

    final List<Color> colors = [
      baseColor.withOpacity(0.8),
      baseColor.withOpacity(0.6),
      baseColor.withOpacity(0.9),
    ];

    canvas.save();
    canvas.clipRect(rect);

    int i = 0;
    for (double x = -step * 2; x < currentWidth + step; x += step) {
      final double currentX = x + offset;
      paint.color = colors[i % colors.length];

      final Path path = Path()
        ..moveTo(currentX, 0)
        ..lineTo(currentX + stripeWidth, 0)
        ..lineTo(currentX + stripeWidth - size.height, size.height)
        ..lineTo(currentX - size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
      i++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BarberPolePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.progress != progress;
  }
}

// Custom painter for individual segments of the segmented progress bar.
class SegmentedProgressPainter extends CustomPainter {
  final double progress;
  final bool isRunning;
  final bool isCurrent;
  final Color bgColor;
  final double animationValue;
  final bool alignRight; // Novo: alinha o preenchimento à direita

  SegmentedProgressPainter({
    required this.progress,
    required this.isRunning,
    required this.isCurrent,
    required this.bgColor,
    required this.animationValue,
    this.alignRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final RRect outerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(2.0),
    );

    // Background of the segment
    paint.color = bgColor;
    canvas.drawRRect(outerRRect, paint);

    if (progress <= 0) return;

    // Progress Part
    final double currentWidth = size.width * progress;
    final double xOffset = alignRight ? (size.width - currentWidth) : 0.0;
    
    final RRect progressRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(xOffset, 0, currentWidth, size.height),
      const Radius.circular(2.0),
    );

    if (isCurrent && isRunning) {
      // Draw Barber Pole for the currently running segment
      final BarberPolePainter barberPainter = BarberPolePainter(
        animationValue: animationValue,
        isRunning: true,
        progress: 1.0, // Barber pole fills the entire progress width
      );

      canvas.save();
      canvas.clipRRect(progressRRect);
      // Se estiver alinhado à direita, precisamos transladar o canvas para o início do preenchimento
      if (alignRight) {
        canvas.translate(xOffset, 0);
      }
      barberPainter.paint(canvas, Size(currentWidth, size.height));
      canvas.restore();
    } else {
      // Solid Teal for completed segments or the current segment when paused.
      paint.color = Colors.teal;
      canvas.drawRRect(progressRRect, paint);

      // If it's the current topic but not running, draw static stripes to indicate it's the one being worked on.
      if (isCurrent && !isRunning) {
        final BarberPolePainter barberPainter = BarberPolePainter(
          animationValue: 0, // Static animation value
          isRunning: false,
          progress: 1.0,
        );
        canvas.save();
        canvas.clipRRect(progressRRect);
        if (alignRight) {
          canvas.translate(xOffset, 0);
        }
        barberPainter.paint(canvas, Size(currentWidth, size.height));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant SegmentedProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.isCurrent != isCurrent ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.alignRight != alignRight;
  }
}
