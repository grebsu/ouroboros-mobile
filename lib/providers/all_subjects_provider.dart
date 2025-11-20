import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:ouroboros_mobile/providers/plans_provider.dart';

class AllSubjectsProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService.instance;
  final AuthProvider? _authProvider;
  final PlansProvider? _plansProvider;

  List<Subject> _subjects = [];
  Map<String, Plan> _plansMap = {};
  List<StudyRecord> _studyRecords = [];
  List<SimuladoRecord> _simuladoRecords = [];
  bool _isLoading = false;
  bool _isDisposed = false;

  List<Subject> get subjects => _subjects;
  List<Subject> get uniqueSubjectsByName {
    final uniqueSubjects = <Subject>[];
    final subjectNames = <String>{};
    for (final subject in _subjects) {
      if (subjectNames.add(subject.subject)) {
        uniqueSubjects.add(subject);
      }
    }
    return uniqueSubjects;
  }

  Future<Subject?> getSubjectByNameAndPlanId(String name, String planId) async {
    try {
      return _subjects.firstWhere((subject) => subject.subject == name && subject.plan_id == planId);
    } catch (e) {
      return null;
    }
  }

  Map<String, Plan> get plansMap => _plansMap;
  bool get isLoading => _isLoading;

  AllSubjectsProvider({AuthProvider? authProvider, PlansProvider? plansProvider})
      : _authProvider = authProvider,
        _plansProvider = plansProvider {
    fetchData();
    _plansProvider?.addListener(_onPlansProviderChanged);
  }

  void _onPlansProviderChanged() {
    print('AllSubjectsProvider: PlansProvider mudou, recarregando dados internos.');
    _internalRefreshData();
    notifyListeners();
  }

  @override
  void dispose() {
    _plansProvider?.removeListener(_onPlansProviderChanged);
    _isDisposed = true;
    super.dispose();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // New private method to refresh data without notifying about loading state
  Future<void> _internalRefreshData() async {
    if (_authProvider?.currentUser == null) return;
    print('AllSubjectsProvider: Iniciando _internalRefreshData...');
    _subjects = await _dbService.readAllSubjects(_authProvider!.currentUser!.name);
    final allPlans = await _dbService.readAllPlans(_authProvider!.currentUser!.name);
    _plansMap = { for (var plan in allPlans) plan.id: plan };

    // Filtrar matérias para incluir apenas aquelas com planos existentes
    _subjects = _subjects.where((subject) => _plansMap.containsKey(subject.plan_id)).toList();
    _studyRecords = await _dbService.readStudyRecordsForUser(_authProvider!.currentUser!.name);
    _simuladoRecords = [];
    for (final plan in allPlans) {
      _simuladoRecords.addAll(await _dbService.readSimuladoRecordsForPlan(plan.id, _authProvider!.currentUser!.name));
    }
    print('AllSubjectsProvider: _internalRefreshData concluído.');
  }

  Future<void> fetchData() async {
    if (_authProvider?.currentUser == null) return;
    print('AllSubjectsProvider: Iniciando fetchData...');
    _setLoading(true);
    await _internalRefreshData();
    _setLoading(false);
    print('AllSubjectsProvider: fetchData concluído.');
  }

  String getStudyHoursForSubject(String subjectId) {
    final totalMilliseconds = _studyRecords
        .where((record) => record.subject_id == subjectId)
        .fold<int>(0, (sum, record) => sum + record.study_time);
    final totalMinutes = totalMilliseconds / 60000;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.floor()}h ${minutes.round()}m';
  }

  int getQuestionsForSubject(String subjectId) {
    final studyQuestions = _studyRecords
        .where((record) => record.subject_id == subjectId)
        .fold<int>(0, (sum, record) => sum + (record.questions['total'] ?? 0));
    final simuladoQuestions = _simuladoRecords
        .expand((record) => record.subjects)
        .where((subject) => subject.subject_id == subjectId)
        .fold<int>(0, (sum, subject) => sum + subject.total_questions);
    return studyQuestions + simuladoQuestions;
  }

  double getPerformanceForSubject(String subjectId) {
    int totalCorrect = 0;
    int totalQuestions = 0;

    for (final record in _studyRecords) {
      if (record.subject_id == subjectId) {
        totalCorrect += record.questions['correct'] ?? 0;
        totalQuestions += record.questions['total'] ?? 0;
      }
    }

    for (final record in _simuladoRecords) {
      for (final subject in record.subjects) {
        if (subject.subject_id == subjectId) {
          totalCorrect += subject.correct;
          totalQuestions += subject.total_questions;
        }
      }
    }

    if (totalQuestions == 0) {
      return 0.0;
    }

    final percentage = (totalCorrect / totalQuestions) * 100;
    return percentage;
  }

  String getTotalStudyHours() {
    final totalMilliseconds = _studyRecords.fold<int>(0, (sum, record) => sum + record.study_time);
    final totalMinutes = totalMilliseconds / 60000;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.floor()}h ${minutes.round()}m';
  }

  int getTotalQuestions() {
    final studyQuestions = _studyRecords.fold<int>(0, (sum, record) => sum + (record.questions['total'] ?? 0));
    final simuladoQuestions = _simuladoRecords
        .expand((record) => record.subjects)
        .fold<int>(0, (sum, subject) => sum + subject.total_questions);
    return studyQuestions + simuladoQuestions;
  }

  double getOverallPerformance() {
    int totalCorrect = 0;
    int totalQuestions = 0;

    for (final record in _studyRecords) {
      totalCorrect += record.questions['correct'] ?? 0;
      totalQuestions += record.questions['total'] ?? 0;
    }

    for (final record in _simuladoRecords) {
      for (final subject in record.subjects) {
        totalCorrect += subject.correct;
        totalQuestions += subject.total_questions;
      }
    }

    if (totalQuestions == 0) {
      return 0.0;
    }

    return (totalCorrect / totalQuestions) * 100;
  }

  Future<void> addSubject(Subject subject) async {
    if (_authProvider?.currentUser == null) return;
    await _dbService.createSubject(subject, _authProvider!.currentUser!.name);
    await fetchData(); // Keep full fetch here to update UI correctly
  }

  Future<void> updateSubject(Subject subject) async {
    if (_authProvider?.currentUser == null) return;
    await _dbService.updateSubject(subject, _authProvider!.currentUser!.name);
    await fetchData();
  }

  Future<void> updateTopicWeights(Map<int, int> weights) async {
    await _dbService.updateTopicWeights(weights);
    await fetchData();
  }

  Future<void> calculateAndApplyTopicWeights(List<String> selectedSubjectIds) async {
    try {
      final selectedSubjects = _subjects.where((s) => selectedSubjectIds.contains(s.id)).toList();

      // Helper to extract all leaf topics recursively from a list of subjects
      List<Topic> _extractAllLeafTopics(List<Subject> subjects) {
        List<Topic> leafTopics = [];
        void extract(List<Topic> topics) {
          for (var topic in topics) {
            if (topic.sub_topics == null || topic.sub_topics!.isEmpty) {
              leafTopics.add(topic);
              print('Extracted leaf topic: ${topic.topic_text}, Questions: ${topic.question_count}');
            } else {
              extract(topic.sub_topics!);
            }
          }
        }
        for (var subject in subjects) {
          extract(subject.topics);
        }
        return leafTopics;
      }

      final guideSubjects = selectedSubjects.where((s) => s.import_source == 'tec_concursos').toList();
      final manualSubjects = selectedSubjects.where((s) => s.import_source != 'tec_concursos').toList();

      // Helper function to calculate and normalize weights for a given set of topics
      Map<int, int> _calculateAndNormalizeWeights(List<Topic> topics) {
        final weights = <int, int>{};
        if (topics.isEmpty) {
          print('calculateAndNormalizeWeights: No topics to process.');
          return weights;
        }

        print('calculateAndNormalizeWeights: Processing ${topics.length} topics.');
        
        final topicsWithQuestions = topics.where((t) => t.question_count != null && t.question_count! > 0).toList();
        final topicsWithoutQuestions = topics.where((t) => t.question_count == null || t.question_count == 0).toList();

        // Assign default weight of 1 for topics without questions
        for (var topic in topicsWithoutQuestions) {
          if (topic.id != null) {
            weights[topic.id!] = 1;
            print('  Assigned default weight 1 to topic ${topic.topic_text} (no questions).');
          }
        }

        if (topicsWithQuestions.isNotEmpty) {
          // Use log transformation to handle skewed data distribution
          final List<double> logCounts = topicsWithQuestions.map((t) => log(t.question_count!)).toList();
          final double minLog = logCounts.reduce((a, b) => a < b ? a : b);
          final double maxLog = logCounts.reduce((a, b) => a > b ? a : b);

          print('  Min Log Questions: $minLog, Max Log Questions: $maxLog');

          if (minLog == maxLog) {
            // All topics have the same number of questions, assign a middle weight
            for (final topic in topicsWithQuestions) {
              if (topic.id != null) {
                weights[topic.id!] = 3;
                print('  Topic: ${topic.topic_text}, Questions: ${topic.question_count}, Calculated Weight: 3 (all equal).');
              }
            }
          } else {
            final double logRange = maxLog - minLog;
            for (final topic in topicsWithQuestions) {
              if (topic.id != null) {
                final double logCount = log(topic.question_count!);
                final double normalizedValue = (logCount - minLog) / logRange;
                final int weight = (1 + (normalizedValue * 4)).round().clamp(1, 5);
                weights[topic.id!] = weight;
                print('  Topic: ${topic.topic_text}, Questions: ${topic.question_count}, Log: $logCount, Normalized: $normalizedValue, Calculated Weight: $weight');
              }
            }
          }
        } else {
          print('  No topics with questions in this group.');
        }
        return weights;
      }

      // Calculate weights for each group independently
      final guideTopics = _extractAllLeafTopics(guideSubjects);
      final manualTopics = _extractAllLeafTopics(manualSubjects);

      final guideWeights = _calculateAndNormalizeWeights(guideTopics);
      final manualWeights = _calculateAndNormalizeWeights(manualTopics);

      // Combine the results
      final Map<int, int> finalWeights = {}
        ..addAll(guideWeights)
        ..addAll(manualWeights);

      // Save to the database
      if (finalWeights.isNotEmpty) {
        await _dbService.updateTopicWeights(finalWeights);
        await _internalRefreshData();
        notifyListeners();
      }
    } catch (e) {
      print('Erro ao calcular pesos: $e');
      rethrow;
    }
  }
}