import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';

class ActivePlanProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService.instance;
  final AuthProvider? _authProvider;
  Plan? _activePlan;
  List<Plan> _allPlans = [];

  Plan? get activePlan => _activePlan;
  String? get activePlanId => _activePlan?.id;
  List<Plan> get allPlans => _allPlans;

  ActivePlanProvider({AuthProvider? authProvider}) : _authProvider = authProvider {
    _loadActivePlan();
  }

  Future<void> _loadActivePlan() async {
    if (_authProvider?.currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    final activePlanId = prefs.getString('active_plan_id_${_authProvider!.currentUser!.name}');
    print('ActivePlanProvider: _loadActivePlan - activePlanId salvo: $activePlanId');

    // Sempre carrega todos os planos para garantir que _allPlans esteja atualizado
    _allPlans = await _dbService.readAllPlans(_authProvider!.currentUser!.name);
    print('ActivePlanProvider: _loadActivePlan - Planos lidos do DB: ${_allPlans.length}');
    for (var plan in _allPlans) {
      print('ActivePlanProvider: _loadActivePlan - Plano ID no _allPlans: ${plan.id}');
    }

    if (activePlanId != null) {
      try {
        _activePlan = _allPlans.firstWhere((plan) => plan.id == activePlanId);
        print('ActivePlanProvider: _loadActivePlan - Plano ativo encontrado: ${_activePlan?.name}');
      } catch (e) {
        print('ActivePlanProvider: _loadActivePlan - Erro ao encontrar plano ativo salvo: $e');
        // Se o plano salvo não for encontrado (ex: foi excluído), define como null
        _activePlan = null;
        await prefs.remove('active_plan_id_\${_authProvider!.currentUser!.name}'); // Limpa o ID salvo
      }
    } else {
      // Se não houver ID de plano ativo salvo, tenta definir o primeiro plano como ativo
      _activePlan = _allPlans.isNotEmpty ? _allPlans.first : null;
      if (_activePlan != null) {
        print('ActivePlanProvider: _loadActivePlan - Primeiro plano definido como ativo: ${_activePlan?.name}');
      }
    }
    notifyListeners();
  }

  Future<void> setActivePlan(String planId) async {
    if (_authProvider?.currentUser == null) return;
    print('ActivePlanProvider: setActivePlan - Tentando definir plano ID: $planId');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_plan_id_\${_authProvider!.currentUser!.name}', planId);

    // Garante que _allPlans esteja atualizado
    _allPlans = await _dbService.readAllPlans(_authProvider!.currentUser!.name);
    print('ActivePlanProvider: setActivePlan - Planos lidos do DB: ${_allPlans.length}');
    for (var plan in _allPlans) {
      print('ActivePlanProvider: setActivePlan - Plano ID no _allPlans: ${plan.id}');
    }

    try {
      _activePlan = _allPlans.firstWhere((plan) => plan.id == planId);
      print('ActivePlanProvider: setActivePlan - Plano ativo definido: ${_activePlan?.name}');
    } catch (e) {
      print('ActivePlanProvider: setActivePlan - Erro ao encontrar plano com ID $planId: $e');
      // Se o plano não for encontrado (ex: foi excluído), define como null
      _activePlan = null;
      await prefs.remove('active_plan_id_\${_authProvider!.currentUser!.name}'); // Limpa o ID salvo
    }
    notifyListeners();
  }

  Future<void> clearActivePlan() async {
    if (_authProvider?.currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_plan_id_\${_authProvider!.currentUser!.name}');
    _activePlan = null;
    notifyListeners();
  }
}