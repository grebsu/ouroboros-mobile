import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

class StopwatchProvider with ChangeNotifier {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _result = '00:00:00';
  bool _isTimerMode = false;
  Duration _timerDuration = const Duration();
  String? _selectedSubjectId;
  List<TopicWithTime> _recommendedTopics = const [];
  int _currentTopicIndex = 0;
  Duration _currentTopicRemainingTime = Duration.zero;
  String? _planId;
  Function(String)? onSessionComplete; // Callback para quando a sessão for completa
  bool _automaticTopicProgression = true; // Novo: controla se avança sozinho

  // Novos campos para rastrear tempo total e por tópico
  int _totalElapsedBeforeCurrentTopicMs = 0;
  List<int> _topicsElapsedMs = [];

  // Getters
  Stopwatch get stopwatch => _stopwatch;
  String get result => _result;
  bool get isTimerMode => _isTimerMode;
  Duration get timerDuration => _timerDuration;
  String? get selectedSubjectId => _selectedSubjectId;
  Topic? get selectedTopic => _recommendedTopics.isNotEmpty ? _recommendedTopics[_currentTopicIndex].topic : null;
  String? get planId => _planId;
  bool get isRunning => _stopwatch.isRunning;
  bool get isActive => _stopwatch.elapsedMilliseconds > 0 || isRunning;
  List<TopicWithTime> get recommendedTopics => _recommendedTopics;
  int get currentTopicIndex => _currentTopicIndex;
  Duration get currentTopicRemainingTime => _currentTopicRemainingTime;
  bool get automaticTopicProgression => _automaticTopicProgression;

  // Setter para o avanço automático
  void setAutomaticTopicProgression(bool value) {
    _automaticTopicProgression = value;
    notifyListeners();
  }

  // Getter para o tempo total decorrido
  int get totalElapsedMilliseconds {
    if (!_isTimerMode || _recommendedTopics.isEmpty) {
      return _stopwatch.elapsedMilliseconds;
    }
    return _totalElapsedBeforeCurrentTopicMs + _stopwatch.elapsedMilliseconds;
  }

  // Getter para o tempo decorrido de cada tópico
  List<int> get topicsElapsedMs => _topicsElapsedMs;

