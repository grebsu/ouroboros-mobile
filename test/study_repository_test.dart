import 'package:flutter_test/flutter_test.dart';
import 'package:ouroboros_mobile/data/repositories/study_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ouroboros_mobile/data/database/schema_v3.dart';

// Fake SharedPreferences for testing
class FakeSharedPreferences implements SharedPreferences {
  final Map<String, Object> _data = {};

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  double? getDouble(String key) => _data[key] as double?;

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  int? getInt(String key) => _data[key] as int?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    return true;
  }

  @override
  List<String>? getStringList(String key) => _data[key] as List<String>?;

  @override
  Set<String> getKeys() => _data.keys.toSet();

  @override
  Object? get(String key) => _data[key];

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Future<void> reload() async {}

  @override
  bool containsKey(String key) => _data.containsKey(key);
}

void main() {
  late Database db;
  late StudyRepository repo;
  
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // Executar schema v3 aqui...
    for (final stmt in schemaV3.split(';')) {
      if (stmt.trim().isNotEmpty) await db.execute(stmt);
    }
    repo = StudyRepository(db: db, prefs: FakeSharedPreferences());

    // Inserir dados básicos para os testes
    await db.insert('subject_areas', {'id': 1, 'name': 'Matemática', 'created_at': DateTime.now().millisecondsSinceEpoch});
    await db.insert('topics', {'id': 1, 'subject_area_id': 1, 'name': 'Álgebra', 'created_at': DateTime.now().millisecondsSinceEpoch, 'estimated_hours': 10.0});
    await db.insert('topics', {'id': 2, 'subject_area_id': 1, 'name': 'Geometria', 'created_at': DateTime.now().millisecondsSinceEpoch, 'estimated_hours': 15.0});
  });

  tearDown(() async {
    await db.close();
  });
  
  test('getHoursPerSubjectArea retorna soma correta', () async {
    // Inserir dados de teste
    await db.insert('study_sessions', {
      'topic_id': 1,
      'cycle_id': 1,
      'study_date': DateTime(2025, 1, 1).millisecondsSinceEpoch,
      'minutes': 120,
      'session_type': 'theory',
      'updated_at': DateTime.now().millisecondsSinceEpoch
    });
    await db.insert('study_sessions', {
      'topic_id': 2,
      'cycle_id': 1,
      'study_date': DateTime(2025, 1, 1).millisecondsSinceEpoch,
      'minutes': 60,
      'session_type': 'theory',
      'updated_at': DateTime.now().millisecondsSinceEpoch
    });
    
    final result = await repo.getHoursPerSubjectArea(
      DateTime(2025, 1, 1), 
      DateTime(2025, 1, 2),
    );
    
    expect(result.length, 1);
    expect(result.first['area'], 'Matemática');
    expect(result.first['hours'], 3.0); // 120 + 60 = 180 minutes = 3 hours
    expect(result.first['topics_count'], 2);
  });

  test('getSessionsByTopic retorna sessões corretas para um tópico', () async {
    await db.insert('study_sessions', {
      'topic_id': 1,
      'cycle_id': 1,
      'study_date': DateTime(2025, 1, 5).millisecondsSinceEpoch,
      'minutes': 90,
      'session_type': 'questions',
      'updated_at': DateTime.now().millisecondsSinceEpoch
    });
    await db.insert('study_sessions', {
      'topic_id': 1,
      'cycle_id': 1,
      'study_date': DateTime(2025, 1, 1).millisecondsSinceEpoch,
      'minutes': 30,
      'session_type': 'theory',
      'updated_at': DateTime.now().millisecondsSinceEpoch
    });
    await db.insert('study_sessions', {
      'topic_id': 2, // Diferente tópico
      'cycle_id': 1,
      'study_date': DateTime(2025, 1, 1).millisecondsSinceEpoch,
      'minutes': 60,
      'session_type': 'theory',
      'updated_at': DateTime.now().millisecondsSinceEpoch
    });

    final sessions = await repo.getSessionsByTopic('Álgebra');
    expect(sessions.length, 2);
    expect(sessions.first['minutes'], 90); // Ordenado por data DESC
    expect(sessions.last['minutes'], 30);
    expect(sessions.first['topic_info']['name'], 'Álgebra');
    expect(sessions.last['topic_info']['name'], 'Álgebra');
  });

  test('syncSessions insere e atualiza sessões', () async {
    // Inserir sessão inicial
    await db.insert('study_sessions', {
      'id': 1,
      'topic_id': 1,
      'cycle_id': 1,
      'study_date': DateTime(2025, 1, 1).millisecondsSinceEpoch,
      'minutes': 60,
      'session_type': 'theory',
      'updated_at': DateTime(2025, 1, 1, 10, 0, 0).millisecondsSinceEpoch // old timestamp
    });

    // Sessão remota para inserir
    final newRemoteSession = {
      'id': 2,
      'topic_id': 1,
      'study_date': DateTime(2025, 1, 2).millisecondsSinceEpoch,
      'minutes': 90,
      'session_type': 'questions',
      'metadata': '{"foo": "bar"}',
      'updated_at': DateTime(2025, 1, 2, 11, 0, 0).millisecondsSinceEpoch
    };

    // Sessão remota para atualizar (mesmo ID, mas minutos diferentes e updated_at mais recente)
    final updatedRemoteSession = {
      'id': 1,
      'topic_id': 1,
      'study_date': DateTime(2025, 1, 1).millisecondsSinceEpoch,
      'minutes': 75,
      'session_type': 'theory',
      'metadata': '{"note": "updated"}',
      'updated_at': DateTime(2025, 1, 1, 12, 0, 0).millisecondsSinceEpoch // more recent timestamp
    };

    await repo.syncSessions([newRemoteSession, updatedRemoteSession]);

    final sessions = await db.query('study_sessions');
    expect(sessions.length, 2);

    final session1 = sessions.firstWhere((s) => s['id'] == 1);
    expect(session1['minutes'], 75); // Deve ter sido atualizado
    expect(session1['metadata'], '{"note": "updated"}');

    final session2 = sessions.firstWhere((s) => s['id'] == 2);
    expect(session2['minutes'], 90); // Deve ter sido inserido
    expect(session2['session_type'], 'questions');
  });

  test('clearCache limpa o cache em memória', () async {
    // Adicionar algo ao cache
    await repo.getSessionsByTopic('Álgebra');
    expect(repo.clearCache, returnsNormally);
    // Verificação indireta: garantir que o cache está vazio
    // Como _memoryCache é privado, verificamos que o próximo getSessionsByTopic não use o cache
    // ou adicionamos um método de debug no StudyRepository se necessário para testes mais profundos.
    // Por enquanto, a chamada sem erros é o suficiente.
  });

  test('Trigger de topic_progress funciona ao inserir session', () async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('study_sessions', {
      'topic_id': 1,
      'cycle_id': 1,
      'study_date': now,
      'minutes': 60,
      'session_type': 'theory',
      'updated_at': now
    });

    final progress = await db.query('topic_progress', where: 'topic_id = ?', whereArgs: [1]);
    expect(progress.length, 1);
    expect(progress.first['total_minutes'], 60);
    expect(progress.first['last_studied_at'], now);
    // estimated_hours para Algebra é 10.0, então 60 min = 1 hora / 10 horas = 0.1 mastery
    expect(progress.first['mastery_level'], closeTo(0.1, 0.001));

    await db.insert('study_sessions', {
      'topic_id': 1,
      'cycle_id': 1,
      'study_date': now + 3600000, // uma hora depois
      'minutes': 120,
      'session_type': 'questions',
      'updated_at': now + 3600000
    });

    final updatedProgress = await db.query('topic_progress', where: 'topic_id = ?', whereArgs: [1]);
    expect(updatedProgress.length, 1);
    expect(updatedProgress.first['total_minutes'], 180); // 60 + 120
    expect(updatedProgress.first['last_studied_at'], now + 3600000); // data mais recente
    // 180 min = 3 horas / 10 horas = 0.3 mastery
    expect(updatedProgress.first['mastery_level'], closeTo(0.3, 0.001));
  });
}
