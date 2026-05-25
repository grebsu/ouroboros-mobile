import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import 'package:ouroboros_mobile/providers/mentoria_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';

class PlanningProvider with ChangeNotifier {
  String? _planId;
  final AuthProvider? _authProvider;
  final MentoriaProvider? mentoriaProvider;
  final HistoryProvider? _historyProvider;

  List<Subject> _subjects = [];
  List<StudySession>? _studyCycle;
  int _completedCycles = 0;
  int _currentProgressMinutes = 0;
  Map<String, int> _sessionProgressMap = {};
  Map<String, int> _extraStudyTimeBySubjectId = {};
  String _studyHours = '0';
  String _weeklyQuestionsGoal = '0';
  Map<String, Map<String, double>> _subjectSettings = {};
  List<String> _studyDays = [];
  String? _currentCycleId;

  PlanningProvider({
    this.mentoriaProvider,
    AuthProvider? authProvider,
    HistoryProvider? historyProvider,
  }) : _authProvider = authProvider,
       _historyProvider = historyProvider;

  // Getters
  List<Subject> get subjects => _subjects;
  List<StudySession>? get studyCycle => _studyCycle;
  int get completedCycles => _completedCycles;
  int get currentProgressMinutes => _currentProgressMinutes;
  Map<String, int> get sessionProgressMap => _sessionProgressMap;
  Map<String, int> get extraStudyTimeBySubjectId => _extraStudyTimeBySubjectId;
  String get studyHours => _studyHours;
  String get weeklyQuestionsGoal => _weeklyQuestionsGoal;
  Map<String, Map<String, double>> get subjectSettings => _subjectSettings;
  List<String> get studyDays => _studyDays;
  String? get currentCycleId => _currentCycleId;

  String _key(String base) {
    final userId = _authProvider?.currentUser?.name ?? 'default_user';
    if (_planId == null) {
      throw Exception("PlanningProvider: Plan ID is not set");
    }
    return '${userId}_${base}_$_planId';
  }

  void updateForPlan(String? newPlanId) {
    if (_planId == newPlanId) return;

    if (_planId == null && newPlanId == null) {
      return;
    }

    _planId = newPlanId;

    if (_planId == null) {
      _clearDataInMemory();
    } else {
      loadData();
    }
  }

  void _clearDataInMemory() {
    _subjects = [];
    _studyCycle = null;
    _completedCycles = 0;
    _currentProgressMinutes = 0;
    _sessionProgressMap = {};
    _extraStudyTimeBySubjectId = {};
    _studyHours = '0';
    _weeklyQuestionsGoal = '0';
    _subjectSettings = {};
    _studyDays = [];
    _currentCycleId = null;
    notifyListeners();
  }

  void setSubjects(List<Subject> newSubjects) {
    _subjects = newSubjects;
    saveData();
    notifyListeners();
  }

  void setStudyCycle(List<StudySession>? newCycle) {
    _studyCycle = newCycle;
    saveData();
    notifyListeners();
  }

  void setCompletedCycles(int count) {
    _completedCycles = count;
    saveData();
    notifyListeners();
  }

  void setCurrentProgressMinutes(int minutes) {
    _currentProgressMinutes = minutes;
    saveData();
    notifyListeners();
  }

  void setSessionProgressMap(Map<String, int> newMap) {
    _sessionProgressMap = newMap;
    saveData();
    notifyListeners();
  }

  void setStudyHours(String hours) {
    _studyHours = hours;
    saveData();
    notifyListeners();
  }

  void setWeeklyQuestionsGoal(String goal) {
    _weeklyQuestionsGoal = goal;
    saveData();
    notifyListeners();
  }

  void setSubjectSettings(Map<String, Map<String, double>> settings) {
    _subjectSettings = settings;
    saveData();
    notifyListeners();
  }

  void setStudyDays(List<String> days) {
    _studyDays = days;
    saveData();
    notifyListeners();
  }

  void updateProgress(StudyRecord record) {
    if (record.cycleId == _currentCycleId) {
      _applyProgress(record);
      saveData();
      notifyListeners();
    }
  }

