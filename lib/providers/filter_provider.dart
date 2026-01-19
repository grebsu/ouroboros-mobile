import 'package:flutter/foundation.dart';

enum FilterScreen { history, stats }

class FilterProvider with ChangeNotifier {
  Map<String, dynamic> _historyFilters = {};
  Map<String, dynamic> _statsFilters = {};

  Map<String, dynamic> get historyFilters => _historyFilters;
  Map<String, dynamic> get statsFilters => _statsFilters;

  void setFilters(FilterScreen screen, Map<String, dynamic> newFilters) {
    if (screen == FilterScreen.history) {
      _historyFilters = newFilters;
    } else {
      _statsFilters = newFilters;
    }
    notifyListeners();
  }

  void clearFilters(FilterScreen screen) {
    if (screen == FilterScreen.history) {
      _historyFilters = {};
    } else {
      _statsFilters = {};
    }
    notifyListeners();
  }

  // Getters for history filters
  DateTime? get historyStartDate => _historyFilters['startDate'];
  DateTime? get historyEndDate => _historyFilters['endDate'];
  int? get historyMinDuration => _historyFilters['minDuration'];
  int? get historyMaxDuration => _historyFilters['maxDuration'];
  double? get historyMinPerformance => _historyFilters['minPerformance'];
  double? get historyMaxPerformance => _historyFilters['maxPerformance'];
  List<String> get historySelectedCategories =>
      _historyFilters['categories'] ?? [];
  List<String> get historySelectedSubjects => _historyFilters['subjects'] ?? [];
  List<String> get historySelectedTopics => _historyFilters['topics'] ?? [];

  // Getters for stats filters
  DateTime? get statsStartDate => _statsFilters['startDate'];
  DateTime? get statsEndDate => _statsFilters['endDate'];
  int? get statsMinDuration => _statsFilters['minDuration'];
  int? get statsMaxDuration => _statsFilters['maxDuration'];
  double? get statsMinPerformance => _statsFilters['minPerformance'];
  double? get statsMaxPerformance => _statsFilters['maxPerformance'];
  List<String> get statsSelectedCategories => _statsFilters['categories'] ?? [];
  List<String> get statsSelectedSubjects => _statsFilters['subjects'] ?? [];
  List<String> get statsSelectedTopics => _statsFilters['topics'] ?? [];
}
