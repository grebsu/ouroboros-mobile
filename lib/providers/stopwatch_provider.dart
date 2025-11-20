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
  Topic? _selectedTopic;
  String? _planId;

  // Getters
  Stopwatch get stopwatch => _stopwatch;
  String get result => _result;
  bool get isTimerMode => _isTimerMode;
  Duration get timerDuration => _timerDuration;
  String? get selectedSubjectId => _selectedSubjectId;
  Topic? get selectedTopic => _selectedTopic;
  String? get planId => _planId;
  bool get isRunning => _stopwatch.isRunning;
  bool get isActive => _stopwatch.elapsedMilliseconds > 0 || isRunning;

  StopwatchProvider() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (Timer t) {
      if (!_stopwatch.isRunning) return;

      if (_isTimerMode) {
        final remaining = _timerDuration - _stopwatch.elapsed;
        if (remaining.isNegative) {
          _stopwatch.stop();
          _result = '00:00:00';
        } else {
          _result = _formatDuration(remaining);
        }
      } else {
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
    Topic? topic,
    int? durationMinutes,
  }) {
    // Only set if the stopwatch is not running to avoid conflicts
    if (!isRunning) {
      _planId = planId;
      _selectedSubjectId = subjectId;
      _selectedTopic = topic;
      if (durationMinutes != null) {
        _timerDuration = Duration(minutes: durationMinutes);
        _isTimerMode = true;
        _result = _formatDuration(_timerDuration);
      } else {
        _isTimerMode = false;
        _result = '00:00:00';
      }
      _stopwatch.reset();
      notifyListeners();
    }
  }

  void setSubject(String? subjectId) {
    _selectedSubjectId = subjectId;
    _selectedTopic = null;
    notifyListeners();
  }

  void setTopic(Topic? topic) {
    _selectedTopic = topic;
    notifyListeners();
  }

  void setTimerDuration(Duration duration) {
    if (!isRunning) {
      _timerDuration = duration;
      _result = _formatDuration(_timerDuration);
      notifyListeners();
    }
  }

  void toggleMode(bool isTimer) {
    if (!isRunning) {
      _isTimerMode = isTimer;
      _stopwatch.reset();
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
    if (_isTimerMode) {
      _result = _formatDuration(_timerDuration);
    } else {
      _result = '00:00:00';
    }
    notifyListeners();
  }

  // Method to be called when saving the session
  int getElapsedMilliseconds() {
    return _stopwatch.elapsed.inMilliseconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
