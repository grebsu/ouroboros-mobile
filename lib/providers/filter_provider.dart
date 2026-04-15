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
  DateTime? get historyStartDate => _historyFilters['startDate'] as DateTime?;
  DateTime? get historyEndDate => _historyFilters['endDate'] as DateTime?;
  int? get historyMinDuration => _historyFilters['minDuration'] as int?;
  int? get historyMaxDuration => _historyFilters['maxDuration'] as int?;
  double? get historyMinPerformance => _historyFilters['minPerformance'] as double?;
  double? get historyMaxPerformance => _historyFilters['maxPerformance'] as double?;
  List<String> get historySelectedCategories =>
      (_historyFilters['categories'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get historySelectedSubjects =>
      (_historyFilters['subjects'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get historySelectedTopics =>
      (_historyFilters['topics'] as List<dynamic>?)?.cast<String>() ?? [];

  // Getters for stats filters
  DateTime? get statsStartDate => _statsFilters['startDate'] as DateTime?;
  DateTime? get statsEndDate => _statsFilters['endDate'] as DateTime?;
  int? get statsMinDuration => _statsFilters['minDuration'] as int?;
  int? get statsMaxDuration => _statsFilters['maxDuration'] as int?;
  double? get statsMinPerformance => _statsFilters['minPerformance'] as double?;
  double? get statsMaxPerformance => _statsFilters['maxPerformance'] as double?;
  List<String> get statsSelectedCategories =>
      (_statsFilters['categories'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get statsSelectedSubjects =>
      (_statsFilters['subjects'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get statsSelectedTopics =>
      (_statsFilters['topics'] as List<dynamic>?)?.cast<String>() ?? [];
}
