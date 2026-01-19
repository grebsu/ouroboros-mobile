import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'dart:collection';

class SimuladosProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService.instance;
  final AuthProvider? _authProvider;
  List<SimuladoRecord> _simulados = [];
  bool _isLoading = false;

  SimuladosProvider({AuthProvider? authProvider})
    : _authProvider = authProvider {
    fetchSimulados();
  }

  UnmodifiableListView<SimuladoRecord> get simulados =>
      UnmodifiableListView(_simulados);
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> fetchSimulados() async {
    if (_authProvider?.currentUser == null) return;
    _setLoading(true);
    _simulados = await _dbService.readAllSimuladoRecordsForUser(
      _authProvider!.currentUser!.name,
    );
    _setLoading(false);
  }

  Future<void> addSimulado(SimuladoRecord simulado) async {
    if (_authProvider?.currentUser == null) return;
    final newSimulado = simulado.copyWith(
      userId: _authProvider!.currentUser!.name,
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );
    await _dbService.createSimuladoRecord(
      newSimulado,
      _authProvider!.currentUser!.name,
    );
    await fetchSimulados();
  }

  Future<void> updateSimulado(SimuladoRecord simulado) async {
    if (_authProvider?.currentUser == null) return;
    final updatedSimulado = simulado.copyWith(
      lastModified: DateTime.now().millisecondsSinceEpoch,
    );
    await _dbService.updateSimuladoRecord(
      updatedSimulado,
      _authProvider!.currentUser!.name,
    );
    await fetchSimulados();
  }

  Future<void> deleteSimulado(String id) async {
    if (_authProvider?.currentUser == null) return;
    await _dbService.deleteSimuladoRecord(id, _authProvider!.currentUser!.name);
    await fetchSimulados();
  }
}
