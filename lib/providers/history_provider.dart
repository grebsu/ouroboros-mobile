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

  HistoryProvider(this._reviewProvider, this._filterProvider, this._authProvider) {
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
    _allStudyRecords = await _dbService.readStudyRecordsForUser(_authProvider!.currentUser!.name);
    List<Subject> allSubjects = await _dbService.readAllSubjects(_authProvider!.currentUser!.name);

    _allSubjectsMap = { for (var s in allSubjects) s.id: s };
    print('HistoryProvider: Registros de estudo lidos: ${_allStudyRecords.length}');
    print('HistoryProvider: Todas as disciplinas lidas: ${allSubjects.length}');

    // Apply filters
    _records = _allStudyRecords.where((record) {
      // Date filter
      if (_filterProvider.historyStartDate != null && DateTime.parse(record.date).isBefore(_filterProvider.historyStartDate!)) {
        return false;
      }
      if (_filterProvider.historyEndDate != null && DateTime.parse(record.date).isAfter(_filterProvider.historyEndDate!)) {
        return false;
      }

      // Duration filter
      if (_filterProvider.historyMinDuration != null && record.study_time < _filterProvider.historyMinDuration! * 60000) { // convert minutes to ms
        return false;
      }
      if (_filterProvider.historyMaxDuration != null && record.study_time > _filterProvider.historyMaxDuration! * 60000) {
        return false;
      }

      // Performance filter
      final correct = record.questions['correct'] ?? 0;
      final total = record.questions['total'] ?? 0;
      final performance = total > 0 ? (correct / total) * 100 : 0.0;
      if (_filterProvider.historyMinPerformance != null && performance < _filterProvider.historyMinPerformance!) {
        return false;
      }
      if (_filterProvider.historyMaxPerformance != null && performance > _filterProvider.historyMaxPerformance!) {
        return false;
      }

      // Category filter
      if (_filterProvider.historySelectedCategories.isNotEmpty && !_filterProvider.historySelectedCategories.contains(record.category)) {
        return false;
      }

      // Subject filter
      if (_filterProvider.historySelectedSubjects.isNotEmpty) {
        final subject = _allSubjectsMap[record.subject_id];
        if (subject == null || !_filterProvider.historySelectedSubjects.contains(subject.subject)) {
          return false;
        }
      }

      // Topic filter
      if (_filterProvider.historySelectedTopics.isNotEmpty && !_filterProvider.historySelectedTopics.contains(record.topic)) {
        return false;
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
      final recordWithUser = record.copyWith(userId: _authProvider!.currentUser!.name);
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
      final oldReviewRecords = await _dbService.readReviewRecordsForStudyRecord(record.id, _authProvider!.currentUser!.name);
      for (var oldReview in oldReviewRecords) {
        await _reviewProvider.deleteReview(oldReview.id);
      }

      final recordWithUser = record.copyWith(userId: _authProvider!.currentUser!.name);
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

  Future<void> toggleTopicCompletion({required String subjectId, required String topicText, required String planId}) async {
    if (_authProvider?.currentUser == null) return;
    _setLoading(true);
    try {
      final allRecords = await _dbService.readStudyRecordsForUser(_authProvider!.currentUser!.name);
      StudyRecord? existingRecord;
      try {
        existingRecord = allRecords.firstWhere((r) => r.subject_id == subjectId && r.topic == topicText);
      } catch (e) {
        existingRecord = null;
      }

      if (existingRecord != null) {
        final recordToSave = StudyRecord(
          id: existingRecord.id,
          userId: _authProvider!.currentUser!.name,
          plan_id: existingRecord.plan_id,
          date: existingRecord.date,
          subject_id: existingRecord.subject_id,
          topic: existingRecord.topic,
          category: existingRecord.category,
          study_time: existingRecord.study_time,
          questions: existingRecord.questions,
          material: existingRecord.material,
          notes: existingRecord.notes,
          review_periods: existingRecord.review_periods,
          teoria_finalizada: !existingRecord.teoria_finalizada,
          count_in_planning: existingRecord.count_in_planning,
          pages: existingRecord.pages,
          videos: existingRecord.videos,
        );
        await _dbService.updateStudyRecord(recordToSave);
      } else {
        final newRecord = StudyRecord(
          id: Uuid().v4(),
          userId: _authProvider!.currentUser!.name,
          plan_id: planId, // Requires a planId, which is a challenge from the global Edital screen
          date: DateTime.now().toIso8601String(),
          subject_id: subjectId,
          topic: topicText,
          category: 'teoria',
          study_time: 0,
          questions: {'correct': 0, 'total': 0},
          review_periods: [],
          teoria_finalizada: true,
          count_in_planning: false,
          pages: [],
          videos: [],
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
          scheduledDate = originalDate.add(Duration(days: int.parse(period.replaceAll('d', ''))));
        } else if (period.endsWith('w')) {
          scheduledDate = originalDate.add(Duration(days: int.parse(period.replaceAll('w', '')) * 7));
        } else if (period.endsWith('m')) {
          scheduledDate = DateTime(originalDate.year, originalDate.month + int.parse(period.replaceAll('m', '')), originalDate.day);
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
            topic: studyRecord.topic,
            review_period: period,
            completed_date: null,
            ignored: false,
          ),
        );
      });
    }
    return newReviewRecords;
  }
}
