import 'package:flutter/material.dart';
import 'dart:convert';

// Helper para criar MaterialColor a partir de uma única cor
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

enum StudyCategory { teoria, revisao, questoes, leituraLei, jurisprudencia }

// Data Models

class Topic {
  final int? id;
  String? subject_id; // Tornar opcional
  final String topic_text;
  final int? parent_id;
  List<Topic>? sub_topics;
  bool? is_grouping_topic;
  final int? question_count;
  final int? userWeight;
  bool isSelected;
  bool isEditing;
  final int? lastModified;

  Topic({
    this.id,
    this.subject_id, // Tornar opcional
    required this.topic_text,
    this.parent_id,
    this.sub_topics,
    this.is_grouping_topic,
    this.question_count,
    this.userWeight,
    this.isSelected = true, // Default to selected
    this.isEditing = false,
    this.lastModified,
  });

  factory Topic.fromMap(Map<String, dynamic> map) {
    List<Topic> subTopics = [];
    if (map['sub_topics'] != null) {
      subTopics = (map['sub_topics'] as List<dynamic>)
          .map(
            (t) => Topic.fromMap(t as Map<String, dynamic>),
          ) // Recursive call with cast
          .toList();
    }

    return Topic(
      id: map['id'],
      subject_id: map['subject_id'],
      topic_text: map['topic_text'],
      parent_id: map['parent_id'],
      sub_topics:
          subTopics, // Initially empty, will be populated by DatabaseService
      is_grouping_topic: map['is_grouping_topic'] == 1, // Directly read from DB
      question_count: map['question_count'],
      userWeight: map['userWeight'],
      lastModified:
          map['lastModified'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory Topic.fromBackupMap(Map<String, dynamic> map) {
    List<Topic> subTopics = [];
    if (map['sub_topics'] != null) {
      subTopics = (map['sub_topics'] as List<dynamic>)
          .map((t) => Topic.fromBackupMap(t)) // Recursive call
          .toList();
    }

    return Topic(
      id: map['id'],
      subject_id: map['subject_id'],
      topic_text: map['topic_text'],
      parent_id: map['parent_id'],
      sub_topics: subTopics, // Use the recursively populated list
      is_grouping_topic: map['is_grouping_topic'] ?? false,
      question_count: map['question_count'],
      userWeight: map['userWeight'],
      lastModified:
          map['lastModified'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subject_id,
      'topic_text': topic_text,
      'parent_id': parent_id,
      'is_grouping_topic': (is_grouping_topic ?? false) ? 1 : 0,
      'question_count': question_count,
      'userWeight': userWeight,
      'lastModified': lastModified,
    };
  }

  Map<String, dynamic> toMapForBackup() {
    return {
      'id': id,
      'subject_id': subject_id,
      'topic_text': topic_text,
      'parent_id': parent_id,
      'is_grouping_topic': is_grouping_topic,
      'question_count': question_count,
      'userWeight': userWeight,
      'sub_topics': sub_topics?.map((t) => t.toMapForBackup()).toList(),
      'lastModified': lastModified,
    };
  }

  Topic copyWith({
    int? id,
    String? subject_id,
    String? topic_text,
    int? parent_id,
    List<Topic>? sub_topics,
    bool? is_grouping_topic,
    int? question_count,
    int? userWeight,
    bool? isSelected,
    bool? isEditing,
    int? lastModified,
  }) {
    return Topic(
      id: id ?? this.id,
      subject_id: subject_id ?? this.subject_id,
      topic_text: topic_text ?? this.topic_text,
      parent_id: parent_id ?? this.parent_id,
      sub_topics: sub_topics ?? this.sub_topics,
      is_grouping_topic: is_grouping_topic ?? this.is_grouping_topic,
      question_count: question_count ?? this.question_count,
      userWeight: userWeight ?? this.userWeight,
      isSelected: isSelected ?? this.isSelected,
      isEditing: isEditing ?? this.isEditing,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

// NEW CLASS: TopicProgress
class TopicProgress {
  final String topicId;
  final String
  topicText; // Para facilitar a exibição sem precisar buscar o Topic
  final Map<String, int> questions; // {'total':..., 'correct':...}
  final List<Map<String, int>> pages; // [{'start':..., 'end':...}]
  final List<Map<String, String>> videos; // [{'url':..., 'description':...}]
  final String? notes;
  final bool isTheoryFinished;
  final int? userWeight; // Peso do tópico no momento do estudo, pode ser útil

  TopicProgress({
    required this.topicId,
    required this.topicText,
    this.questions = const {'total': 0, 'correct': 0},
    this.pages = const [],
    this.videos = const [],
    this.notes,
    this.isTheoryFinished = false,
    this.userWeight,
  });

  factory TopicProgress.fromMap(Map<String, dynamic> map) {
    return TopicProgress(
      topicId: map['topicId'],
      topicText: map['topicText'],
      questions: Map<String, int>.from(
        map['questions'] ?? {'total': 0, 'correct': 0},
      ),
      pages:
          (map['pages'] as List<dynamic>?)
              ?.map((e) => Map<String, int>.from(e))
              .toList() ??
          [],
      videos:
          (map['videos'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      notes: map['notes'],
      isTheoryFinished: map['isTheoryFinished'] ?? false,
      userWeight: map['userWeight'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'topicId': topicId,
      'topicText': topicText,
      'questions': questions,
      'pages': pages,
      'videos': videos,
      'notes': notes,
      'isTheoryFinished': isTheoryFinished,
      'userWeight': userWeight,
    };
  }

  TopicProgress copyWith({
    String? topicId,
    String? topicText,
    Map<String, int>? questions,
    List<Map<String, int>>? pages,
    List<Map<String, String>>? videos,
    String? notes,
    bool? isTheoryFinished,
    int? userWeight,
  }) {
    return TopicProgress(
      topicId: topicId ?? this.topicId,
      topicText: topicText ?? this.topicText,
      questions: questions ?? this.questions,
      pages: pages ?? this.pages,
      videos: videos ?? this.videos,
      notes: notes ?? this.notes,
      isTheoryFinished: isTheoryFinished ?? this.isTheoryFinished,
      userWeight: userWeight ?? this.userWeight,
    );
  }
}

class Subject {
  final String id;
  final String plan_id;
  final String subject;
  final List<Topic> topics;
  final String color;
  final int? total_topics_count;
  final String? import_source;
  final int lastModified;

  Subject({
    required this.id,
    required this.plan_id,
    required this.subject,
    required this.topics,
    required this.color,
    this.total_topics_count,
    this.import_source,
    required this.lastModified,
  });

  factory Subject.fromMap(Map<String, dynamic> map, List<Topic> topics) {
    return Subject(
      id: map['id'],
      plan_id: map['plan_id'],
      subject: map['subject'],
      color: map['color'],
      topics: topics,
      total_topics_count: map['total_topics_count'],
      import_source: map['import_source'],
      lastModified:
          map['lastModified'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_id': plan_id,
      'subject': subject,
      'color': color,
      'total_topics_count': total_topics_count,
      'import_source': import_source,
      'lastModified': lastModified,
    };
  }

  Map<String, dynamic> toMapWithTopics() {
    return {
      'id': id,
      'plan_id': plan_id,
      'subject': subject,
      'color': color,
      'total_topics_count': total_topics_count,
      'import_source': import_source,
      'topics': topics.map((t) => t.toMapForBackup()).toList(),
      'lastModified': lastModified,
    };
  }

  Subject copyWith({
    String? id,
    String? plan_id,
    String? subject,
    List<Topic>? topics,
    String? color,
    int? total_topics_count,
    String? import_source,
    int? lastModified,
  }) {
    return Subject(
      id: id ?? this.id,
      plan_id: plan_id ?? this.plan_id,
      subject: subject ?? this.subject,
      topics: topics ?? this.topics,
      color: color ?? this.color,
      total_topics_count: total_topics_count ?? this.total_topics_count,
      import_source: import_source ?? this.import_source,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subject && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class StudySession {
  final String id;
  final String subject;
  final String subjectId;
  final int duration;
  final String color;

  StudySession({
    required this.id,
    required this.subject,
    required this.subjectId,
    required this.duration,
    required this.color,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'],
      subject: json['subject'],
      subjectId: json['subjectId'],
      duration: json['duration'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'subjectId': subjectId,
      'duration': duration,
      'color': color,
    };
  }
}

class StudyRecord {
  final String id;
  final String userId;
  final String plan_id;
  final String date;
  final String subject_id;
  final String category;
  final int study_time;
  final List<TopicProgress>
  topicsProgress; // NOVO: Lista de progresso por tópico
  final List<String> review_periods;
  final bool count_in_planning;
  final int lastModified;

  StudyRecord({
    required this.id,
    required this.userId,
    required this.plan_id,
    required this.date,
    required this.subject_id,
    required this.category,
    required this.study_time,
    this.topicsProgress = const [], // NOVO
    required this.review_periods,
    required this.count_in_planning,
    required this.lastModified,
  });

  factory StudyRecord.fromMap(Map<String, dynamic> map) {
    return StudyRecord(
      id: map['id'],
      userId: map['userId'],
      plan_id: map['plan_id'],
      date: map['date'],
      subject_id: map['subject_id'],
      category: map['category'],
      study_time: map['study_time'],
      topicsProgress:
          (jsonDecode(map['topicsProgress'] ?? '[]') as List<dynamic>)
              .map((e) => TopicProgress.fromMap(e as Map<String, dynamic>))
              .toList(), // NOVO
      review_periods: List<String>.from(
        jsonDecode(map['review_periods'] ?? '[]'),
      ),
      count_in_planning: map['count_in_planning'] == 1,
      lastModified:
          map['lastModified'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'plan_id': plan_id,
      'date': date,
      'subject_id': subject_id,
      'category': category,
      'study_time': study_time,
      'topicsProgress': jsonEncode(
        topicsProgress.map((e) => e.toMap()).toList(),
      ),
      'review_periods': jsonEncode(review_periods),
      'count_in_planning': count_in_planning ? 1 : 0,
      'lastModified': lastModified,
    };
  }

  StudyRecord copyWith({
    String? id,
    String? userId,
    String? plan_id,
    String? date,
    String? subject_id,
    String? category,
    int? study_time,
    List<TopicProgress>? topicsProgress, // NOVO
    List<String>? review_periods,
    bool? count_in_planning,
    int? lastModified,
  }) {
    return StudyRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan_id: plan_id ?? this.plan_id,
      date: date ?? this.date,
      subject_id: subject_id ?? this.subject_id,
      category: category ?? this.category,
      study_time: study_time ?? this.study_time,
      topicsProgress: topicsProgress ?? this.topicsProgress, // NOVO
      review_periods: review_periods ?? this.review_periods,
      count_in_planning: count_in_planning ?? this.count_in_planning,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

class SubjectSettings {
  final int importance;
  final int knowledge;

  SubjectSettings({required this.importance, required this.knowledge});

  factory SubjectSettings.fromJson(Map<String, dynamic> json) {
    return SubjectSettings(
      importance: json['importance'],
      knowledge: json['knowledge'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'importance': importance, 'knowledge': knowledge};
  }
}

class Plan {
  final String id;
  final String name;
  final String? observations;
  final String? cargo;
  final String? edital;
  final String? banca;
  final String? iconUrl;
  final List<Subject>? subjects; // Adicionado
  final int lastModified;

  Plan({
    required this.id,
    required this.name,
    this.observations,
    this.cargo,
    this.edital,
    this.banca,
    this.iconUrl,
    this.subjects, // Adicionado
    required this.lastModified,
  });

  factory Plan.fromMap(Map<String, dynamic> map) {
    return Plan(
      id: map['id'],
      name: map['name'],
      observations: map['observations'],
      cargo: map['cargo'],
      edital: map['edital'],
      banca: map['banca'],
      iconUrl: map['iconUrl'],
      lastModified:
          map['lastModified'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'observations': observations,
      'cargo': cargo,
      'edital': edital,
      'banca': banca,
      'iconUrl': iconUrl,
      'lastModified': lastModified,
    };
  }

  Plan copyWith({
    String? id,
    String? name,
    String? observations,
    String? cargo,
    String? edital,
    String? banca,
    String? iconUrl,
    List<Subject>? subjects,
    int? lastModified,
  }) {
    return Plan(
      id: id ?? this.id,
      name: name ?? this.name,
      observations: observations ?? this.observations,
      cargo: cargo ?? this.cargo,
      edital: edital ?? this.edital,
      banca: banca ?? this.banca,
      iconUrl: iconUrl ?? this.iconUrl,
      subjects: subjects ?? this.subjects,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

class ReviewRecord {
  final String id;
  final String userId;
  final String plan_id;
  final String study_record_id;
  final String scheduled_date;
  final String status;
  final String original_date;
  final String? subject_id;
  final List<String> topics;
  final String review_period;
  final String? completed_date;
  final bool ignored;
  final int lastModified;

  ReviewRecord({
    required this.id,
    required this.userId,
    required this.plan_id,
    required this.study_record_id,
    required this.scheduled_date,
    required this.status,
    required this.original_date,
    this.subject_id,
    required this.topics,
    required this.review_period,
    this.completed_date,
    this.ignored = false,
    required this.lastModified,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'plan_id': plan_id,
      'study_record_id': study_record_id,
      'scheduled_date': scheduled_date,
      'status': status,
      'original_date': original_date,
      'subject_id': subject_id,
      'topics': jsonEncode(topics),
      'review_period': review_period,
      'completed_date': completed_date,
      'ignored': ignored ? 1 : 0,
      'lastModified': lastModified,
    };
  }

  factory ReviewRecord.fromMap(Map<String, dynamic> map) {
    // Adicionado para compatibilidade retroativa
    List<String> topicsList = [];
    if (map['topics'] != null) {
      final decoded = jsonDecode(map['topics']);
      if (decoded is List) {
        topicsList = List<String>.from(decoded);
      }
    } else if (map['topic'] != null) {
      // Se 'topics' não existir, tenta usar o campo antigo 'topic'
      topicsList = [map['topic'] as String];
    }

    return ReviewRecord(
      id: map['id'],
      userId: map['userId'],
      plan_id: map['plan_id'],
      study_record_id: map['study_record_id'],
      scheduled_date: map['scheduled_date'],
      status: map['status'],
      original_date: map['original_date'],
      subject_id: map['subject_id'],
      topics: topicsList,
      review_period: map['review_period'],
      completed_date: map['completed_date'],
      ignored: map['ignored'] == 1,
      lastModified:
          map['lastModified'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  ReviewRecord copyWith({
    String? id,
    String? userId,
    String? plan_id,
    String? study_record_id,
    String? scheduled_date,
    String? status,
    String? original_date,
    String? subject_id,
    List<String>? topics,
    String? review_period,
    String? completed_date,
    bool? ignored,
    int? lastModified,
  }) {
    return ReviewRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan_id: plan_id ?? this.plan_id,
      study_record_id: study_record_id ?? this.study_record_id,
      scheduled_date: scheduled_date ?? this.scheduled_date,
      status: status ?? this.status,
      original_date: original_date ?? this.original_date,
      subject_id: subject_id ?? this.subject_id,
      topics: topics ?? this.topics,
      review_period: review_period ?? this.review_period,
      completed_date: completed_date ?? this.completed_date,
      ignored: ignored ?? this.ignored,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

class SimuladoSubject {
  final int? id;
  final String simulado_record_id;
  final String subject_id;
  final String subject_name;
  final double weight;
  final int total_questions;
  final int correct;
  final int incorrect;
  final String color;
  final int? lastModified;

  SimuladoSubject({
    this.id,
    required this.simulado_record_id,
    required this.subject_id,
    required this.subject_name,
    required this.weight,
    required this.total_questions,
    required this.correct,
    required this.incorrect,
    required this.color,
    this.lastModified,
  });

  factory SimuladoSubject.fromMap(Map<String, dynamic> map) {
    return SimuladoSubject(
      id: map['id'],
      simulado_record_id: map['simulado_record_id'],
      subject_id: map['subject_id'],
      subject_name: map['subject_name'],
      weight: map['weight'],
      total_questions: map['total_questions'],
      correct: map['correct'],
      incorrect: map['incorrect'],
      color: map['color'],
      lastModified:
          map['lastModified'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'simulado_record_id': simulado_record_id,
      'subject_id': subject_id,
      'subject_name': subject_name,
      'weight': weight,
      'total_questions': total_questions,
      'correct': correct,
      'incorrect': incorrect,
      'color': color,
      'lastModified': lastModified,
    };
  }

  SimuladoSubject copyWith({
    int? id,
    String? simulado_record_id,
    String? subject_id,
    String? subject_name,
    double? weight,
    int? total_questions,
    int? correct,
    int? incorrect,
    String? color,
    int? lastModified,
  }) {
    return SimuladoSubject(
      id: id ?? this.id,
      simulado_record_id: simulado_record_id ?? this.simulado_record_id,
      subject_id: subject_id ?? this.subject_id,
      subject_name: subject_name ?? this.subject_name,
      weight: weight ?? this.weight,
      total_questions: total_questions ?? this.total_questions,
      correct: correct ?? this.correct,
      incorrect: incorrect ?? this.incorrect,
      color: color ?? this.color,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

class SimuladoRecord {
  final String id;
  final String userId;
  final String plan_id;
  final String date;
  final String name;
  final String? style;
  final String? banca;
  final String? time_spent;
  final String? comments;
  final List<SimuladoSubject> subjects;
  final int lastModified;

  SimuladoRecord({
    required this.id,
    required this.userId,
    required this.plan_id,
    required this.date,
    required this.name,
    this.style,
    this.banca,
    this.time_spent,
    this.comments,
    required this.subjects,
    required this.lastModified,
  });

  factory SimuladoRecord.fromMap(
    Map<String, dynamic> map,
    List<SimuladoSubject> subjects,
  ) {
    return SimuladoRecord(
      id: map['id'],
      userId: map['userId'],
      plan_id: map['plan_id'],
      date: map['date'],
      name: map['name'],
      style: map['style'],
      banca: map['banca'],
      time_spent: map['time_spent'],
      comments: map['comments'],
      subjects: subjects,
      lastModified:
          map['lastModified'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'plan_id': plan_id,
      'date': date,
      'name': name,
      'style': style,
      'banca': banca,
      'time_spent': time_spent,
      'comments': comments,
      'subjects': subjects.map((s) => s.toMap()).toList(),
      'lastModified': lastModified,
    };
  }

  SimuladoRecord copyWith({
    String? id,
    String? userId,
    String? plan_id,
    String? date,
    String? name,
    String? style,
    String? banca,
    String? time_spent,
    String? comments,
    List<SimuladoSubject>? subjects,
    int? lastModified,
  }) {
    return SimuladoRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan_id: plan_id ?? this.plan_id,
      date: date ?? this.date,
      name: name ?? this.name,
      style: style ?? this.style,
      banca: banca ?? this.banca,
      time_spent: time_spent ?? this.time_spent,
      comments: comments ?? this.comments,
      subjects: subjects ?? this.subjects,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

class SubjectPerformanceData {
  final Subject subject;
  final int correctQuestions;
  final int totalQuestions;

  SubjectPerformanceData({
    required this.subject,
    required this.correctQuestions,
    required this.totalQuestions,
  });

  double get correctPercentage =>
      totalQuestions > 0 ? (correctQuestions / totalQuestions) * 100 : 0.0;
  double get incorrectPercentage => totalQuestions > 0
      ? ((totalQuestions - correctQuestions) / totalQuestions) * 100
      : 0.0;
}

class ReminderNote {
  final String id;

  final String text;

  final bool completed;

  ReminderNote({required this.id, required this.text, required this.completed});

  factory ReminderNote.fromJson(Map<String, dynamic> json) {
    return ReminderNote(
      id: json['id'],

      text: json['text'],

      completed: json['completed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'text': text, 'completed': completed};
  }
}

class MasterSubject {
  final int id;

  final String name;

  MasterSubject({required this.id, required this.name});

  factory MasterSubject.fromMap(Map<String, dynamic> map) {
    return MasterSubject(id: map['id'], name: map['name']);
  }
}

class MasterTopic {
  final int id;

  final int masterSubjectId;

  final String name;

  final String? tecId;

  final int? parentId;

  List<MasterTopic> children;

  MasterTopic({
    required this.id,

    required this.masterSubjectId,

    required this.name,

    this.tecId,

    this.parentId,

    this.children = const [],
  });

  factory MasterTopic.fromMap(Map<String, dynamic> map) {
    return MasterTopic(
      id: map['id'],

      masterSubjectId: map['master_subject_id'],

      name: map['name'],

      tecId: map['tec_id'],

      parentId: map['parent_id'],

      children: [], // Inicializado como vazio, será populado depois
    );
  }
}

// Helper para agregar dados de TopicProgress
class AggregatedTopicProgress {
  final int totalQuestions;
  final int correctQuestions;
  final List<Map<String, int>> pages;
  final List<Map<String, String>> videos;
  final bool isTeoriaFinalizada;
  final List<String> topicTexts;
  final String? notes; // Notas agregadas (se houver, pega a primeira não nula)

  AggregatedTopicProgress({
    this.totalQuestions = 0,
    this.correctQuestions = 0,
    this.pages = const [],
    this.videos = const [],
    this.isTeoriaFinalizada = false,
    this.topicTexts = const [],
    this.notes,
  });

  int get incorrectQuestions => totalQuestions - correctQuestions;
  double get performance =>
      totalQuestions > 0 ? (correctQuestions / totalQuestions) * 100 : 0.0;

  factory AggregatedTopicProgress.fromStudyRecord(StudyRecord record) {
    int totalQ = 0;
    int correctQ = 0;
    List<Map<String, int>> allPages = [];
    List<Map<String, String>> allVideos = [];
    bool anyTeoriaFinalizada = false;
    List<String> allTopicTexts = [];
    String? firstNote;

    for (var tp in record.topicsProgress) {
      totalQ += tp.questions['total'] ?? 0;
      correctQ += tp.questions['correct'] ?? 0;
      allPages.addAll(tp.pages);
      allVideos.addAll(tp.videos);
      if (tp.isTheoryFinished) anyTeoriaFinalizada = true;
      allTopicTexts.add(tp.topicText);
      if (firstNote == null && tp.notes != null) firstNote = tp.notes;
    }

    return AggregatedTopicProgress(
      totalQuestions: totalQ,
      correctQuestions: correctQ,
      pages: allPages.toSet().toList(), // Remove duplicatas de páginas
      videos: allVideos.toSet().toList(), // Remove duplicatas de vídeos
      isTeoriaFinalizada: anyTeoriaFinalizada,
      topicTexts: allTopicTexts,
      notes: firstNote,
    );
  }
}
