import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MentoriaProvider with ChangeNotifier {
  // General
  bool _sequentialTopics = false;

  // Multi-Topic Recommendation
  bool _multiTopicRecommendationEnabled = false;
  int _maxTopicsPerSession = 1;
  String _timeAllocationStrategy = 'proportional'; // 'proportional' or 'equal'

  // Automatic Progression
  bool _automaticProgressionToNextSubject = false;

  // Performance
  bool _useHitRate = true;
  bool _prioritizeLessStudiedTime = false;
  bool _prioritizeMoreStudiedTime = false;
  bool _prioritizeMostErrors = false;
  bool _prioritizeLeastQuestions = false;

  // Review
  bool _prioritizePendingReviews = false;
  bool _prioritizeMostReviewed = false;

  // Temporality
  bool _prioritizeRecentlyAdded = false;
  bool _prioritizeNotStudiedInTimeWindow = false;
  int _notStudiedInDays = 7;
  bool _prioritizeNotRecentlyStudied = true;

  // Relevancy
  bool _prioritizeUnfinishedTopics = true;
  bool _prioritizeTopicWeights = false;
  bool _shuffleCycle = true;

  // Pre-configured levels (Workload in hours)
  int _inicianteWorkload = 24;
  int _intermediarioWorkload = 32;
  int _avancadoWorkload = 40;

  // Pre-configured levels (Session Durations in minutes)
  int _inicianteMinSession = 30;
  int _inicianteMaxSession = 50;
  int _intermediarioMinSession = 50;
  int _intermediarioMaxSession = 90;
  int _avancadoMinSession = 90;
  int _avancadoMaxSession = 120;

  // Getters
  bool get sequentialTopics => _sequentialTopics;
  bool get multiTopicRecommendationEnabled => _multiTopicRecommendationEnabled;
  int get maxTopicsPerSession => _maxTopicsPerSession;
  String get timeAllocationStrategy => _timeAllocationStrategy;
  bool get automaticProgressionToNextSubject => _automaticProgressionToNextSubject;
  bool get useHitRate => _useHitRate;
  bool get prioritizeLessStudiedTime => _prioritizeLessStudiedTime;
  bool get prioritizeMoreStudiedTime => _prioritizeMoreStudiedTime;
  bool get prioritizeMostErrors => _prioritizeMostErrors;
  bool get prioritizeLeastQuestions => _prioritizeLeastQuestions;
  bool get prioritizePendingReviews => _prioritizePendingReviews;
  bool get prioritizeMostReviewed => _prioritizeMostReviewed;
  bool get prioritizeRecentlyAdded => _prioritizeRecentlyAdded;
  bool get prioritizeNotStudiedInTimeWindow =>
      _prioritizeNotStudiedInTimeWindow;
  int get notStudiedInDays => _notStudiedInDays;
  bool get prioritizeNotRecentlyStudied => _prioritizeNotRecentlyStudied;
  bool get prioritizeUnfinishedTopics => _prioritizeUnfinishedTopics;
  bool get prioritizeTopicWeights => _prioritizeTopicWeights;
  bool get shuffleCycle => _shuffleCycle;

  int get inicianteWorkload => _inicianteWorkload;
  int get intermediarioWorkload => _intermediarioWorkload;
  int get avancadoWorkload => _avancadoWorkload;

  int get inicianteMinSession => _inicianteMinSession;
  int get inicianteMaxSession => _inicianteMaxSession;
  int get intermediarioMinSession => _intermediarioMinSession;
  int get intermediarioMaxSession => _intermediarioMaxSession;
  int get avancadoMinSession => _avancadoMinSession;
  int get avancadoMaxSession => _avancadoMaxSession;

  MentoriaProvider() {
    _loadPreferences();
  }

  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _sequentialTopics = prefs.getBool('sequentialTopics') ?? false;
    _multiTopicRecommendationEnabled = prefs.getBool('multiTopicRecommendationEnabled') ?? false;
    _maxTopicsPerSession = prefs.getInt('maxTopicsPerSession') ?? 1;
    _timeAllocationStrategy = prefs.getString('timeAllocationStrategy') ?? 'proportional';
    _automaticProgressionToNextSubject = prefs.getBool('automaticProgressionToNextSubject') ?? false;
    _useHitRate = prefs.getBool('useHitRate') ?? false;
    _prioritizeLessStudiedTime =
        prefs.getBool('prioritizeLessStudiedTime') ?? false;
    _prioritizeMoreStudiedTime =
        prefs.getBool('prioritizeMoreStudiedTime') ?? false;
    _prioritizeMostErrors = prefs.getBool('prioritizeMostErrors') ?? false;
    _prioritizeLeastQuestions =
        prefs.getBool('prioritizeLeastQuestions') ?? false;
    _prioritizePendingReviews =
        prefs.getBool('prioritizePendingReviews') ?? false;
    _prioritizeMostReviewed = prefs.getBool('prioritizeMostReviewed') ?? false;
    _prioritizeRecentlyAdded =
        prefs.getBool('prioritizeRecentlyAdded') ?? false;
    _prioritizeNotStudiedInTimeWindow =
        prefs.getBool('prioritizeNotStudiedInTimeWindow') ?? false;
    _notStudiedInDays = prefs.getInt('notStudiedInDays') ?? 7;
    _prioritizeNotRecentlyStudied =
        prefs.getBool('prioritizeNotRecentlyStudied') ?? true;
    _prioritizeUnfinishedTopics =
        prefs.getBool('prioritizeUnfinishedTopics') ?? true;
    _prioritizeTopicWeights = prefs.getBool('prioritizeTopicWeights') ?? false;
    _shuffleCycle = prefs.getBool('shuffleCycle') ?? true;

    _inicianteWorkload = prefs.getInt('inicianteWorkload') ?? 24;
    _intermediarioWorkload = prefs.getInt('intermediarioWorkload') ?? 32;
    _avancadoWorkload = prefs.getInt('avancadoWorkload') ?? 40;

    _inicianteMinSession = prefs.getInt('inicianteMinSession') ?? 30;
    _inicianteMaxSession = prefs.getInt('inicianteMaxSession') ?? 50;
    _intermediarioMinSession = prefs.getInt('intermediarioMinSession') ?? 50;
    _intermediarioMaxSession = prefs.getInt('intermediarioMaxSession') ?? 90;
    _avancadoMinSession = prefs.getInt('avancadoMinSession') ?? 90;
    _avancadoMaxSession = prefs.getInt('avancadoMaxSession') ?? 120;

    notifyListeners();
  }

  // Setters
  void setSequentialTopics(bool value) async {
    _sequentialTopics = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sequentialTopics', value);
    notifyListeners();
  }

  void setMultiTopicRecommendationEnabled(bool value) async {
    _multiTopicRecommendationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('multiTopicRecommendationEnabled', value);
    notifyListeners();
  }

  void setMaxTopicsPerSession(int value) async {
    _maxTopicsPerSession = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('maxTopicsPerSession', value);
    notifyListeners();
  }

  void setTimeAllocationStrategy(String value) async {
    _timeAllocationStrategy = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('timeAllocationStrategy', value);
    notifyListeners();
  }

  void setAutomaticProgressionToNextSubject(bool value) async {
    _automaticProgressionToNextSubject = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('automaticProgressionToNextSubject', value);
    notifyListeners();
  }

  void setUseHitRate(bool value) async {
    _useHitRate = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useHitRate', value);
    notifyListeners();
  }

  void setPrioritizeLessStudiedTime(bool value) async {
    _prioritizeLessStudiedTime = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeLessStudiedTime', value);
    notifyListeners();
  }

  void setPrioritizeMoreStudiedTime(bool value) async {
    _prioritizeMoreStudiedTime = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeMoreStudiedTime', value);
    notifyListeners();
  }

  void setPrioritizeMostErrors(bool value) async {
    _prioritizeMostErrors = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeMostErrors', value);
    notifyListeners();
  }

  void setPrioritizeLeastQuestions(bool value) async {
    _prioritizeLeastQuestions = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeLeastQuestions', value);
    notifyListeners();
  }

  void setPrioritizePendingReviews(bool value) async {
    _prioritizePendingReviews = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizePendingReviews', value);
    notifyListeners();
  }

  void setPrioritizeMostReviewed(bool value) async {
    _prioritizeMostReviewed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeMostReviewed', value);
    notifyListeners();
  }

  void setPrioritizeRecentlyAdded(bool value) async {
    _prioritizeRecentlyAdded = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeRecentlyAdded', value);
    notifyListeners();
  }

  void setPrioritizeNotStudiedInTimeWindow(bool value) async {
    _prioritizeNotStudiedInTimeWindow = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeNotStudiedInTimeWindow', value);
    notifyListeners();
  }

  void setNotStudiedInDays(int value) async {
    _notStudiedInDays = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notStudiedInDays', value);
    notifyListeners();
  }

  void setPrioritizeNotRecentlyStudied(bool value) async {
    _prioritizeNotRecentlyStudied = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeNotRecentlyStudied', value);
    notifyListeners();
  }

  void setPrioritizeUnfinishedTopics(bool value) async {
    _prioritizeUnfinishedTopics = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeUnfinishedTopics', value);
    notifyListeners();
  }

  void setPrioritizeTopicWeights(bool value) async {
    _prioritizeTopicWeights = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prioritizeTopicWeights', value);
    notifyListeners();
  }

  void setShuffleCycle(bool value) async {
    _shuffleCycle = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shuffleCycle', value);
    notifyListeners();
  }

  void setInicianteWorkload(int value) async {
    _inicianteWorkload = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('inicianteWorkload', value);
    notifyListeners();
  }

  void setIntermediarioWorkload(int value) async {
    _intermediarioWorkload = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('intermediarioWorkload', value);
    notifyListeners();
  }

  void setAvancadoWorkload(int value) async {
    _avancadoWorkload = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('avancadoWorkload', value);
    notifyListeners();
  }

  void setInicianteSessionRange(int min, int max) async {
    _inicianteMinSession = min;
    _inicianteMaxSession = max;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('inicianteMinSession', min);
    await prefs.setInt('inicianteMaxSession', max);
    notifyListeners();
  }

  void setIntermediarioSessionRange(int min, int max) async {
    _intermediarioMinSession = min;
    _intermediarioMaxSession = max;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('intermediarioMinSession', min);
    await prefs.setInt('intermediarioMaxSession', max);
    notifyListeners();
  }

  void setAvancadoSessionRange(int min, int max) async {
    _avancadoMinSession = min;
    _avancadoMaxSession = max;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('avancadoMinSession', min);
    await prefs.setInt('avancadoMaxSession', max);
    notifyListeners();
  }
}
