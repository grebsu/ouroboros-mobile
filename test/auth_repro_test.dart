import 'package:flutter_test/flutter_test.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data;
  }
}

void main() {
  group('AuthProvider Persistence Tests', () {
    late FakeFlutterSecureStorage fakeStorage;
    late Database db;

    setUpAll(() async {
      sqfliteFfiInit();
    });

    setUp(() async {
      fakeStorage = FakeFlutterSecureStorage();
      // Usar banco de dados em memória para testes
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      
      // Criar a tabela de usuários necessária para o teste
      await db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          username TEXT NOT NULL UNIQUE,
          hashedPassword TEXT NOT NULL,
          lastModified INTEGER
        )
      ''');
      
      // Configurar o singleton para usar este banco em memória
      DatabaseService.setDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('login deve funcionar após restart com banco persistente', () async {
      final auth1 = AuthProvider(storage: fakeStorage);

      // Registrar usuário
      final registered = await auth1.register('glebson', 'password123');
      expect(registered, isTrue);
      expect(auth1.isLoggedIn, isTrue);
      expect(auth1.currentUser?.username, 'glebson');

      // Simular restart (nova instância do provider, mesmo banco e storage)
      // O banco em memória persiste enquanto 'db' estiver aberto.
      final auth2 = AuthProvider(storage: fakeStorage);
      
      // Tentar login
      final loggedIn = await auth2.login('glebson', 'password123');
      
      expect(loggedIn, isTrue, reason: 'O login deveria funcionar consultando o banco de dados');
      expect(auth2.currentUser?.username, 'glebson');
    });

    test('registro deve falhar para usuário existente no banco', () async {
      final auth1 = AuthProvider(storage: fakeStorage);
      await auth1.register('glebson', 'password123');

      // Simular restart
      final auth2 = AuthProvider(storage: fakeStorage);
      
      // Tentar registrar com o mesmo nome
      final reRegistered = await auth2.register('glebson', 'newpassword');
      
      expect(reRegistered, isFalse, reason: 'O registro deve falhar se o username já existe no DB');
    });
    
    test('tryAutoLogin deve restaurar sessão do usuário persistido', () async {
      final auth1 = AuthProvider(storage: fakeStorage);
      await auth1.register('glebson', 'password123');

      // Simular restart
      final auth2 = AuthProvider(storage: fakeStorage);
      
      await auth2.tryAutoLogin();
      
      expect(auth2.isLoggedIn, isTrue);
      expect(auth2.currentUser?.username, 'glebson');
    });
  });
}