  StopwatchProvider() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (Timer t) {
      if (!_stopwatch.isRunning) return;

      if (_isTimerMode) {
        // Logic for timer mode (countdown)
        if (_recommendedTopics.isNotEmpty) {
          // Multi-topic timer mode
          final currentTopicAllocationMs = _recommendedTopics[_currentTopicIndex].allocatedTimeSeconds * 1000;
          final topicElapsed = _stopwatch.elapsedMilliseconds;
          
          // Atualiza o tempo do tópico atual na lista
          if (_topicsElapsedMs.length > _currentTopicIndex) {
            _topicsElapsedMs[_currentTopicIndex] = topicElapsed;
          }

          if (topicElapsed >= currentTopicAllocationMs) {
            // Garante que o tempo do tópico atual seja exatamente a alocação ao finalizar o tempo dele
            if (_topicsElapsedMs.length > _currentTopicIndex) {
              _topicsElapsedMs[_currentTopicIndex] = currentTopicAllocationMs;
            }
            _totalElapsedBeforeCurrentTopicMs += currentTopicAllocationMs;

            // Move to next topic or end session
            _stopwatch.stop(); // Stop to reset for next topic
            _stopwatch.reset();
            if (_currentTopicIndex < _recommendedTopics.length - 1) {
              _currentTopicIndex++;
              if (_automaticTopicProgression) {
                _stopwatch.start(); // Só inicia se o avanço automático estiver ligado
              }
            } else {
              // All topics completed
              _result = '00:00:00';
              _currentTopicRemainingTime = Duration.zero;
              notifyListeners();
              onSessionComplete?.call(_planId!); // Notify session completion
              return;
            }
          }
          _currentTopicRemainingTime = Duration(milliseconds: (currentTopicAllocationMs - topicElapsed).clamp(0, currentTopicAllocationMs));
          _result = _formatDuration(_currentTopicRemainingTime);

        } else {
          // Single topic timer mode (old behavior)
          final remaining = _timerDuration - _stopwatch.elapsed;
          if (remaining.isNegative) {
            _stopwatch.stop();
            _result = '00:00:00';
            onSessionComplete?.call(_planId!); // Notify session completion
          } else {
            _result = _formatDuration(remaining);
          }
        }
      } else {
        // Logic for stopwatch mode (count-up)
        _result = _formatDuration(_stopwatch.elapsed);
      }
      notifyListeners();
    });
  }

  String _formatDuration(Duration duration) {
    return '${duration.inHours.toString().padLeft(2, '0')}:'
        '${(duration.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void setContext({
    required String planId,
    String? subjectId,
    List<TopicWithTime> recommendedTopics = const [],
    Function(String)? onSessionCompleteCallback,
  }) {
    if (!isRunning) {
      _planId = planId;
      _selectedSubjectId = subjectId;
      _recommendedTopics = recommendedTopics;
      _currentTopicIndex = 0;
      onSessionComplete = onSessionCompleteCallback;
      
      _totalElapsedBeforeCurrentTopicMs = 0;
      _topicsElapsedMs = List.filled(_recommendedTopics.length, 0);

      if (_recommendedTopics.isNotEmpty) {
        _isTimerMode = true;
        // Calculate total duration for all topics
        _timerDuration = Duration(seconds: _recommendedTopics.fold(0, (sum, topicWithTime) => sum + topicWithTime.allocatedTimeSeconds));
        _currentTopicRemainingTime = Duration(seconds: _recommendedTopics[_currentTopicIndex].allocatedTimeSeconds);
        _result = _formatDuration(_currentTopicRemainingTime); // Show first topic's duration
      } else {
        _isTimerMode = false;
        _timerDuration = Duration.zero;
        _currentTopicRemainingTime = Duration.zero;
        _result = '00:00:00';
      }
      _stopwatch.reset();
      notifyListeners();
    }
  }

  void setSubject(String? subjectId) {
    _selectedSubjectId = subjectId;
    // _selectedTopic is now managed by _recommendedTopics
    notifyListeners();
  }

  void setManualTopics(List<Topic> topics) {
    if (!isRunning) {
      final int totalSeconds = _timerDuration.inSeconds > 0 ? _timerDuration.inSeconds : (topics.length * 30 * 60);
      
      int accumulated = 0;
      _recommendedTopics = List.generate(topics.length, (i) {
        int alloc;
        if (i == topics.length - 1) {
          alloc = totalSeconds - accumulated;
        } else {
          alloc = (totalSeconds / topics.length).floor();
          if (alloc < 1) alloc = 1;
        }
        accumulated += alloc;
        
        return TopicWithTime(
          topic: topics[i],
          allocatedTimeSeconds: alloc,
          justification: 'Seleção manual',
        );
      });
      
      // Update total duration to match the sum (especially if it was zero or had rounding)
      _timerDuration = Duration(seconds: accumulated);

      _currentTopicIndex = 0;
      _totalElapsedBeforeCurrentTopicMs = 0;
      _topicsElapsedMs = List.filled(_recommendedTopics.length, 0);

      if (_recommendedTopics.isNotEmpty) {
        _currentTopicRemainingTime = Duration(seconds: _recommendedTopics[_currentTopicIndex].allocatedTimeSeconds);
        if (_isTimerMode) {
          _result = _formatDuration(_currentTopicRemainingTime);
        }
      }
      notifyListeners();
    }
  }

  void updateTopicAllocations(List<int> newAllocationsSeconds) {
    if (!isRunning && newAllocationsSeconds.length == _recommendedTopics.length) {
      for (int i = 0; i < _recommendedTopics.length; i++) {
        _recommendedTopics[i] = TopicWithTime(
          topic: _recommendedTopics[i].topic,
          allocatedTimeSeconds: newAllocationsSeconds[i],
          justification: _recommendedTopics[i].justification,
        );
      }
      
      // Update total duration to match the sum of allocations
      _timerDuration = Duration(seconds: newAllocationsSeconds.fold(0, (sum, val) => sum + val));
      _topicsElapsedMs = List.filled(_recommendedTopics.length, 0);
      _totalElapsedBeforeCurrentTopicMs = 0;
      
      // Update current topic's remaining time
      if (_recommendedTopics.isNotEmpty) {
        _currentTopicRemainingTime = Duration(seconds: _recommendedTopics[_currentTopicIndex].allocatedTimeSeconds);
        if (_isTimerMode) {
          _result = _formatDuration(_currentTopicRemainingTime);
        }
      }
      notifyListeners();
    }
  }

  void setTimerDuration(Duration duration) {
    if (!isRunning) {
      final int oldTotalSeconds = _timerDuration.inSeconds;
      _timerDuration = duration;
      
      if (_recommendedTopics.isNotEmpty && oldTotalSeconds > 0) {
        final double scaleFactor = _timerDuration.inSeconds / oldTotalSeconds;
        int accumulatedSeconds = 0;
        
        for (int i = 0; i < _recommendedTopics.length; i++) {
          int newAlloc;
          if (i == _recommendedTopics.length - 1) {
            // Last topic gets the remainder to avoid rounding errors
            newAlloc = _timerDuration.inSeconds - accumulatedSeconds;
          } else {
            newAlloc = (_recommendedTopics[i].allocatedTimeSeconds * scaleFactor).round();
            if (newAlloc < 1) newAlloc = 1;
          }
          accumulatedSeconds += newAlloc;
          
          _recommendedTopics[i] = TopicWithTime(
            topic: _recommendedTopics[i].topic,
            allocatedTimeSeconds: newAlloc,
            justification: _recommendedTopics[i].justification,
          );
        }
        
        // Ensure the last topic doesn't end up with negative or zero time
        if (_recommendedTopics.last.allocatedTimeSeconds < 1) {
           _recommendedTopics[_recommendedTopics.length - 1] = TopicWithTime(
             topic: _recommendedTopics.last.topic,
             allocatedTimeSeconds: 1,
             justification: _recommendedTopics.last.justification,
           );
        }

        _currentTopicRemainingTime = Duration(seconds: _recommendedTopics[_currentTopicIndex].allocatedTimeSeconds);
      }
      
      _topicsElapsedMs = List.filled(_recommendedTopics.length, 0);
      _totalElapsedBeforeCurrentTopicMs = 0;

      if (_isTimerMode) {
        _result = _formatDuration(_recommendedTopics.isNotEmpty 
            ? _currentTopicRemainingTime 
            : _timerDuration);
      }
      notifyListeners();
    }
  }

  void toggleMode(bool isTimer) {
    if (!isRunning) {
      _isTimerMode = isTimer;
      _stopwatch.reset();
      _totalElapsedBeforeCurrentTopicMs = 0;
      _topicsElapsedMs = List.filled(_recommendedTopics.length, 0);

      if (_isTimerMode) {
        _result = _formatDuration(_timerDuration);
      } else {
        _result = '00:00:00';
      }
      notifyListeners();
    }
  }

  void start() {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
      notifyListeners();
    }
  }

  void stop() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      notifyListeners();
    }
  }

  void reset() {
    _stopwatch.stop();
    _stopwatch.reset();
    _recommendedTopics = const [];
    _currentTopicIndex = 0;
    _currentTopicRemainingTime = Duration.zero;
    _totalElapsedBeforeCurrentTopicMs = 0;
    _topicsElapsedMs = [];

    if (_isTimerMode) {
      _result = _formatDuration(_timerDuration);
    } else {
      _result = '00:00:00';
    }
    notifyListeners();
  }

  // Method to be called when saving the session
  int getElapsedMilliseconds() {
    return totalElapsedMilliseconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
