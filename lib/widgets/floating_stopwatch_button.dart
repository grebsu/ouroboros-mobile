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
  State<FloatingStopwatchButton> createState() =>
      _FloatingStopwatchButtonState();
}

class _FloatingStopwatchButtonState extends State<FloatingStopwatchButton>
    with TickerProviderStateMixin {
  Offset? _position;
  AnimationController? _floatAnimationController;
  Animation<Offset>? _floatAnimation;

  // Constantes para os tamanhos do botão
  static const double _buttonSize = 56.0;
  static const double _margin = 16.0;

  // Controle de animação de inércia
  AnimationController? _inertiaController;
  Offset _dragVelocity = Offset.zero;
  Offset _lastDragPosition = Offset.zero;
  DateTime? _lastDragTime;
  bool _isDragging = false;

  // Posição alvo para animação de snap
  Offset? _targetPosition;

  // Controller para animação de bounce
  AnimationController? _bounceController;
  Offset _bounceOffset = Offset.zero;

  void _handleStudyRecordSave(StudyRecord record) {
    Provider.of<HistoryProvider>(context, listen: false).addStudyRecord(record);
    Provider.of<PlanningProvider>(
      context,
      listen: false,
    ).updateProgress(record);
  }

  @override
  void initState() {
    super.initState();
    _floatAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -10),
    ).animate(CurvedAnimation(
      parent: _floatAnimationController!,
      curve: Curves.easeInOut,
    ));

    _inertiaController = AnimationController(vsync: this);
    _bounceController = AnimationController(vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePositionAfterBuild();
    });
  }

  void _updatePositionAfterBuild() {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    final maxX = screenSize.width - _buttonSize - _margin;
    final maxY = screenSize.height - _buttonSize - safeAreaBottom - _margin;

    setState(() {
      _position = Offset(maxX, maxY - 80.0);
    });
  }

  Rect _getBounds() {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Rect.fromLTRB(
      _margin,
      safeAreaTop + _margin,
      screenSize.width - _buttonSize - _margin,
      screenSize.height - _buttonSize - safeAreaBottom - _margin,
    );
  }

  Offset _clampToBounds(Offset position) {
    final bounds = _getBounds();
    return Offset(
      position.dx.clamp(bounds.left, bounds.right),
      position.dy.clamp(bounds.top, bounds.bottom),
    );
  }

  Offset _snapToEdge(Offset position) {
    final bounds = _getBounds();
    final center = (bounds.left + bounds.right) / 2;

    final newX = position.dx + _buttonSize / 2 < center
        ? bounds.left
        : bounds.right;

    return Offset(newX, position.dy.clamp(bounds.top, bounds.bottom));
  }

  void _startInertia(Offset velocity) {
    if (!mounted || _position == null) return;

    _inertiaController?.stop();
    _bounceController?.stop();

    final bounds = _getBounds();
    final startPosition = _position!;

    // Calcular posição final com física mais realista
    const double friction = 0.92;
    const double steps = 60.0;

    Offset currentPos = startPosition;
    Offset currentVel = velocity;
    double maxTime = 0.6; // 600ms de inércia

    // Simular trajetória
    for (int i = 0; i < steps; i++) {
      currentVel = Offset(currentVel.dx * friction, currentVel.dy * friction);
      currentPos = Offset(currentPos.dx + currentVel.dx * (maxTime / steps),
          currentPos.dy + currentVel.dy * (maxTime / steps));
    }

    // Aplicar snap na borda
    final targetPosition = _snapToEdge(_clampToBounds(currentPos));

    // Criar animação de inércia + snap
    _inertiaController!.duration = const Duration(milliseconds: 500);

    // Usar CurvedAnimation para desaceleração suave
    final curve = CurvedAnimation(
      parent: _inertiaController!,
      curve: Curves.easeOutCubic,
    );

    final animation = Tween<Offset>(
      begin: startPosition,
      end: targetPosition,
    ).animate(curve);

    animation.addListener(() {
      if (mounted && !_isDragging) {
        setState(() {
          _position = animation.value;
        });
      }
    });

    _inertiaController!.forward(from: 0);
  }

  void _startBounceAnimation(Offset overreach) {
    if (!mounted) return;

    _bounceController?.stop();
    _bounceController!.duration = const Duration(milliseconds: 300);

    final startOffset = _bounceOffset;
    final endOffset = Offset.zero;

    final animation = Tween<Offset>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(
      parent: _bounceController!,
      curve: Curves.elasticOut,
    ));

    animation.addListener(() {
      if (mounted) {
        setState(() {
          _bounceOffset = animation.value;
        });
      }
    });

    _bounceController!.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant FloatingStopwatchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _position != null) {
        setState(() {
          _position = _clampToBounds(_position!);
        });
      }
    });
  }

  @override
  void dispose() {
    _floatAnimationController?.dispose();
    _inertiaController?.dispose();
    _bounceController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_position == null) {
      return const SizedBox.shrink();
    }

    return Consumer<StopwatchProvider>(
      builder: (context, stopwatchProvider, child) {
        return Positioned(
          left: _position!.dx + _bounceOffset.dx,
          top: _position!.dy + _bounceOffset.dy,
          child: AnimatedBuilder(
            animation: _floatAnimation!,
            builder: (context, child) {
              return Transform.translate(
                offset: _floatAnimation!.value,
                child: GestureDetector(
                  onTap: () async {
                    final activePlanProvider = Provider.of<ActivePlanProvider>(context, listen: false);
                    final planId = activePlanProvider.activePlan?.id;

                    if (planId != null) {
                      if (!stopwatchProvider.isActive) {
                        stopwatchProvider.setContext(planId: planId);
                      }

                      final result = await showDialog<Map<String, dynamic>?>(
                        context: context,
                        builder: (context) => const StopwatchModal(),
                      );

                      if (result != null && mounted) {
                        final int time = result['time'] as int;
                        final String? subjectId = result['subjectId'] as String?;
                        final Topic? topic = result['topic'] as Topic?;

                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        final initialRecord = StudyRecord(
                          id: const Uuid().v4(),
                          userId: authProvider.currentUser!.name,
                          plan_id: activePlanProvider.activePlan!.id,
                          date: DateTime.now().toIso8601String(),
                          subject_id: subjectId!,
                          topicsProgress: topic != null
                              ? [
                            TopicProgress(
                              topicId: topic.id.toString(),
                              topicText: topic.topic_text,
                            ),
                          ]
                              : [],
                          study_time: time,
                          category: 'teoria',
                          review_periods: [],
                          count_in_planning: true,
                          lastModified: DateTime.now().millisecondsSinceEpoch,
                        );

                        if (mounted) {
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
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Nenhum plano de estudo ativo selecionado.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  onPanStart: (details) {
                    _isDragging = true;
                    _inertiaController?.stop();
                    _bounceController?.stop();
                    _lastDragPosition = details.localPosition;
                    _lastDragTime = DateTime.now();
                    _dragVelocity = Offset.zero;
                  },
                  onPanUpdate: (details) {
                    final now = DateTime.now();
                    final deltaTime = now.difference(_lastDragTime!).inMilliseconds / 1000.0;

                    if (deltaTime > 0 && deltaTime < 0.1) {
                      _dragVelocity = details.delta / deltaTime;
                    }

                    final newPosition = Offset(
                      _position!.dx + details.delta.dx,
                      _position!.dy + details.delta.dy,
                    );

                    final bounds = _getBounds();
                    final clampedPosition = _clampToBounds(newPosition);

                    // Calcular overreach para bounce
                    final overreachX = newPosition.dx - clampedPosition.dx;
                    final overreachY = newPosition.dy - clampedPosition.dy;

                    if ((overreachX.abs() > 0 || overreachY.abs() > 0) &&
                        (overreachX.abs() < 50 && overreachY.abs() < 50)) {
                      _startBounceAnimation(Offset(overreachX * 0.5, overreachY * 0.5));
                    }

                    setState(() {
                      _position = clampedPosition;
                    });

                    _lastDragPosition = details.localPosition;
                    _lastDragTime = now;
                  },
                  onPanEnd: (details) {
                    _isDragging = false;

                    // Reset bounce
                    _bounceController?.stop();
                    setState(() {
                      _bounceOffset = Offset.zero;
                    });

                    // Aplicar inércia
                    if (_dragVelocity.distance > 50) {
                      _startInertia(_dragVelocity);
                    } else {
                      // Snap suave para a borda mais próxima
                      final snappedPosition = _snapToEdge(_position!);
                      if (snappedPosition != _position) {
                        _inertiaController?.stop();

                        final animation = Tween<Offset>(
                          begin: _position,
                          end: snappedPosition,
                        ).animate(CurvedAnimation(
                          parent: _inertiaController!,
                          curve: Curves.easeOutCubic,
                        ));

                        animation.addListener(() {
                          if (mounted && !_isDragging) {
                            setState(() {
                              _position = animation.value;
                            });
                          }
                        });

                        _inertiaController!.duration = const Duration(milliseconds: 300);
                        _inertiaController!.forward(from: 0);
                      }
                    }

                    _dragVelocity = Offset.zero;
                  },
                  child: Container(
                    width: _buttonSize,
                    height: _buttonSize,
                    decoration: BoxDecoration(
                      color: stopwatchProvider.isRunning
                          ? Colors.teal.shade700
                          : Colors.teal,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: stopwatchProvider.isRunning
                        ? Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer, color: Colors.white, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            stopwatchProvider.result,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                        : const Icon(
                      Icons.timer,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}