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
  final String? currentCycleId;

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
    this.currentCycleId,
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
      'currentCycleId': currentCycleId,
    };
  }

  factory PlanningBackupData.fromMap(Map<String, dynamic> map) {
    return PlanningBackupData(
      studyCycle: map['studyCycle'] != null
          ? List<StudySession>.from(
              (map['studyCycle'] as List<dynamic>).map(
                (x) => StudySession.fromJson(x as Map<String, dynamic>),
              ),
            )
          : null,
      completedCycles: map['completedCycles'] as int? ?? 0,
      currentProgressMinutes: map['currentProgressMinutes'] as int? ?? 0,
      sessionProgressMap: Map<String, int>.from(
        map['sessionProgressMap'] as Map<String, dynamic>? ?? {},
      ),
      studyHours: map['studyHours'] as String? ?? '0',
      weeklyQuestionsGoal: map['weeklyQuestionsGoal'] as String? ?? '0',
      subjectSettings: Map<String, Map<String, double>>.from(
        (map['subjectSettings'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(
                key,
                Map<String, double>.from(value as Map<String, dynamic>),
              ),
            ) ??
            {},
      ),
      studyDays: List<String>.from(map['studyDays'] as List<dynamic>? ?? []),
      cycleGenerationTimestamp: map['cycleGenerationTimestamp'] as String?,
      currentCycleId: map['currentCycleId'] as String?,
    );
  }
}

class BackupData {
  final List<Plan> plans;
  final List<Subject> subjects;
  final List<StudyRecord> studyRecords;
  final List<ReviewRecord> reviewRecords;
  final List<SimuladoRecord> simuladoRecords;
  final Map<String, PlanningBackupData> planningDataPerPlan;

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
      plans: List<Plan>.from(
        (map['plans'] as List<dynamic>?)?.map((x) => Plan.fromMap(x as Map<String, dynamic>)) ?? [],
      ),
      subjects: List<Subject>.from(
        (map['subjects'] as List<dynamic>?)?.map((x) {
              final subjectMap = x as Map<String, dynamic>;
              final topicsList = subjectMap['topics'] as List<dynamic>?;
              final hierarchicalTopics = topicsList
                  ?.map((t) => Topic.fromBackupMap(t as Map<String, dynamic>))
                  .toList() ?? [];
              return Subject.fromMap(subjectMap, hierarchicalTopics);
            }) ??
            [],
      ),
      studyRecords: List<StudyRecord>.from(
        (map['studyRecords'] as List<dynamic>?)?.map((x) => StudyRecord.fromMap(x as Map<String, dynamic>)) ?? [],
      ),
      reviewRecords: List<ReviewRecord>.from(
        (map['reviewRecords'] as List<dynamic>?)?.map((x) => ReviewRecord.fromMap(x as Map<String, dynamic>)) ?? [],
      ),
      simuladoRecords: List<SimuladoRecord>.from(
        (map['simuladoRecords'] as List<dynamic>?)?.map((x) {
              final recordMap = x as Map<String, dynamic>;
              final subjectsList = recordMap['subjects'] as List<dynamic>?;
              return SimuladoRecord.fromMap(
                recordMap,
                subjectsList?.map((s) => SimuladoSubject.fromMap(s as Map<String, dynamic>)).toList() ?? [],
              );
            }) ??
            [],
      ),
      planningDataPerPlan: Map<String, PlanningBackupData>.from(
        (map['planningDataPerPlan'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(
                key,
                PlanningBackupData.fromMap(value as Map<String, dynamic>),
              ),
            ) ??
            {},
      ),
    );
  }

  static List<Topic> _buildTopicHierarchy(List<Topic> flatTopics) {
    final Map<int, Topic> topicMap = {};
    for (final topic in flatTopics) {
      if (topic.id != null) {
        topicMap[topic.id!] = topic.copyWith(
          sub_topics: [],
        );
      }
    }

    final List<Topic> rootTopics = [];
    for (final topic in flatTopics) {
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
