import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';

class SubjectProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService.instance;
  final AuthProvider? _authProvider;
  List<Subject> _subjects = [];
  bool _isLoading = false;

  List<Subject> get subjects => _subjects;
  bool get isLoading => _isLoading;

  SubjectProvider({AuthProvider? authProvider}) : _authProvider = authProvider;

  Future<void> fetchSubjects(String planId) async {
    if (_authProvider?.currentUser == null) return;
    _isLoading = true;
    notifyListeners();
    _subjects = await _dbService.readSubjectsForPlan(
      planId,
      _authProvider!.currentUser!.name,
    );
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addSubject(Subject newSubject) async {
    if (_authProvider?.currentUser == null) return;
    await _dbService.createSubject(
      newSubject,
      _authProvider!.currentUser!.name,
    );
    // Assuming newSubject has planId, refetch for that plan
    await fetchSubjects(newSubject.plan_id);
  }

  Future<void> updateSubject(Subject subject) async {
    if (_authProvider?.currentUser == null) return;
    await _dbService.updateSubject(subject, _authProvider!.currentUser!.name);
    await fetchSubjects(subject.plan_id);
  }

  Future<void> deleteSubject(String subjectId, String planId) async {
    if (_authProvider?.currentUser == null) return;
    await _dbService.deleteSubject(subjectId, _authProvider!.currentUser!.name);
    await fetchSubjects(planId);
  }
}
