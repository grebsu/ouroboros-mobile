import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/providers/stopwatch_provider.dart';
import 'package:ouroboros_mobile/widgets/stopwatch_modal.dart';
import 'package:ouroboros_mobile/widgets/study_register_modal.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class FloatingStopwatchButton extends StatefulWidget {
  const FloatingStopwatchButton({super.key});

  @override
  State<FloatingStopwatchButton> createState() =>
      _FloatingStopwatchButtonState();
}

class _FloatingStopwatchButtonState extends State<FloatingStopwatchButton>
    with TickerProviderStateMixin {
  static const double _baseButtonSize = 56.0;
  static const double _runningButtonSize = 80.0;
  static const double _margin = 16.0;

  double get _buttonSize =>
      (Provider.of<StopwatchProvider>(context, listen: false).isRunning)
          ? _runningButtonSize
          : _baseButtonSize;

  bool? _lastIsRunning;

  Offset? _position;
  late final AnimationController _floatAnimationController;
  late final Animation<Offset> _floatAnimation;

  late final AnimationController _inertiaController;
  late final AnimationController _bounceController;
  late final AnimationController _moveToCenterController;
  late final AnimationController _fallAndSlideController;

  late Animation<Offset?> _moveToCenterAnimation;
  late Animation<double> _fallAnimation;
  late Animation<double> _slideAnimation;

  Offset _dragVelocity = Offset.zero;
  Offset _bounceOffset = Offset.zero;
  bool _isDragging = false;

  bool _isMovingToCenter = false;
  bool _isModalOpen = false;
  bool _isReturningWithFall = false;
  bool _isSlidingToCorner = false;

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
      begin: Offset.zero,
      end: const Offset(0, -10),
    ).animate(CurvedAnimation(
      parent: _floatAnimationController,
      curve: Curves.easeInOut,
    ));

    _inertiaController = AnimationController(vsync: this);
    _bounceController = AnimationController(vsync: this);
    _moveToCenterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fallAndSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _moveToCenterAnimation = Tween<Offset?>(
      begin: null,
      end: null,
    ).animate(CurvedAnimation(
      parent: _moveToCenterController,
      curve: Curves.easeOutCubic,
    ));

    _fallAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fallAndSlideController,
      curve: Curves.bounceOut,
    ));

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fallAndSlideController,
      curve: Curves.easeOutQuad,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePositionAfterBuild();
    });
  }

  void _updatePositionAfterBuild() {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;
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

    _inertiaController.stop();
    _bounceController.stop();

    final startPosition = _position!;

    const double friction = 0.92;
    const double steps = 60.0;

    Offset currentPos = startPosition;
    Offset currentVel = velocity;
    const double maxTime = 0.6;

    for (int i = 0; i < steps; i++) {
      currentVel = Offset(currentVel.dx * friction, currentVel.dy * friction);
      currentPos = Offset(
        currentPos.dx + currentVel.dx * (maxTime / steps),
        currentPos.dy + currentVel.dy * (maxTime / steps),
      );
    }

    final targetPosition = _snapToEdge(_clampToBounds(currentPos));

    _inertiaController.duration = const Duration(milliseconds: 500);

    final curve = CurvedAnimation(
      parent: _inertiaController,
      curve: Curves.easeOutCubic,
    );

    final animation = Tween<Offset>(
      begin: startPosition,
      end: targetPosition,
    ).animate(curve);

    animation.addListener(() {
      if (mounted && !_isDragging && !_isMovingToCenter &&
          !_isReturningWithFall && !_isModalOpen && !_isSlidingToCorner) {
        setState(() {
          _position = animation.value;
        });
      }
    });

    _inertiaController.forward(from: 0);
  }

  void _startBounceAnimation(Offset overreach) {
    if (!mounted) return;

    _bounceController.stop();
    _bounceController.duration = const Duration(milliseconds: 300);

    final startOffset = _bounceOffset;
    const endOffset = Offset.zero;

    final animation = Tween<Offset>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    animation.addListener(() {
      if (mounted) {
        setState(() {
          _bounceOffset = animation.value;
        });
      }
    });

    _bounceController.forward(from: 0);
  }

  Offset _getCenterPosition() {
    final screenSize = MediaQuery.of(context).size;
    return Offset(
      (screenSize.width - _buttonSize) / 2,
      (screenSize.height - _buttonSize) / 2,
    );
  }

  Offset _getBottomCenterPosition() {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    return Offset(
      (screenSize.width - _buttonSize) / 2,
      screenSize.height - _buttonSize - safeAreaBottom - 20,
    );
  }

  Offset _getCornerPosition() {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    return Offset(
      screenSize.width - _buttonSize - _margin,
      screenSize.height - _buttonSize - safeAreaBottom - 80,
    );
  }

  // CORREÇÃO: Remoção do parâmetro BuildContext context
  Future<void> _openModal() async {
    if (_isMovingToCenter || _isModalOpen || _position == null) return;

    // Salvar referências dos Providers e dados críticos ANTES de qualquer animação ou await
    final activePlanProvider = Provider.of<ActivePlanProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stopwatchProvider = Provider.of<StopwatchProvider>(context, listen: false);

    final currentPlanId = activePlanProvider.activePlan?.id;
    final currentUser = authProvider.currentUser;

    if (currentPlanId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum plano de estudo ativo selecionado.'),
          ),
        );
      }
      return;
    }

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário não autenticado.'),
          ),
        );
      }
      return;
    }

    // Configurar o contexto do stopwatch AGORA
    if (!stopwatchProvider.isActive) {
      stopwatchProvider.setContext(planId: currentPlanId);
    }

    setState(() {
      _isMovingToCenter = true;
    });
    final centerPosition = _getCenterPosition();

    _moveToCenterAnimation = Tween<Offset?>(
      begin: _position,
      end: centerPosition,
    ).animate(CurvedAnimation(
      parent: _moveToCenterController,
      curve: Curves.easeOutCubic,
    ));

    _moveToCenterController.addListener(() {
      if (mounted && _moveToCenterAnimation.value != null) {
        setState(() {
          _position = _moveToCenterAnimation.value;
        });
      }
    });

    await _moveToCenterController.forward();

    if (!mounted) return;

    setState(() {
      _isMovingToCenter = false;
      _isModalOpen = true;
    });

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => _ModalExpansionTransition(
        buttonPosition: centerPosition,
        buttonSize: _buttonSize,
        child: const StopwatchModal(),
      ),
    );

    debugPrint('StopwatchModal result: $result');

    if (!mounted) return;

    setState(() {
      _isModalOpen = false;
      _isReturningWithFall = true;
      _position = centerPosition;
    });

    _fallAndSlideController.reset();

    final bottomCenterPosition = _getBottomCenterPosition();

    _fallAndSlideController.addListener(() {
      if (mounted && _isReturningWithFall && !_isSlidingToCorner) {
        final progress = _fallAnimation.value;
        final currentY = centerPosition.dy +
            (bottomCenterPosition.dy - centerPosition.dy) * progress;
        setState(() {
          _position = Offset(centerPosition.dx, currentY);
        });
      }
    });

    await _fallAndSlideController.forward();

    if (!mounted) return;

    setState(() {
      _isSlidingToCorner = true;
    });

    _fallAndSlideController.reset();
    _fallAndSlideController.duration = const Duration(milliseconds: 400); // Dobro da velocidade para o deslize

    final cornerPosition = _getCornerPosition();

    _fallAndSlideController.addListener(() {
      if (mounted && _isSlidingToCorner) {
        final progress = _slideAnimation.value;
        final currentX = bottomCenterPosition.dx +
            (cornerPosition.dx - bottomCenterPosition.dx) * progress;
        final currentY = bottomCenterPosition.dy +
            (cornerPosition.dy - bottomCenterPosition.dy) * progress;
        setState(() {
          _position = Offset(currentX, currentY);
        });
      }
    });

    await _fallAndSlideController.forward();

    if (!mounted) return;

    setState(() {
      _isReturningWithFall = false;
      _isSlidingToCorner = false;
      _position = cornerPosition;
    });

    _fallAndSlideController.reset();

    // Processar resultado do modal
    if (result != null && mounted) {
      final int time = result['time'] as int;
      final String? subjectId = result['subjectId'] as String?;
      final Topic? topic = result['topic'] as Topic?;
      final List<TopicWithTime>? topicsWithTime = result['topics'] as List<TopicWithTime>?;
      final List<int>? topicsElapsedMs = result['topicsElapsedMs'] as List<int>?;

      final initialRecord = StudyRecord(
        id: const Uuid().v4(),
        userId: currentUser.name,
        plan_id: currentPlanId,
        date: DateTime.now().toIso8601String(),
        subject_id: subjectId!,
        topicsProgress: topicsWithTime != null && topicsWithTime.isNotEmpty
            ? topicsWithTime.asMap().entries.map((entry) {
                final idx = entry.key;
                final t = entry.value;
                // Usa o tempo real do tópico se disponível, senão fallback para o tempo alocado
                final int actualTopicTime = (topicsElapsedMs != null && topicsElapsedMs.length > idx)
                    ? topicsElapsedMs[idx]
                    : (t.allocatedTimeSeconds * 1000);
                
                return TopicProgress(
                  topicId: t.topic.id.toString(),
                  topicText: t.topic.topic_text,
                  userWeight: t.topic.userWeight,
                  studyTime: actualTopicTime,
                );
              }).toList()
            : (topic != null
                ? [
                    TopicProgress(
                      topicId: topic.id.toString(),
                      topicText: topic.topic_text,
                      userWeight: topic.userWeight,
                      studyTime: time, // Se for um tópico só, usa o tempo total
                    ),
                  ]
                : []),
        study_time: time,
        category: 'teoria',
        review_periods: [],
        count_in_planning: true,
        lastModified: DateTime.now().millisecondsSinceEpoch,
      );

      if (mounted) {
        await showModalBottomSheet<void>(
          // CORREÇÃO: Utilizando apenas `context` (herdado da classe State)
          context: context,
          isScrollControlled: true,
          builder: (ctx) => StudyRegisterModal(
            planId: currentPlanId,
            initialRecord: initialRecord,
            onSave: _handleStudyRecordSave,
          ),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant FloatingStopwatchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _position != null && !_isMovingToCenter &&
          !_isReturningWithFall && !_isModalOpen && !_isSlidingToCorner) {
        setState(() {
          _position = _clampToBounds(_position!);
        });
      }
    });
  }

  @override
  void dispose() {
    _floatAnimationController.dispose();
    _inertiaController.dispose();
    _bounceController.dispose();
    _moveToCenterController.dispose();
    _fallAndSlideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_position == null || _isModalOpen) {
      return const SizedBox.shrink();
    }

    return Consumer<StopwatchProvider>(
      builder: (context, stopwatchProvider, child) {
        if (_lastIsRunning != stopwatchProvider.isRunning) {
          final wasRunning = _lastIsRunning;
          _lastIsRunning = stopwatchProvider.isRunning;

          if (wasRunning != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _position = _clampToBounds(_position!);
                });
              }
            });
          }
        }

        final currentPos = _clampToBounds(_position!);
        final isAnimating = !_isDragging && !_isMovingToCenter &&
            !_isReturningWithFall && !_isModalOpen && !_isSlidingToCorner;

        return AnimatedPositioned(
          duration: isAnimating
              ? const Duration(milliseconds: 300)
              : Duration.zero,
          curve: Curves.easeInOut,
          left: currentPos.dx + _bounceOffset.dx,
          top: currentPos.dy + _bounceOffset.dy,
          child: AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: _floatAnimation.value,
                child: GestureDetector(
                  // CORREÇÃO: Passando apenas a referência da função sem o contexto antigo
                  onTap: _openModal,
                  onPanStart: (details) {
                    if (_isMovingToCenter || _isReturningWithFall ||
                        _isSlidingToCorner) {
                      return;
                    }
                    _isDragging = true;
                    _inertiaController.stop();
                    _bounceController.stop();
                    _dragVelocity = Offset.zero;
                  },
                  onPanUpdate: (details) {
                    if (_isMovingToCenter || _isReturningWithFall ||
                        _isSlidingToCorner) {
                      return;
                    }

                    final newPosition = Offset(
                      _position!.dx + details.delta.dx,
                      _position!.dy + details.delta.dy,
                    );

                    final clampedPosition = _clampToBounds(newPosition);
                    final overreachX = newPosition.dx - clampedPosition.dx;
                    final overreachY = newPosition.dy - clampedPosition.dy;

                    if ((overreachX.abs() > 0 || overreachY.abs() > 0) &&
                        (overreachX.abs() < 50 && overreachY.abs() < 50)) {
                      _startBounceAnimation(
                          Offset(overreachX * 0.5, overreachY * 0.5));
                    }

                    setState(() {
                      _position = clampedPosition;
                    });

                    _dragVelocity = details.delta;
                  },
                  onPanEnd: (details) {
                    if (_isMovingToCenter || _isReturningWithFall ||
                        _isSlidingToCorner) {
                      return;
                    }
                    _isDragging = false;

                    _bounceController.stop();
                    setState(() {
                      _bounceOffset = Offset.zero;
                    });

                    if (_dragVelocity.distance > 50) {
                      _startInertia(_dragVelocity);
                    } else {
                      final snappedPosition = _snapToEdge(_position!);
                      if (snappedPosition != _position) {
                        _inertiaController.stop();

                        final animation = Tween<Offset>(
                          begin: _position,
                          end: snappedPosition,
                        ).animate(CurvedAnimation(
                          parent: _inertiaController,
                          curve: Curves.easeOutCubic,
                        ));

                        animation.addListener(() {
                          if (mounted && !_isDragging && !_isMovingToCenter &&
                              !_isReturningWithFall && !_isModalOpen &&
                              !_isSlidingToCorner) {
                            setState(() {
                              _position = animation.value;
                            });
                          }
                        });

                        _inertiaController.duration =
                        const Duration(milliseconds: 300);
                        _inertiaController.forward(from: 0);
                      }
                    }

                    _dragVelocity = Offset.zero;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: _buttonSize,
                    height: _buttonSize,
                    decoration: BoxDecoration(
                      color: stopwatchProvider.isRunning
                          ? Colors.teal.shade700
                          : Colors.teal,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: stopwatchProvider.isRunning
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.timer,
                                        color: Colors.white, size: 28),
                                    const SizedBox(width: 6),
                                    Text(
                                      stopwatchProvider.result,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

class _ModalExpansionTransition extends StatefulWidget {
  final Offset buttonPosition;
  final double buttonSize;
  final Widget child;

  const _ModalExpansionTransition({
    required this.buttonPosition,
    required this.buttonSize,
    required this.child,
  });

  @override
  State<_ModalExpansionTransition> createState() =>
      _ModalExpansionTransitionState();
}

class _ModalExpansionTransitionState
    extends State<_ModalExpansionTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final center = Offset(screenSize.width / 2, screenSize.height / 2);
    final buttonCenter = widget.buttonPosition +
        Offset(widget.buttonSize / 2, widget.buttonSize / 2);
    final translateOffset = buttonCenter - center;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  color: Colors.black
                      .withValues(alpha: 0.6 * _opacityAnimation.value),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: translateOffset * (1 - _scaleAnimation.value),
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
