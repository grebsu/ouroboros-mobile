import 'dart:convert';
import 'package:ouroboros_mobile/models/data_models.dart';

class PlanningBackupData {
  final List<StudySession>? studyCycle;
  final int completedCycles;
  final int currentProgressMinutes;
  final Map<String, int> sessionProgressMap;
  final String studyHours;
  final String weeklyQuestionsGoal;
  final Map<String, Map<String, double>> subjectSettings;
  final List<String> studyDays;
  final String? cycleGenerationTimestamp;

  PlanningBackupData({
    this.studyCycle,
    required this.completedCycles,
    required this.currentProgressMinutes,
    required this.sessionProgressMap,
    required this.studyHours,
    required this.weeklyQuestionsGoal,
    required this.subjectSettings,
    required this.studyDays,
    this.cycleGenerationTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'studyCycle': studyCycle?.map((x) => x.toJson()).toList(),
      'completedCycles': completedCycles,
      'currentProgressMinutes': currentProgressMinutes,
      'sessionProgressMap': sessionProgressMap,
      'studyHours': studyHours,
      'weeklyQuestionsGoal': weeklyQuestionsGoal,
      'subjectSettings': subjectSettings,
      'studyDays': studyDays,
      'cycleGenerationTimestamp': cycleGenerationTimestamp,
    };
  }

  factory PlanningBackupData.fromMap(Map<String, dynamic> map) {
    return PlanningBackupData(
      studyCycle: map['studyCycle'] != null
          ? List<StudySession>.from(
              map['studyCycle'].map((x) => StudySession.fromJson(x)),
            )
          : null,
      completedCycles: map['completedCycles'] ?? 0,
      currentProgressMinutes: map['currentProgressMinutes'] ?? 0,
      sessionProgressMap: Map<String, int>.from(
        map['sessionProgressMap'] ?? {},
      ),
      studyHours: map['studyHours'] ?? '0',
      weeklyQuestionsGoal: map['weeklyQuestionsGoal'] ?? '0',
      subjectSettings: Map<String, Map<String, double>>.from(
        (map['subjectSettings'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, Map<String, double>.from(value)),
            ) ??
            {},
      ),
      studyDays: List<String>.from(map['studyDays'] ?? []),
      cycleGenerationTimestamp: map['cycleGenerationTimestamp'],
    );
  }
}

class BackupData {
  final List<Plan> plans;
  final List<Subject> subjects;
  final List<StudyRecord> studyRecords;
  final List<ReviewRecord> reviewRecords;
  final List<SimuladoRecord> simuladoRecords;
  final Map<String, PlanningBackupData> planningDataPerPlan; // Keyed by planId

  BackupData({
    required this.plans,
    required this.subjects,
    required this.studyRecords,
    required this.reviewRecords,
    required this.simuladoRecords,
    required this.planningDataPerPlan,
  });

  Map<String, dynamic> toMap() {
    return {
      'plans': plans.map((x) => x.toMap()).toList(),
      'subjects': subjects.map((x) => x.toMapWithTopics()).toList(),
      'studyRecords': studyRecords.map((x) => x.toMap()).toList(),
      'reviewRecords': reviewRecords.map((x) => x.toMap()).toList(),
      'simuladoRecords': simuladoRecords.map((x) => x.toMap()).toList(),
      'planningDataPerPlan': planningDataPerPlan.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    };
  }

  factory BackupData.fromMap(Map<String, dynamic> map) {
    return BackupData(
      plans: List<Plan>.from(map['plans']?.map((x) => Plan.fromMap(x)) ?? []),
      subjects: List<Subject>.from(
        map['subjects']?.map((x) {
              // Extrai a lista de tópicos e reconstrói a hierarquia
              List<Topic> hierarchicalTopics =
                  (x['topics'] as List<dynamic>?)
                      ?.map((t) => Topic.fromBackupMap(t))
                      .toList() ??
                  [];
              return Subject.fromMap(x, hierarchicalTopics);
            }) ??
            [],
      ),
      studyRecords: List<StudyRecord>.from(
        map['studyRecords']?.map((x) => StudyRecord.fromMap(x)) ?? [],
      ),
      reviewRecords: List<ReviewRecord>.from(
        map['reviewRecords']?.map((x) => ReviewRecord.fromMap(x)) ?? [],
      ),
      simuladoRecords: List<SimuladoRecord>.from(
        map['simuladoRecords']?.map(
              (x) => SimuladoRecord.fromMap(
                x,
                (x['subjects'] as List<dynamic>)
                    .map((s) => SimuladoSubject.fromMap(s))
                    .toList(),
              ),
            ) ??
            [],
      ),
      planningDataPerPlan: Map<String, PlanningBackupData>.from(
        (map['planningDataPerPlan'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, PlanningBackupData.fromMap(value)),
            ) ??
            {},
      ),
    );
  }

  static List<Topic> _buildTopicHierarchy(List<Topic> flatTopics) {
    final Map<int, Topic> topicMap = {};
    for (var topic in flatTopics) {
      if (topic.id != null) {
        topicMap[topic.id!] = topic.copyWith(
          sub_topics: [],
        ); // Initialize sub_topics
      }
    }

    final List<Topic> rootTopics = [];
    for (var topic in flatTopics) {
      if (topic.parent_id == null) {
        rootTopics.add(topicMap[topic.id!] ?? topic);
      } else {
        final parent = topicMap[topic.parent_id!];
        if (parent != null) {
          parent.sub_topics ??= [];
          parent.sub_topics!.add(topicMap[topic.id!] ?? topic);
        }
      }
    }
    return rootTopics;
  }
}
