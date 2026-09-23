import 'dart:convert';

class Question {
  final String id;
  final int masterSubjectId;
  final int? masterTopicId;
  final String enunciado;
  final List<String> alternativas; // parsed from JSON string
  final String gabarito;
  final String? comentarioProfessor;
  final String? comentarioForum;
  final String? banca;
  final String? ano;
  final String? orgao;
  final int? lastModified;

  Question({
    required this.id,
    required this.masterSubjectId,
    this.masterTopicId,
    required this.enunciado,
    required this.alternativas,
    required this.gabarito,
    this.comentarioProfessor,
    this.comentarioForum,
    this.banca,
    this.ano,
    this.orgao,
    this.lastModified,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    List<String> alts = [];
    try {
      final decoded = jsonDecode(map['alternativas'] as String);
      if (decoded is List) {
        alts = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return Question(
      id: map['id'] as String,
      masterSubjectId: map['master_subject_id'] as int,
      masterTopicId: map['master_topic_id'] as int?,
      enunciado: map['enunciado'] as String,
      alternativas: alts,
      gabarito: map['gabarito'] as String,
      comentarioProfessor: map['comentario_professor'] as String?,
      comentarioForum: map['comentario_forum'] as String?,
      banca: map['banca'] as String?,
      ano: map['ano'] as String?,
      orgao: map['orgao'] as String?,
      lastModified: map['lastModified'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'master_subject_id': masterSubjectId,
      'master_topic_id': masterTopicId,
      'enunciado': enunciado,
      'alternativas': jsonEncode(alternativas),
      'gabarito': gabarito,
      'comentario_professor': comentarioProfessor,
      'comentario_forum': comentarioForum,
      'banca': banca,
      'ano': ano,
      'orgao': orgao,
      'lastModified': lastModified ?? DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class UserQuestionResponse {
  final String id;
  final String userId;
  final String questionId;
  final String? selectedAlternative;
  final bool isCorrect;
  final String answeredAt;
  final int? lastModified;

  UserQuestionResponse({
    required this.id,
    required this.userId,
    required this.questionId,
    this.selectedAlternative,
    required this.isCorrect,
    required this.answeredAt,
    this.lastModified,
  });

  factory UserQuestionResponse.fromMap(Map<String, dynamic> map) {
    return UserQuestionResponse(
      id: map['id'] as String,
      userId: map['userId'] as String,
      questionId: map['question_id'] as String,
      selectedAlternative: map['selected_alternative'] as String?,
      isCorrect: (map['is_correct'] as int) == 1,
      answeredAt: map['answered_at'] as String,
      lastModified: map['lastModified'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'question_id': questionId,
      'selected_alternative': selectedAlternative,
      'is_correct': isCorrect ? 1 : 0,
      'answered_at': answeredAt,
      'lastModified': lastModified ?? DateTime.now().millisecondsSinceEpoch,
    };
  }
}
