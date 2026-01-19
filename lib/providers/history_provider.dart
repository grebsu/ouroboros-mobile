import 'package:flutter/foundation.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:uuid/uuid.dart';
import 'package:ouroboros_mobile/providers/review_provider.dart';
import 'package:ouroboros_mobile/providers/filter_provider.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';

class HistoryProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService.instance;
  final ReviewProvider _reviewProvider;
  final FilterProvider _filterProvider;
  final AuthProvider? _authProvider;

  HistoryProvider(
    this._reviewProvider,
    this._filterProvider,
    this._authProvider,
  ) {
    _filterProvider.addListener(fetchHistory);
    fetchHistory();
  }

  List<StudyRecord> _records = [];
  List<StudyRecord> _allStudyRecords = [];
  Map<String, Subject> _allSubjectsMap = {};
  bool _isLoading = false;
  bool _isDisposed = false;

  List<StudyRecord> get records => _records;
  List<StudyRecord> get allStudyRecords => _allStudyRecords;
  List<String> get availableCategories {
    final List<String> categories = [
      'Teoria',
      'Revisão',
      'Questões',
      'Leitura de lei',
      'Jurisprudência',
    ];
    return categories;
  }

  Map<String, Subject> get allSubjectsMap => _allSubjectsMap;
  bool get isLoading => _isLoading;

  @override
  void dispose() {
    _isDisposed = true;
    _filterProvider.removeListener(fetchHistory);
    super.dispose();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> fetchHistory() async {
    if (_authProvider?.currentUser == null) return;
    print('HistoryProvider: Iniciando fetchHistory...');
    _setLoading(true);
    _allStudyRecords = await _dbService.readStudyRecordsForUser(
      _authProvider!.currentUser!.name,
    );
    List<Subject> allSubjects = await _dbService.readAllSubjects(
      _authProvider!.currentUser!.name,
    );

    _allSubjectsMap = {for (var s in allSubjects) s.id: s};
    print(
      'HistoryProvider: Registros de estudo lidos: ${_allStudyRecords.length}',
    );
    print('HistoryProvider: Todas as disciplinas lidas: ${allSubjects.length}');

    // Apply filters
    _records = _allStudyRecords.where((record) {
      // Date filter
      if (_filterProvider.historyStartDate != null &&
          DateTime.parse(
            record.date,
          ).isBefore(_filterProvider.historyStartDate!)) {
        return false;
      }
      if (_filterProvider.historyEndDate != null &&
          DateTime.parse(
            record.date,
          ).isAfter(_filterProvider.historyEndDate!)) {
        return false;
      }

      // Duration filter
      if (_filterProvider.historyMinDuration != null &&
          record.study_time < _filterProvider.historyMinDuration! * 60000) {
        // convert minutes to ms
        return false;
      }
      if (_filterProvider.historyMaxDuration != null &&
          record.study_time > _filterProvider.historyMaxDuration! * 60000) {
        return false;
      }

      // Performance filter (agregando de topicsProgress)
      int totalQuestionsSum = 0;
      int correctQuestionsSum = 0;
      for (var tp in record.topicsProgress) {
        totalQuestionsSum += tp.questions['total'] ?? 0;
        correctQuestionsSum += tp.questions['correct'] ?? 0;
      }
      final performance = totalQuestionsSum > 0
          ? (correctQuestionsSum / totalQuestionsSum) * 100
          : 0.0;
      if (_filterProvider.historyMinPerformance != null &&
          performance < _filterProvider.historyMinPerformance!) {
        return false;
      }
      if (_filterProvider.historyMaxPerformance != null &&
          performance > _filterProvider.historyMaxPerformance!) {
        return false;
      }

      // Category filter
      if (_filterProvider.historySelectedCategories.isNotEmpty &&
          !_filterProvider.historySelectedCategories.contains(
            record.category,
          )) {
        return false;
      }

      // Subject filter
      if (_filterProvider.historySelectedSubjects.isNotEmpty) {
        final subject = _allSubjectsMap[record.subject_id];
        if (subject == null ||
            !_filterProvider.historySelectedSubjects.contains(
              subject.subject,
            )) {
          return false;
        }
      }

      // Topic filter (agregando de topicsProgress)
      if (_filterProvider.historySelectedTopics.isNotEmpty) {
        bool topicMatch = false;
        for (var tp in record.topicsProgress) {
          if (_filterProvider.historySelectedTopics.contains(tp.topicText)) {
            topicMatch = true;
            break;
          }
        }
        if (!topicMatch) {
          return false;
        }
      }

      return true;
    }).toList();
    print('HistoryProvider: Registros filtrados: ${_records.length}');

    _setLoading(false);
    print('HistoryProvider: fetchHistory concluído.');
  }

  Future<void> addStudyRecord(StudyRecord record) async {
    if (_authProvider?.currentUser == null) return;
    _setLoading(true);
    try {
      final recordWithUser = record.copyWith(
        userId: _authProvider!.currentUser!.name,
        lastModified: DateTime.now().millisecondsSinceEpoch,
      );
      await _dbService.createStudyRecord(recordWithUser);

      final newReviewRecords = _generateReviewRecords(recordWithUser);
      for (var review in newReviewRecords) {
        await _reviewProvider.addReview(review);
      }
    } finally {
      await fetchHistory(); // Refresh the list
    }
  }

  Future<void> updateStudyRecord(StudyRecord record) async {
    if (_authProvider?.currentUser == null) return;
    _setLoading(true);
    try {
      // 1. Obter e excluir os ReviewRecords antigos associados a este StudyRecord
      final oldReviewRecords = await _dbService.readReviewRecordsForStudyRecord(
        record.id,
        _authProvider!.currentUser!.name,
      );
      for (var oldReview in oldReviewRecords) {
        await _reviewProvider.deleteReview(oldReview.id);
      }

      final recordWithUser = record.copyWith(
        userId: _authProvider!.currentUser!.name,
        lastModified: DateTime.now().millisecondsSinceEpoch,
      );
      await _dbService.updateStudyRecord(recordWithUser);

      // 2. Gerar e adicionar os novos ReviewRecords
      final newReviewRecords = _generateReviewRecords(recordWithUser);
      for (var review in newReviewRecords) {
        await _reviewProvider.addReview(review);
      }
    } finally {
      await fetchHistory(); // Refresh the list
    }
  }

  Future<void> toggleTopicCompletion({
    required String subjectId,
    required String topicText,
    required String planId,
  }) async {
    if (_authProvider?.currentUser == null) return;
    _setLoading(true);
    try {
      final allRecords = await _dbService.readStudyRecordsForUser(
        _authProvider!.currentUser!.name,
      );
      StudyRecord? existingRecord;

      // Encontrar o StudyRecord que contém o TopicProgress correspondente
      for (var record in allRecords) {
        if (record.subject_id == subjectId) {
          for (var tp in record.topicsProgress) {
            if (tp.topicText == topicText) {
              existingRecord = record;
              break;
            }
          }
        }
        if (existingRecord != null) break;
      }

      if (existingRecord != null) {
        // Encontrar o TopicProgress específico e modificar isTheoryFinished
        final List<TopicProgress> updatedTopicsProgress = existingRecord
            .topicsProgress
            .map((tp) {
              if (tp.topicText == topicText) {
                return tp.copyWith(isTheoryFinished: !tp.isTheoryFinished);
              }
              return tp;
            })
            .toList();

        final recordToSave = existingRecord.copyWith(
          topicsProgress: updatedTopicsProgress,
          lastModified: DateTime.now().millisecondsSinceEpoch,
        );
        await _dbService.updateStudyRecord(recordToSave);
      } else {
        // Se não existir, criar um novo StudyRecord com o TopicProgress
        // Note: Neste cenário, um StudyRecord tem APENAS um TopicProgress se for para toggling de um único tópico.
        final newTopicProgress = TopicProgress(
          topicId: Uuid().v4(), // Será um novo ID para o TopicProgress
          topicText: topicText,
          isTheoryFinished:
              true, // Se estamos toggling para completar, começa como true
        );

        final newRecord = StudyRecord(
          id: Uuid().v4(),
          userId: _authProvider!.currentUser!.name,
          plan_id: planId,
          date: DateTime.now().toIso8601String(),
          subject_id: subjectId,
          category: 'teoria', // Default
          study_time: 0, // Default
          topicsProgress: [newTopicProgress],
          review_periods: [],
          count_in_planning: false,
          lastModified: DateTime.now().millisecondsSinceEpoch,
        );
        await _dbService.createStudyRecord(newRecord);
      }
    } finally {
      await fetchHistory();
    }
  }

  Future<void> deleteStudyRecord(String id) async {
    if (_authProvider?.currentUser == null) return;
    _setLoading(true);
    try {
      // 1. Excluir os ReviewRecords associados
      await _reviewProvider.deleteReviewsForStudyRecord(id);

      // 2. Excluir o StudyRecord
      await _dbService.deleteStudyRecord(id);
    } finally {
      await fetchHistory(); // Refresh the list
    }
  }

  List<ReviewRecord> _generateReviewRecords(StudyRecord studyRecord) {
    final List<ReviewRecord> newReviewRecords = [];
    if (studyRecord.review_periods.isNotEmpty) {
      studyRecord.review_periods.forEach((period) {
        final originalDate = DateTime.parse(studyRecord.date);
        DateTime scheduledDate = originalDate;

        if (period.endsWith('d')) {
          scheduledDate = originalDate.add(
            Duration(days: int.parse(period.replaceAll('d', ''))),
          );
        } else if (period.endsWith('w')) {
          scheduledDate = originalDate.add(
            Duration(days: int.parse(period.replaceAll('w', '')) * 7),
          );
        } else if (period.endsWith('m')) {
          scheduledDate = DateTime(
            originalDate.year,
            originalDate.month + int.parse(period.replaceAll('m', '')),
            originalDate.day,
          );
        }

        newReviewRecords.add(
          ReviewRecord(
            id: const Uuid().v4(),
            userId: _authProvider!.currentUser!.name,
            plan_id: studyRecord.plan_id,
            study_record_id: studyRecord.id,
            scheduled_date: scheduledDate.toIso8601String().split('T')[0],
            status: 'pending',
            original_date: studyRecord.date,
            subject_id: studyRecord.subject_id,
            // O ReviewRecord agora espera uma lista de tópicos.
            // Precisamos coletar os topicText de todos os TopicProgress
            topics: studyRecord.topicsProgress
                .map((tp) => tp.topicText)
                .toList(),
            review_period: period,
            completed_date: null,
            ignored: false,
            lastModified: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      });
    }
    return newReviewRecords;
  }
}
