import 'dart:io'; // Importar dart:io para operações de arquivo
import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:uuid/uuid.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:path_provider/path_provider.dart'; // Importar path_provider

class PlansProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService.instance;
  final AuthProvider? _authProvider;
  List<Plan> _plans = [];
  Map<String, ({int subjectCount, int topicCount})> _planStats = {};
  bool _isLoading = false;

  List<Plan> get plans => _plans;
  Map<String, ({int subjectCount, int topicCount})> get planStats => _planStats;
  bool get isLoading => _isLoading;

  PlansProvider({AuthProvider? authProvider}) : _authProvider = authProvider {
    fetchPlans();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> fetchPlans() async {
    if (_authProvider?.currentUser == null) return;
    print('PlansProvider: Iniciando fetchPlans...');
    _setLoading(true);
    try {
      _plans = await _dbService.readAllPlans(_authProvider!.currentUser!.name);
      print('PlansProvider: Planos lidos: ${_plans.length}');
      
      // Helper to count only leaf topics
      int _countLeafTopics(List<Topic> topics) {
        int count = 0;
        for (final topic in topics) {
          if (topic.sub_topics == null || topic.sub_topics!.isEmpty) {
            count++;
          } else {
            count += _countLeafTopics(topic.sub_topics!);
          }
        }
        return count;
      }

      // Fetch stats for each plan
      final newStats = <String, ({int subjectCount, int topicCount})>{};
      for (final plan in _plans) {
        final subjects = await _dbService.readSubjectsForPlan(plan.id, _authProvider!.currentUser!.name);
        int totalLeafTopics = 0;
        for (final subject in subjects) {
          totalLeafTopics += _countLeafTopics(subject.topics);
        }
        newStats[plan.id] = (subjectCount: subjects.length, topicCount: totalLeafTopics);
      }
      _planStats = newStats;
    } finally {
      _setLoading(false);
    }
  }

  Future<Plan?> getPlanByName(String name) async {
    if (_authProvider?.currentUser == null) return null;
    try {
      return _plans.firstWhere((plan) => plan.name == name);
    } catch (e) {
      return null;
    }
  }

  Future<Plan> addPlan({
    required String name,
    String? observations,
    String? cargo,
    String? edital,
    String? banca,
    String? iconUrl,
  }) async {
    if (_authProvider?.currentUser == null) throw Exception('Usuário não logado');
    final newPlan = Plan(
      id: const Uuid().v4(),
      name: name,
      observations: observations,
      cargo: cargo,
      edital: edital,
      banca: banca,
      iconUrl: iconUrl,
    );
    
    _setLoading(true);
    await _dbService.createPlan(newPlan, _authProvider!.currentUser!.name);
    await fetchPlans(); // Atualiza a lista de planos após a criação
    _setLoading(false);
    return newPlan;
  }

  Future<void> updatePlan(Plan plan) async {
    if (_authProvider?.currentUser == null) return;
    _setLoading(true);
    await _dbService.updatePlan(plan, _authProvider!.currentUser!.name);
    await fetchPlans(); // Refresh the list and stats
  }

  Future<void> deletePlan(String id) async {
    if (_authProvider?.currentUser == null) return;
    _setLoading(true);

    // Retrieve the plan to get its iconUrl before deleting from DB
    final planToDelete = _plans.firstWhere((plan) => plan.id == id);
    if (planToDelete.iconUrl != null && planToDelete.iconUrl!.isNotEmpty) {
      try {
        final file = File(planToDelete.iconUrl!);
        if (await file.exists()) {
          await file.delete();
          print('PlansProvider: Imagem ${planToDelete.iconUrl} deletada com sucesso.');
        }
      } catch (e) {
        print('PlansProvider: Erro ao deletar imagem ${planToDelete.iconUrl}: $e');
        // Decide how to handle the error (e.g., log it, show a message, or ignore if not critical)
      }
    }

    await _dbService.deletePlan(id, _authProvider!.currentUser!.name);
    await fetchPlans(); // Refresh the list and stats
  }
}