  void _applyProgress(StudyRecord record) {
    if (studyCycle == null || !record.count_in_planning) return;

    int remainingStudyMinutes = (record.study_time / 60000).round();
    if (remainingStudyMinutes <= 0) return;

    final subjectSessions = studyCycle!
        .where((s) => s.subjectId == record.subject_id)
        .toList();

    for (final session in subjectSessions) {
      if (remainingStudyMinutes <= 0) break;

      final currentProgress = _sessionProgressMap[session.id] ?? 0;
      final timeToComplete = session.duration - currentProgress;

      if (timeToComplete > 0) {
        int timeToAdd = remainingStudyMinutes;
        if (timeToAdd > timeToComplete) {
          timeToAdd = timeToComplete;
        }

        _sessionProgressMap[session.id] = currentProgress + timeToAdd;
        _currentProgressMinutes += timeToAdd;
        remainingStudyMinutes -= timeToAdd;
      }
    }

    if (remainingStudyMinutes > 0) {
      final currentExtraTime = _extraStudyTimeBySubjectId[record.subject_id] ?? 0;
      _extraStudyTimeBySubjectId[record.subject_id] = currentExtraTime + remainingStudyMinutes;
    }

    final totalCycleDuration = studyCycle!.fold<int>(
      0,
      (sum, s) => sum + s.duration,
    );
    if (totalCycleDuration > 0 && _currentProgressMinutes >= totalCycleDuration) {
      _completedCycles++;
      _currentProgressMinutes -= totalCycleDuration;
      _sessionProgressMap = {};
      _extraStudyTimeBySubjectId = {};
    }
  }

  void recalculateProgress(List<StudyRecord> allRecords) {
    if (studyCycle == null || _currentCycleId == null) {
      _currentProgressMinutes = 0;
      _completedCycles = 0;
      _sessionProgressMap = {};
      _extraStudyTimeBySubjectId = {};
      return;
    }

    _currentProgressMinutes = 0;
    _completedCycles = 0;
    _sessionProgressMap = {};
    _extraStudyTimeBySubjectId = {};

    final relevantRecords = allRecords.where((r) {
      return r.cycleId == _currentCycleId && r.count_in_planning;
    }).toList();

    relevantRecords.sort(
      (a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)),
    );

    for (final record in relevantRecords) {
      _applyProgress(record);
    }

