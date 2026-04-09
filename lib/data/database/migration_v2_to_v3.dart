import 'package:sqflite/sqflite.dart';
import 'package:ouroboros_mobile/data/database/schema_v3.dart';

Future<void> migrateV2ToV3(Database db) async {
  await db.transaction((txn) async {
    // 1. Backup das tabelas antigas (se existirem)
    await txn.execute('ALTER TABLE study_sessions RENAME TO study_sessions_backup');
    
    // 2. Criar novas tabelas (schema v3)
    for (final stmt in schemaV3.split(';')) {
      if (stmt.trim().isNotEmpty) await txn.execute(stmt);
    }
    
    // 3. Migrar dados: extrair áreas e tópicos do JSON bag antigo
    //    Aqui assumo que a tabela antiga tinha colunas: topicos_json (TEXT), minutes, date, etc.
    //    Ajuste conforme seu schema real.
    await txn.rawInsert('''
      INSERT INTO subject_areas (name, created_at)
      SELECT DISTINCT json_extract(value, '$.area'), strftime('%s', 'now')
      FROM study_sessions_backup, json_each(study_sessions_backup.topicos_json)
      ON CONFLICT(name) DO NOTHING
    ''');
    
    await txn.rawInsert('''
      INSERT INTO topics (subject_area_id, name, created_at)
      SELECT DISTINCT sa.id, json_extract(topic.value, '$.name'), strftime('%s', 'now')
      FROM study_sessions_backup,
           json_each(study_sessions_backup.topicos_json) AS topic
      JOIN subject_areas sa ON sa.name = json_extract(topic.value, '$.area')
      ON CONFLICT(subject_area_id, name) DO NOTHING
    ''');
    
    // 4. Migrar sessões de estudo
    await txn.rawInsert('''
      INSERT INTO study_sessions (topic_id, study_date, minutes, metadata, updated_at)
      SELECT 
        t.id,
        sb.date,
        sb.minutes,
        json_object('old_metadata', sb.metadata),
        strftime('%s', 'now')
      FROM study_sessions_backup sb
      JOIN topics t ON t.name = json_extract(sb.topicos_json, '$[0].name')
    ''');
    
    // 5. Validar integridade (opcional, mas recomendado)
    final countOld = await txn.rawQuery('SELECT COUNT(*) as c FROM study_sessions_backup');
    final countNew = await txn.rawQuery('SELECT COUNT(*) as c FROM study_sessions');
    if (countOld.first['c'] != countNew.first['c']) {
      throw Exception('Migração falhou: contagem de sessões inconsistente');
    }
    
    // 6. Remover backup somente se tudo deu certo
    await txn.execute('DROP TABLE study_sessions_backup');
  });
}
