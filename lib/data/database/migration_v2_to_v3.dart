import 'package:sqflite/sqflite.dart';
import 'package:ouroboros_mobile/data/database/schema_v3.dart';
import 'package:flutter/foundation.dart';

Future<void> migrateV2ToV3(Database db) async {
  await db.transaction((txn) async {
    // 1. Verificar se a tabela antiga existe
    final tables = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='study_sessions_backup'"
    );

    if (tables.isNotEmpty) {
      await txn.execute('DROP TABLE study_sessions_backup');
    }

    // Renomear tabela antiga
    await txn.execute('ALTER TABLE study_sessions RENAME TO study_sessions_backup');

    // 2. Criar novas tabelas (schema v3)
    final statements = schemaV3.split(';');
    for (final stmt in statements) {
      final trimmed = stmt.trim();
      if (trimmed.isNotEmpty) {
        try {
          await txn.execute(trimmed);
        } catch (e) {
          debugPrint('Erro ao executar: $trimmed');
          debugPrint('Erro: $e');
        }
      }
    }

    // 3. Migrar dados - Versão SIMPLIFICADA (sem json_extract)
    // Primeiro, obter dados da tabela antiga
    final oldSessions = await txn.rawQuery('''
      SELECT id, date, minutes, topicos_json, metadata 
      FROM study_sessions_backup 
      WHERE topicos_json IS NOT NULL
    ''');

    // Processar cada sessão manualmente
    for (final session in oldSessions) {
      try {
        final topicosJson = session['topicos_json'] as String?;
        if (topicosJson == null) continue;

        // Extrair área e tópico do JSON (simplificado)
        // Assumindo que o JSON tem formato: [{"area": "NomeArea", "name": "NomeTopico"}]
        final areaName = _extractAreaFromJson(topicosJson);
        final topicName = _extractTopicFromJson(topicosJson);

        if (areaName == null || topicName == null) continue;

        // Inserir área (se não existir)
        await txn.rawInsert('''
          INSERT OR IGNORE INTO subject_areas (name, created_at)
          VALUES (?, strftime('%s', 'now'))
        ''', [areaName]);

        // Buscar ID da área
        final areaResult = await txn.rawQuery('''
          SELECT id FROM subject_areas WHERE name = ?
        ''', [areaName]);

        final areaId = areaResult.first['id'] as int? ?? 0;

        // Inserir tópico (se não existir)
        await txn.rawInsert('''
          INSERT OR IGNORE INTO topics (subject_area_id, name, created_at)
          VALUES (?, ?, strftime('%s', 'now'))
        ''', [areaId, topicName]);

        // Buscar ID do tópico
        final topicResult = await txn.rawQuery('''
          SELECT id FROM topics WHERE subject_area_id = ? AND name = ?
        ''', [areaId, topicName]);

        final topicId = topicResult.first['id'] as int? ?? 0;

        // Inserir sessão de estudo
        await txn.rawInsert('''
          INSERT INTO study_sessions (topic_id, study_date, minutes, metadata, updated_at)
          VALUES (?, ?, ?, ?, strftime('%s', 'now'))
        ''', [
          topicId,
          session['date'],
          session['minutes'],
          session['metadata'] ?? '{}'
        ]);

      } catch (e) {
        debugPrint('Erro ao migrar sessão: $e');
      }
    }

    // 4. Validar integridade (opcional)
    final countOld = await txn.rawQuery('SELECT COUNT(*) as c FROM study_sessions_backup');
    final countNew = await txn.rawQuery('SELECT COUNT(*) as c FROM study_sessions');

    debugPrint('Sessões antigas: ${countOld.first['c']}');
    debugPrint('Sessões novas: ${countNew.first['c']}');

    // 5. Remover backup somente se tudo deu certo
    await txn.execute('DROP TABLE study_sessions_backup');
  });
}

// Funções auxiliares para extrair dados do JSON
String? _extractAreaFromJson(String jsonStr) {
  try {
    // Implementação simples - ajuste conforme seu formato JSON
    final areaMatch = RegExp(r'"area"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
    return areaMatch?.group(1);
  } catch (e) {
    return null;
  }
}

String? _extractTopicFromJson(String jsonStr) {
  try {
    // Implementação simples - ajuste conforme seu formato JSON
    final topicMatch = RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(jsonStr);
    return topicMatch?.group(1);
  } catch (e) {
    return null;
  }
}
