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

enum StudyCategory {
  teoria,
  revisao,
  questoes,
  leituraLei,
  jurisprudencia,
}

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

  Topic({
    this.id,
    this.subject_id, // Tornar opcional
    required this.topic_text,
    this.parent_id,
    this.sub_topics,
    this.is_grouping_topic,
    this.question_count,
    this.userWeight, 
  });

  factory Topic.fromMap(Map<String, dynamic> map) {
    var subTopicsList = map['sub_topics'] as List<dynamic>?;
    List<Topic> subTopics = subTopicsList != null
        ? subTopicsList.map((i) => Topic.fromMap(i)).toList()
        : [];

    return Topic(
      id: map['id'],
      subject_id: map['subject_id'],
      topic_text: map['topic_text'],
      parent_id: map['parent_id'],
      sub_topics: subTopics,
      is_grouping_topic: map['is_grouping_topic'] == 1 || (map['is_grouping_topic'] is bool && map['is_grouping_topic']),
      question_count: map['question_count'],
      userWeight: map['userWeight'], 
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
    );
  }
}class Subject {
  final String id;
  final String plan_id;
  final String subject;
  final List<Topic> topics;
  final String color;
  final int? total_topics_count;
  final String? import_source;

  Subject({
    required this.id,
    required this.plan_id,
    required this.subject,
    required this.topics,
    required this.color,
    this.total_topics_count,
    this.import_source,
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
  }) {
    return Subject(
      id: id ?? this.id,
      plan_id: plan_id ?? this.plan_id,
      subject: subject ?? this.subject,
      topics: topics ?? this.topics,
      color: color ?? this.color,
      total_topics_count: total_topics_count ?? this.total_topics_count,
      import_source: import_source ?? this.import_source,
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
  final String topic;
  final String category;
  final int study_time;
  final Map<String, int> questions;
  final String? material;
  final String? notes;
  final List<String> review_periods;
  final bool teoria_finalizada;
  final bool count_in_planning;
  final List<dynamic> pages;
  final List<dynamic> videos;

  StudyRecord({
    required this.id,
    required this.userId,
    required this.plan_id,
    required this.date,
    required this.subject_id,
    required this.topic,
    required this.category,
    required this.study_time,
    required this.questions,
    this.material,
    this.notes,
    required this.review_periods,
    required this.teoria_finalizada,
    required this.count_in_planning,
    required this.pages,
    required this.videos,
  });

  factory StudyRecord.fromMap(Map<String, dynamic> map) {
    return StudyRecord(
      id: map['id'],
      userId: map['userId'],
      plan_id: map['plan_id'],
      date: map['date'],
      subject_id: map['subject_id'],
      topic: map['topic'],
      category: map['category'],
      study_time: map['study_time'],
      questions: Map<String, int>.from(jsonDecode(map['questions'])),
      material: map['material'],
      notes: map['notes'],
      review_periods: List<String>.from(jsonDecode(map['review_periods'])),
      teoria_finalizada: map['teoria_finalizada'] == 1,
      count_in_planning: map['count_in_planning'] == 1,
      pages: List<dynamic>.from(jsonDecode(map['pages'])),
      videos: List<dynamic>.from(jsonDecode(map['videos'])),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'plan_id': plan_id,
      'date': date,
      'subject_id': subject_id,
      'topic': topic,
      'category': category,
      'study_time': study_time,
      'questions': jsonEncode(questions),
      'material': material,
      'notes': notes,
      'review_periods': jsonEncode(review_periods),
      'teoria_finalizada': teoria_finalizada ? 1 : 0,
      'count_in_planning': count_in_planning ? 1 : 0,
      'pages': jsonEncode(pages),
      'videos': jsonEncode(videos),
    };
  }

  StudyRecord copyWith({
    String? id,
    String? userId,
    String? plan_id,
    String? date,
    String? subject_id,
    String? topic,
    String? category,
    int? study_time,
    Map<String, int>? questions,
    String? material,
    String? notes,
    List<String>? review_periods,
    bool? teoria_finalizada,
    bool? count_in_planning,
    List<dynamic>? pages,
    List<dynamic>? videos,
  }) {
    return StudyRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan_id: plan_id ?? this.plan_id,
      date: date ?? this.date,
      subject_id: subject_id ?? this.subject_id,
      topic: topic ?? this.topic,
      category: category ?? this.category,
      study_time: study_time ?? this.study_time,
      questions: questions ?? this.questions,
      material: material ?? this.material,
      notes: notes ?? this.notes,
      review_periods: review_periods ?? this.review_periods,
      teoria_finalizada: teoria_finalizada ?? this.teoria_finalizada,
      count_in_planning: count_in_planning ?? this.count_in_planning,
      pages: pages ?? this.pages,
      videos: videos ?? this.videos,
    );
  }
}

class SubjectSettings {
  final int importance;
  final int knowledge;

  SubjectSettings({
    required this.importance,
    required this.knowledge,
  });

  factory SubjectSettings.fromJson(Map<String, dynamic> json) {
    return SubjectSettings(
      importance: json['importance'],
      knowledge: json['knowledge'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'importance': importance,
      'knowledge': knowledge,
    };
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

  Plan({
    required this.id,
    required this.name,
    this.observations,
    this.cargo,
    this.edital,
    this.banca,
    this.iconUrl,
    this.subjects, // Adicionado
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
  final String topic;
  final String review_period;
  final String? completed_date;
  final bool ignored;

  ReviewRecord({
    required this.id,
    required this.userId,
    required this.plan_id,
    required this.study_record_id,
    required this.scheduled_date,
    required this.status,
    required this.original_date,
    this.subject_id,
    required this.topic,
    required this.review_period,
    this.completed_date,
    this.ignored = false,
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
      'topic': topic,
      'review_period': review_period,
      'completed_date': completed_date,
      'ignored': ignored ? 1 : 0,
    };
  }

  factory ReviewRecord.fromMap(Map<String, dynamic> map) {
    return ReviewRecord(
      id: map['id'],
      userId: map['userId'],
      plan_id: map['plan_id'],
      study_record_id: map['study_record_id'],
      scheduled_date: map['scheduled_date'],
      status: map['status'],
      original_date: map['original_date'],
      subject_id: map['subject_id'],
      topic: map['topic'],
      review_period: map['review_period'],
      completed_date: map['completed_date'],
      ignored: map['ignored'] == 1,
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
    String? topic,
    String? review_period,
    String? completed_date,
    bool? ignored,
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
      topic: topic ?? this.topic,
      review_period: review_period ?? this.review_period,
      completed_date: completed_date ?? this.completed_date,
      ignored: ignored ?? this.ignored,
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
    };
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
  });

  factory SimuladoRecord.fromMap(Map<String, dynamic> map, List<SimuladoSubject> subjects) {
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
    };
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

  double get correctPercentage => totalQuestions > 0 ? (correctQuestions / totalQuestions) * 100 : 0.0;
  double get incorrectPercentage => totalQuestions > 0 ? ((totalQuestions - correctQuestions) / totalQuestions) * 100 : 0.0;
}

class ReminderNote {
  final String id;
  final String text;
  final bool completed;

  ReminderNote({
    required this.id,
    required this.text,
    required this.completed,
  });

  factory ReminderNote.fromJson(Map<String, dynamic> json) {
    return ReminderNote(
      id: json['id'],
      text: json['text'],
      completed: json['completed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'completed': completed,
    };
  }
}
