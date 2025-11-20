import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/widgets/stopwatch_modal.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/providers/stopwatch_provider.dart';
import 'package:ouroboros_mobile/widgets/study_register_modal.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';

class FloatingStopwatchButton extends StatefulWidget {
  const FloatingStopwatchButton({super.key});

  @override
  State<FloatingStopwatchButton> createState() => _FloatingStopwatchButtonState();
}

class _FloatingStopwatchButtonState extends State<FloatingStopwatchButton> with SingleTickerProviderStateMixin {
  Offset? _position;
  AnimationController? _animationController;
  Animation<Offset>? _floatAnimation;

  void _handleStudyRecordSave(StudyRecord record) {
    Provider.of<HistoryProvider>(context, listen: false).addStudyRecord(record);
    Provider.of<PlanningProvider>(context, listen: false).updateProgress(record);
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -10),
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
    // Initialize _position here
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenSize = MediaQuery.of(context).size;
      setState(() {
        _position = Offset(screenSize.width - 120.0, screenSize.height - 160.0);
      });
    });
  }

  @override
  void didUpdateWidget(covariant FloatingStopwatchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculate position if screen size changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenSize = MediaQuery.of(context).size;
      if (_position != null) {
        setState(() {
          _position = Offset(
            _position!.dx.clamp(0.0, screenSize.width - 120.0),
            _position!.dy.clamp(0.0, screenSize.height - 160.0),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: AnimatedBuilder(
        animation: _floatAnimation!,
        builder: (context, child) {
          return Transform.translate(
            offset: _floatAnimation!.value,
            child: Draggable(
              feedback: Consumer<StopwatchProvider>(
                builder: (context, stopwatchProvider, child) {
                  if (stopwatchProvider.isRunning) {
                    return Card(
                      color: Colors.teal.withOpacity(0.8),
                      elevation: 4.0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              stopwatchProvider.result,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return FloatingActionButton(
                      onPressed: () {}, // onPressed is not used for feedback
                      backgroundColor: Colors.teal.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.timer),
                    );
                  }
                },
              ),
              childWhenDragging: Container(),
              onDragEnd: (details) {
                setState(() {
                  double x = details.offset.dx;
                  double y = details.offset.dy;

                  x = x.clamp(0.0, screenSize.width - 80.0);
                  y = y.clamp(0.0, screenSize.height - 160.0);

                  _position = Offset(x, y);
                });
              },
              child: Consumer2<ActivePlanProvider, StopwatchProvider>(
                builder: (context, activePlanProvider, stopwatchProvider, child) {
                  final onPressed = () async { // Marcar como async
                    final planId = activePlanProvider.activePlan?.id;

                    if (planId != null) {
                      if (!stopwatchProvider.isActive) {
                        stopwatchProvider.setContext(planId: planId);
                      }
                      
                      final result = await showDialog<Map<String, dynamic>?>( // Capturar o resultado
                        context: context,
                        builder: (context) => const StopwatchModal(), // Não passa onSaveAndClose
                      );

                      if (result != null) { // Se o usuário salvou
                        final int time = result['time'];
                        final String? subjectId = result['subjectId'];
                        final Topic? topic = result['topic'];

                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final initialRecord = StudyRecord(
                          id: const Uuid().v4(),
                          userId: authProvider.currentUser!.name,
                          plan_id: activePlanProvider.activePlan!.id,
                          date: DateTime.now().toIso8601String(),
                          subject_id: subjectId!,
                          topic: topic?.topic_text ?? '',
                          study_time: time,
                          category: 'teoria',
                          questions: {},
                          review_periods: [],
                          teoria_finalizada: false,
                          count_in_planning: true,
                          pages: [],
                          videos: [],
                        );
                        
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (ctx) => StudyRegisterModal(
                            planId: planId,
                            initialRecord: initialRecord,
                            onSave: _handleStudyRecordSave,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nenhum plano de estudo ativo selecionado.')),
                      );
                    }
                  };

                  if (stopwatchProvider.isRunning) {
                    return Card(
                      color: Colors.teal,
                      elevation: 4.0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      child: InkWell(
                        onTap: onPressed,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                stopwatchProvider.result,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    return FloatingActionButton(
                      onPressed: onPressed,
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.timer),
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
