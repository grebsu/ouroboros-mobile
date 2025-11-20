import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String name;
  final String password;

  User({required this.name, required this.password});
}

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  User? _currentUser;
  final List<User> _users = []; // Lista para armazenar usuários registrados

  bool get isLoggedIn => _isLoggedIn;
  User? get currentUser => _currentUser;

  Future<void> tryAutoLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('username')) {
      return;
    }
    
    final username = prefs.getString('username');
    final password = prefs.getString('password');

    // Temporariamente, vamos recriar o usuário a partir dos dados salvos
    // O ideal seria ter uma fonte de dados persistente para os usuários
    if (username != null && password != null) {
      _users.add(User(name: username, password: password));
      await login(username, password);
    }
  }

  Future<bool> register(String name, String password) async {
    // Verifica se o usuário já existe
    if (_users.any((user) => user.name == name)) {
      return false; // Usuário já registrado
    }

    // Adiciona o novo usuário
    _users.add(User(name: name, password: password));
    // Após o registro, também faz o login para salvar as credenciais
    await login(name, password);
    notifyListeners();
    return true;
  }

  Future<bool> login(String name, String password) async {
    // Simula uma chamada de rede
    await Future.delayed(const Duration(seconds: 1));

    try {
      final user = _users.firstWhere((user) => user.name == name && user.password == password);
      _isLoggedIn = true;
      _currentUser = user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', name);
      await prefs.setString('password', password);

      notifyListeners();
      return true;
    } catch (e) {
      return false; // Usuário não encontrado
    }
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(seconds: 1));
    _isLoggedIn = false;
    _currentUser = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');

    notifyListeners();
  }
}
