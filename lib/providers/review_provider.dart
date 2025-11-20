import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';

class ReviewProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService.instance;
  final AuthProvider? _authProvider;
  List<ReviewRecord> _allReviewRecords = [];
  List<ReviewRecord> _pendingReviews = [];
  List<ReviewRecord> _completedReviews = [];
  bool _isLoading = false;

  List<ReviewRecord> get allReviewRecords => _allReviewRecords;
  List<ReviewRecord> get pendingReviews => _pendingReviews;
  List<ReviewRecord> get completedReviews => _completedReviews;
  bool get isLoading => _isLoading;

  ReviewProvider({AuthProvider? authProvider}) : _authProvider = authProvider {
    fetchReviews();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> fetchReviews() async {
    if (_authProvider?.currentUser == null) return;
    _setLoading(true);
    _allReviewRecords = await _dbService.getAllReviewRecords(_authProvider!.currentUser!.name);
    _filterReviews();
    _setLoading(false);
  }

  void _filterReviews() {
    final now = DateTime.now();
    _pendingReviews = _allReviewRecords.where((record) {
      final scheduledDate = DateTime.parse(record.scheduled_date);
      return record.status == 'pending' && scheduledDate.isBefore(now.add(const Duration(days: 1)));
    }).toList();
    _completedReviews = _allReviewRecords.where((record) => record.status == 'completed').toList();
  }

  Future<void> addReview(ReviewRecord record) async {
    if (_authProvider?.currentUser == null) return;
    await _dbService.createReviewRecord(record, _authProvider!.currentUser!.name);
    await fetchReviews();
  }

  Future<void> updateReview(ReviewRecord record) async {
    if (_authProvider?.currentUser == null) return;
    await _dbService.updateReviewRecord(record, _authProvider!.currentUser!.name);
    await fetchReviews();
  }

  Future<void> deleteReview(String id) async {
    if (_authProvider?.currentUser == null) return;
    await _dbService.deleteReviewRecord(id, _authProvider!.currentUser!.name);
    await fetchReviews();
  }

  Future<void> deleteReviewsForStudyRecord(String studyRecordId) async {
    if (_authProvider?.currentUser == null) return;
    final reviewsToDelete = await _dbService.readReviewRecordsForStudyRecord(studyRecordId, _authProvider!.currentUser!.name);
    for (var review in reviewsToDelete) {
      await _dbService.deleteReviewRecord(review.id, _authProvider!.currentUser!.name);
    }
    await fetchReviews();
  }

  Future<void> markReviewAsCompleted(ReviewRecord record) async {
    if (_authProvider?.currentUser == null) return;
    final updatedRecord = record.copyWith(
      status: 'completed',
      completed_date: DateTime.now().toIso8601String(),
    );
    await _dbService.updateReviewRecord(updatedRecord, _authProvider!.currentUser!.name);
    await fetchReviews();
  }

  Future<void> ignoreReview(ReviewRecord record) async {
    if (_authProvider?.currentUser == null) return;
    final updatedRecord = record.copyWith(
      ignored: true,
    );
    await _dbService.updateReviewRecord(updatedRecord, _authProvider!.currentUser!.name);
    await fetchReviews();
  }

  Future<void> scheduleNextReview(ReviewRecord originalRecord, int daysToAdd) async {
    if (_authProvider?.currentUser == null) return;
    final originalScheduledDate = DateTime.parse(originalRecord.scheduled_date);
    final newScheduledDate = originalScheduledDate.add(Duration(days: daysToAdd));

    final newReviewRecord = originalRecord.copyWith(
      id: const Uuid().v4(),
      scheduled_date: newScheduledDate.toIso8601String(),
      status: 'pending',
      completed_date: null,
      ignored: false,
    );
    await _dbService.createReviewRecord(newReviewRecord, _authProvider!.currentUser!.name);
    await fetchReviews();
  }

  // Helper to get reviews for a specific study record
  Future<List<ReviewRecord>> getReviewsForStudyRecord(String studyRecordId) async {
    if (_authProvider?.currentUser == null) return [];
    return await _dbService.readReviewRecordsForStudyRecord(studyRecordId, _authProvider!.currentUser!.name);
  }

  // Helper to get reviews for a specific plan
  Future<List<ReviewRecord>> getReviewsForPlan(String planId) async {
    if (_authProvider?.currentUser == null) return [];
    return await _dbService.readReviewRecordsForPlan(planId, _authProvider!.currentUser!.name);
  }
}
