import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/data_models.dart';
import '../services/database_service.dart';

// Helper function to hash passwords using BCrypt
String _hashPassword(String password) {
  return BCrypt.hashpw(password, BCrypt.gensalt());
}

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _storage;
  final _uuid = const Uuid();
  final _db = DatabaseService.instance;
  
  AuthProvider({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );

  bool _isLoggedIn = false;
  User? _currentUser;

  bool get isLoggedIn => _isLoggedIn;
  User? get currentUser => _currentUser;

  Future<void> tryAutoLogin() async {
    // await Future.delayed(const Duration(seconds: 2)); // Reduzi o delay para UX
    final username = await _storage.read(key: 'username');
    
    if (username != null) {
      final user = await _db.getUserByUsername(username);
      if (user != null) {
        _isLoggedIn = true;
        _currentUser = user;
        notifyListeners();
      }
    }
  }

  Future<bool> register(String name, String password) async {
    try {
      // Verifica se o usuário já existe no Banco de Dados
      final existingUser = await _db.getUserByUsername(name);
      if (existingUser != null) {
        return false; // Usuário já registrado
      }

      final hashedPwd = _hashPassword(password);
      final newUser = User(
        id: _uuid.v4(),
        username: name,
        hashedPassword: hashedPwd,
      );

      await _db.createUser(newUser);
      
      _isLoggedIn = true;
      _currentUser = newUser;
      
      await _storage.write(key: 'username', value: name);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthProvider: Erro durante o registro: $e');
      // Propagamos o erro para que a UI possa tratar ou exibir a mensagem real
      throw Exception('Falha técnica no registro: ${e.toString()}');
    }
  }

  Future<bool> login(String name, String password) async {
    try {
      final user = await _db.getUserByUsername(name);
      
      if (user != null && BCrypt.checkpw(password, user.hashedPassword)) {
        _isLoggedIn = true;
        _currentUser = user;

        await _storage.write(key: 'username', value: name);

        notifyListeners();
        return true;
      }
      
      return false; // Usuário não encontrado ou senha incorreta
    } catch (e) {
      debugPrint('AuthProvider: Erro durante o login: $e');
      throw Exception('Falha técnica no login: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _currentUser = null;

    await _storage.delete(key: 'username');

    notifyListeners();
  }
}