    saveData();
    notifyListeners();
  }

  Future<void> loadData() async {
    if (_planId == null) {
      _clearDataInMemory();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final studyCycleString = prefs.getString(_key('studyCycle'));
    if (studyCycleString != null) {
      final List<dynamic> decodedCycle = jsonDecode(studyCycleString) as List<dynamic>;
      _studyCycle = decodedCycle
          .map((item) => StudySession.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      _studyCycle = null;
    }

    _completedCycles = prefs.getInt(_key('completedCycles')) ?? 0;
    _currentProgressMinutes = prefs.getInt(_key('currentProgressMinutes')) ?? 0;

    final sessionProgressMapString = prefs.getString(_key('sessionProgressMap'));
    if (sessionProgressMapString != null) {
      _sessionProgressMap = Map<String, int>.from(
        jsonDecode(sessionProgressMapString) as Map<String, dynamic>,
      );
    } else {
      _sessionProgressMap = {};
    }

    final extraStudyTimeString = prefs.getString(_key('extraStudyTimeBySubjectId'));
    if (extraStudyTimeString != null) {
      _extraStudyTimeBySubjectId = Map<String, int>.from(
        jsonDecode(extraStudyTimeString) as Map<String, dynamic>,
      );
    } else {
      _extraStudyTimeBySubjectId = {};
    }

    _studyHours = prefs.getString(_key('studyHours')) ?? '0';
    _weeklyQuestionsGoal = prefs.getString(_key('weeklyQuestionsGoal')) ?? '0';

    final subjectSettingsString = prefs.getString(_key('subjectSettings'));
    if (subjectSettingsString != null) {
      _subjectSettings = Map<String, Map<String, double>>.from(
        (jsonDecode(subjectSettingsString) as Map<String, dynamic>).map(
          (key, value) => MapEntry(
            key,
            Map<String, double>.from(value as Map<String, dynamic>),
          ),
        ),
      );
    } else {
      _subjectSettings = {};
    }

    _studyDays = prefs.getStringList(_key('studyDays')) ?? [];
    _currentCycleId = prefs.getString(_key('currentCycleId'));

    if (_studyCycle != null && _currentCycleId == null) {
      if (_historyProvider != null) {
        await _historyProvider!.fetchHistory();

        final candidateIds = _historyProvider!.allStudyRecords
            .where((r) => r.cycleId != null && r.count_in_planning)
            .map((r) => r.cycleId!)
            .toList();

        if (candidateIds.isNotEmpty) {
          final mostCommon = candidateIds
              .fold<Map<String, int>>({}, (map, id) => map..update(id, (v) => v + 1, ifAbsent: () => 1))
              .entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;

          _currentCycleId = mostCommon;
        } else {
          _currentCycleId = const Uuid().v4();
        }
      } else {
        _currentCycleId = const Uuid().v4();
      }

      await saveData();
    }

    if (_historyProvider != null) {
      await _historyProvider!.fetchHistory();
      recalculateProgress(_historyProvider!.allStudyRecords);
    } else {
      notifyListeners();
    }
  }

  Future<void> saveData() async {
    if (_planId == null) return;
    final prefs = await SharedPreferences.getInstance();

    if (_studyCycle != null) {
      final studyCycleString = jsonEncode(
        _studyCycle!.map((session) => session.toJson()).toList(),
      );
      await prefs.setString(_key('studyCycle'), studyCycleString);
    } else {
      await prefs.remove(_key('studyCycle'));
    }
    await prefs.setInt(_key('completedCycles'), _completedCycles);
    await prefs.setInt(_key('currentProgressMinutes'), _currentProgressMinutes);
    await prefs.setString(
      _key('sessionProgressMap'),
      jsonEncode(_sessionProgressMap),
    );
    await prefs.setString(
      _key('extraStudyTimeBySubjectId'),
      jsonEncode(_extraStudyTimeBySubjectId),
    );
    await prefs.setString(_key('studyHours'), _studyHours);
    await prefs.setString(_key('weeklyQuestionsGoal'), _weeklyQuestionsGoal);
    await prefs.setString(
      _key('subjectSettings'),
      jsonEncode(_subjectSettings),
    );
    await prefs.setStringList(_key('studyDays'), _studyDays);
    if (_currentCycleId != null) {
      await prefs.setString(_key('currentCycleId'), _currentCycleId!);
    } else {
      await prefs.remove(_key('currentCycleId'));
    }
  }

  Future<void> clearData() async {
    if (_planId == null) return;
    _clearDataInMemory();
    await saveData();
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _clearDataInMemory();
  }

  void generateStudyCycle({
    required int studyHours,
    required int minSession,
    required int maxSession,
    required Map<String, Map<String, double>> subjectSettings,
    required List<Subject> subjects,
    required String weeklyQuestionsGoal,
    required bool shuffle,
  }) {
    resetStudyCycle();

    if (subjects.isEmpty) {
      _studyCycle = [];
      saveData();
      notifyListeners();
      return;
    }

    final List<StudySession> generatedCycle = [];
    final Map<String, double> subjectWeights = {};
    double totalWeight = 0;

    for (final subject in subjects) {
      final settings = subjectSettings[subject.id] ?? {'importance': 3, 'knowledge': 3};
      final importance = settings['importance']!;
      final knowledge = settings['knowledge']!;
      final weight = importance / knowledge;
      subjectWeights[subject.id] = weight;
      totalWeight += weight;
    }

    final totalStudyMinutes = studyHours * 60;

    for (final subject in subjects) {
      final weight = subjectWeights[subject.id]!;
      final subjectStudyMinutes = (totalStudyMinutes * (weight / totalWeight));
      final averageSessionDuration = (minSession + maxSession) / 2;
      int numberOfSessions = (subjectStudyMinutes / averageSessionDuration).round();
      if (numberOfSessions == 0) continue;

      int sessionDuration = (subjectStudyMinutes / numberOfSessions).round();
      if (sessionDuration < minSession) sessionDuration = minSession;
      if (sessionDuration > maxSession) sessionDuration = maxSession;

      for (int i = 0; i < numberOfSessions; i++) {
        generatedCycle.add(
          StudySession(
            id: '${subject.id}_$i',
            subject: subject.subject,
            subjectId: subject.id,
            duration: sessionDuration,
            color: subject.color,
          ),
        );
      }
    }

    if (shuffle) {
      generatedCycle.shuffle();
    }
    _studyCycle = generatedCycle;
    _currentCycleId = const Uuid().v4();

    saveData();
    notifyListeners();
  }

  void setManualStudyCycle(List<StudySession> manualCycle) {
    resetStudyCycle();

    _studyCycle = manualCycle;
    _currentCycleId = const Uuid().v4();

    saveData();
    notifyListeners();
  }

  void shuffleUncompletedSessions() {
    if (_studyCycle == null) return;

    final completedSessions = _studyCycle!.where((session) {
      final progress = _sessionProgressMap[session.id] ?? 0;
      return progress >= session.duration;
    }).toList();
    
    final uncompletedSessions = _studyCycle!.where((session) {
      final progress = _sessionProgressMap[session.id] ?? 0;
      return progress < session.duration;
    }).toList();
    
    uncompletedSessions.shuffle();
    
    _studyCycle = [...completedSessions, ...uncompletedSessions];
    saveData();
    notifyListeners();
  }

  void resetStudyCycle() {
    _studyCycle = null;
    _completedCycles = 0;
    _currentProgressMinutes = 0;
    _sessionProgressMap = {};
    _currentCycleId = null;
    saveData();
    notifyListeners();
  }

  Future<void> addStudyRecord(StudyRecord record) async {
    notifyListeners();
  }

  Future<void> updateStudyRecord(StudyRecord record) async {
    notifyListeners();
  }

  Future<void> deleteStudyRecord(String id) async {
    notifyListeners();
  }

  List<Topic> _flattenTopics(List<Topic> topics) {
    List<Topic> flattened = [];
    for (var topic in topics) {
      flattened.add(topic);
      if (topic.sub_topics != null && topic.sub_topics!.isNotEmpty) {
        flattened.addAll(_flattenTopics(topic.sub_topics!));
      }
    }
    return flattened;
  }

  Map<String, dynamic> getRecommendedSession({
    String? forceSubject,
    List<StudyRecord> studyRecords = const [],
    required List<Subject> subjects,
    required List<ReviewRecord> reviewRecords,
  }) {
    if (_studyCycle == null || _studyCycle!.isEmpty) {
      return {
        'recommendedTopics': <TopicWithTime>[],
        'justification': 'Nenhum ciclo de estudos ativo.',
        'nextSession': null,
      };
    }

    StudySession? nextSession;
    if (forceSubject != null) {
      nextSession = _studyCycle!.firstWhereOrNull(
        (session) =>
            session.subject == forceSubject &&
            (_sessionProgressMap[session.id] ?? 0) < session.duration,
      );
    }

    nextSession ??= _studyCycle!.firstWhereOrNull(
      (session) => (_sessionProgressMap[session.id] ?? 0) < session.duration,
    );

    if (nextSession == null) {
      return {
        'recommendedTopics': <TopicWithTime>[],
        'justification': 'Parabéns! Você concluiu todas as sessões deste ciclo.',
        'nextSession': null,
      };
    }

    final subject = subjects.firstWhereOrNull(
      (s) => s.id == nextSession!.subjectId,
    );
    if (subject == null || subject.topics.isEmpty) {
      return {
        'recommendedTopics': <TopicWithTime>[],
        'justification': 'Seguindo a ordem do seu ciclo de estudos.',
        'nextSession': nextSession,
      };
    }

    final allTopics = _flattenTopics(subject.topics)
        .where((t) => t.sub_topics == null || t.sub_topics!.isEmpty)
        .toList();
    if (allTopics.isEmpty) {
      return {
        'recommendedTopics': <TopicWithTime>[],
        'justification': 'Não há tópicos cadastrados para esta matéria.',
        'nextSession': nextSession,
      };
    }

    if (mentoriaProvider?.sequentialTopics == true) {
      final firstUnstudiedTopic = allTopics.firstWhereOrNull((topic) {
        return studyRecords.every(
          (r) => !r.topicsProgress.any(
            (tp) => tp.topicText == topic.topic_text && tp.isTheoryFinished,
          ),
        );
      });

      final recommendedTopics = <TopicWithTime>[];
      if (firstUnstudiedTopic != null) {
        recommendedTopics.add(TopicWithTime(
          topic: firstUnstudiedTopic,
          allocatedTimeSeconds: nextSession.duration * 60, // Aloca todo o tempo para o primeiro tópico (convertido para segundos)
          justification: 'Recomendação sequencial ativada.',
        ));
      }

      return {
        'recommendedTopics': recommendedTopics,
        'justification': 'Recomendação sequencial ativada.',
        'nextSession': nextSession,
      };
    }

    final now = DateTime.now();
    final Map<Topic, double> topicScores = {};

    for (var topic in allTopics) {
      final List<TopicProgress> topicProgresses = studyRecords
          .expand((r) => r.topicsProgress)
          .where((tp) => tp.topicText == topic.topic_text)
          .toList();

      double totalScore = 0;
      int criteriaCount = 0;

      if (mentoriaProvider?.useHitRate == true) {
        final recordsWithQuestions = topicProgresses
            .where((tp) => (tp.questions['total'] ?? 0) > 0)
            .toList();
        double accuracyScore;
        if (recordsWithQuestions.isEmpty) {
          accuracyScore = 0.75;
        } else {
          int totalCorrect = recordsWithQuestions
              .map((tp) => tp.questions['correct'] ?? 0)
              .reduce((a, b) => a + b);
          int totalQuestions = recordsWithQuestions
              .map((tp) => tp.questions['total'] ?? 0)
              .reduce((a, b) => a + b);
          double accuracy = totalQuestions > 0 ? totalCorrect / totalQuestions : 1.0;
          accuracyScore = 1.0 - accuracy;
        }
        totalScore += accuracyScore;
        criteriaCount++;
      }

      if (mentoriaProvider?.prioritizeLessStudiedTime == true) {
        double totalStudyTime = studyRecords
            .where((r) => r.topicsProgress.any((tp) => tp.topicText == topic.topic_text))
            .fold(0, (sum, r) => sum + r.study_time);
        double score = 1.0 - (totalStudyTime / (10 * 3600000)).clamp(0.0, 1.0);
        totalScore += score;
        criteriaCount++;
      }

      if (mentoriaProvider?.prioritizeMoreStudiedTime == true) {
        double totalStudyTime = studyRecords
            .where((r) => r.topicsProgress.any((tp) => tp.topicText == topic.topic_text))
            .fold(0, (sum, r) => sum + r.study_time);
        double score = (totalStudyTime / (10 * 3600000)).clamp(0.0, 1.0);
        totalScore += score;
        criteriaCount++;
      }

      if (mentoriaProvider?.prioritizeMostErrors == true) {
        int totalErrors = topicProgresses.fold(
          0,
          (sum, tp) => sum + (tp.questions['total'] ?? 0) - (tp.questions['correct'] ?? 0),
        );
        double score = (totalErrors / 100.0).clamp(0.0, 1.0);
        totalScore += score;
        criteriaCount++;
      }

      if (mentoriaProvider?.prioritizeLeastQuestions == true) {
        int totalQuestions = topicProgresses.fold(
          0,
          (sum, tp) => sum + (tp.questions['total'] ?? 0),
        );
        double score = 1.0 - (totalQuestions / 200.0).clamp(0.0, 1.0);
        totalScore += score;
        criteriaCount++;
      }

      if (mentoriaProvider?.prioritizePendingReviews == true) {
        final pendingReviews = reviewRecords
            .where(
              (r) =>
                  r.topics.contains(topic.topic_text) &&
                  r.subject_id == subject.id &&
                  r.status == 'pending',
            )
            .toList();
        if (pendingReviews.isNotEmpty) {
          totalScore += 1.0;
        }
        criteriaCount++;
      }

      if (mentoriaProvider?.prioritizeMostReviewed == true) {
        final reviewedCount = reviewRecords
            .where(
              (r) =>
                  r.topics.contains(topic.topic_text) &&
                  r.subject_id == subject.id,
            )
            .length;
        double score = (reviewedCount / 10.0).clamp(0.0, 1.0);
        totalScore += score;
        criteriaCount++;
      }

      if (mentoriaProvider?.prioritizeNotStudiedInTimeWindow == true) {
        if (topicProgresses.isEmpty) {
          totalScore += 1.0;
        } else {
          final relevantRecords = studyRecords
              .where((r) => r.topicsProgress.any((tp) => tp.topicText == topic.topic_text))
              .toList();
          if (relevantRecords.isNotEmpty) {
            relevantRecords.sort(
              (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)),
            );
            final lastStudied = DateTime.parse(relevantRecords.first.date);
            final daysSince = now.difference(lastStudied).inDays;
            if (daysSince >= (mentoriaProvider?.notStudiedInDays ?? 7)) {
              totalScore += 1.0;
            }
          } else {
            totalScore += 1.0;
          }
        }
        criteriaCount++;
      }

      if (mentoriaProvider?.prioritizeTopicWeights == true && topic.userWeight != null) {
        double normalizedWeight = (topic.userWeight! - 1) / 4.0;
        totalScore += normalizedWeight;
        criteriaCount++;
      }

      if (mentoriaProvider?.prioritizeNotRecentlyStudied == true) {
        final relevantRecords = studyRecords
            .where((r) => r.topicsProgress.any((tp) => tp.topicText == topic.topic_text))
            .toList();
        if (relevantRecords.isNotEmpty) {
          relevantRecords.sort(
            (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)),
          );
          final lastStudiedDate = DateTime.parse(relevantRecords.first.date);
          final difference = now.difference(lastStudiedDate);
          if (difference.inDays < 1) {
            totalScore -= 0.5;
          }
        } else {
          totalScore += 0.5;
        }
        criteriaCount++;
      }

      if (mentoriaProvider?.prioritizeUnfinishedTopics == true) {
        final bool teoriaFinalizada = topicProgresses.any((tp) => tp.isTheoryFinished);
        if (!teoriaFinalizada) {
          totalScore += 1.0;
        }
        criteriaCount++;
      }

      topicScores[topic] = criteriaCount > 0 ? totalScore / criteriaCount : 0;
    }

    // Sort topics by score in descending order
    final sortedTopics = topicScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<TopicWithTime> recommendedTopics = [];
    String justification = 'Sugerido com base nos seus critérios de mentoria.';

    if (mentoriaProvider?.multiTopicRecommendationEnabled == true &&
        mentoriaProvider?.maxTopicsPerSession != null &&
        mentoriaProvider!.maxTopicsPerSession > 1) {
      final int maxTopics = mentoriaProvider!.maxTopicsPerSession;
      final int totalSessionDurationSeconds = nextSession.duration * 60;
      final String timeAllocationStrategy = mentoriaProvider?.timeAllocationStrategy ?? 'proportional';

      final selectedTopics = sortedTopics.take(maxTopics).toList();
      double totalSelectedScore = selectedTopics.fold(0.0, (sum, entry) => sum + entry.value);

      int remainingTimeSeconds = totalSessionDurationSeconds;

      for (int i = 0; i < selectedTopics.length; i++) {
        final topic = selectedTopics[i].key;
        final score = selectedTopics[i].value;
        int allocatedTimeSeconds = 0;

        if (timeAllocationStrategy == 'proportional' && totalSelectedScore > 0) {
          allocatedTimeSeconds = (totalSessionDurationSeconds * (score / totalSelectedScore)).round();
        } else {
          // Equal split or if totalSelectedScore is 0
          allocatedTimeSeconds = (totalSessionDurationSeconds / selectedTopics.length).round();
        }

        // Adjust for remaining time in the last topic to ensure total matches
        if (i == selectedTopics.length - 1) {
          allocatedTimeSeconds = remainingTimeSeconds;
        } else if (allocatedTimeSeconds > remainingTimeSeconds) {
          allocatedTimeSeconds = remainingTimeSeconds;
        }

        recommendedTopics.add(TopicWithTime(
          topic: topic,
          allocatedTimeSeconds: allocatedTimeSeconds,
          justification: justification,
        ));
        remainingTimeSeconds -= allocatedTimeSeconds;
      }
    } else {
      // Single topic recommendation
      Topic? bestTopic = sortedTopics.isNotEmpty ? sortedTopics.first.key : null;
      if (bestTopic != null) {
        recommendedTopics.add(TopicWithTime(
          topic: bestTopic,
          allocatedTimeSeconds: nextSession.duration * 60,
          justification: justification,
        ));
      }
    }

    return {
      'recommendedTopics': recommendedTopics,
      'justification': justification,
      'nextSession': nextSession,
    };

  }
}
