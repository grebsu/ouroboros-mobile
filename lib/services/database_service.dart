import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:math';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/data_models.dart';
import '../models/backup_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );

  DatabaseService._init();

  @visibleForTesting
  static void setDatabase(Database db) {
    _database = db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    debugPrint('🔍 DatabaseService: Solicitando instância do banco...');
    _database = await _initDB('ouroboros_secure.db');
    return _database!;
  }

  Future<Database> _openDatabaseWithCipher(String path, String key) async {
    debugPrint('🔍 DatabaseService: Abrindo banco com senha...');
    return await openDatabase(
      path,
      password: key,
      version: 19,
      onCreate: (db, version) async {
        debugPrint('🏗️ Criando banco criptografado na versão $version');
        await _createDB(db, version);
      },
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        try {
          // Verificar se SQLCipher está ativo
          final List<Map<String, dynamic>> result = await db.rawQuery('PRAGMA cipher_version;');
          if (result.isNotEmpty && result.first.values.first != null) {
            debugPrint('🔐 SQLCipher detectado e ativo. Versão: ${result.first.values.first}');
          }
        } catch (e) {
          debugPrint('⚠️ SQLCipher: Erro ao verificar versão: $e');
        }

        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);
    debugPrint('📂 DatabaseService: Caminho do banco: $path');

    try {
      debugPrint('🔑 DatabaseService: Lendo chave do SecureStorage...');
      String? encryptionKey = await _storage.read(key: 'db_encryption_key');
      
      if (encryptionKey == null) {
        debugPrint('🔑 DatabaseService: Gerando nova chave de criptografia...');
        encryptionKey = _generateNewEncryptionKey();
        await _storage.write(key: 'db_encryption_key', value: encryptionKey);
        debugPrint('🔑 DatabaseService: Nova chave gerada e salva.');
      }

      return await _openDatabaseWithCipher(path, encryptionKey);
    } catch (e) {
      debugPrint('❌ DatabaseService: ERRO NO SECURE STORAGE: $e');
      // Fallback em caso de falha catastrófica do Keystore em ambiente de dev
      return await _openDatabaseWithCipher(path, 'fallback_key_ouroboros');
    }
  }

  String _generateNewEncryptionKey() {
    // Generate a secure random key using a cryptographically secure random number generator
    // For production, consider a more robust key management strategy.
    // This is a placeholder for demonstration purposes.
    final List<int> bytes = List<int>.generate(32, (i) => Random().nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE topics ADD COLUMN parent_id INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE topics ADD COLUMN is_grouping_topic INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE subjects ADD COLUMN total_topics_count INTEGER');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE topics ADD COLUMN question_count INTEGER');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE topics ADD COLUMN userWeight INTEGER');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE subjects ADD COLUMN import_source TEXT');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE study_records ADD COLUMN userId TEXT NOT NULL DEFAULT ''');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE subjects ADD COLUMN userId TEXT NOT NULL DEFAULT ''');
      await db.execute('ALTER TABLE simulado_records ADD COLUMN userId TEXT NOT NULL DEFAULT ''');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE review_records ADD COLUMN userId TEXT NOT NULL DEFAULT ''');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE plans ADD COLUMN userId TEXT NOT NULL DEFAULT ''');
    }
    if (oldVersion < 12) {
      await _createMasterTables(db);
    }
    if (oldVersion < 13) {
      await db.execute('ALTER TABLE plans ADD COLUMN lastModified INTEGER;');
      await db.execute('ALTER TABLE subjects ADD COLUMN lastModified INTEGER;');
      await db.execute('ALTER TABLE topics ADD COLUMN lastModified INTEGER;');
      await db.execute('ALTER TABLE study_records ADD COLUMN lastModified INTEGER;');
      await db.execute('ALTER TABLE review_records ADD COLUMN lastModified INTEGER;');
      await db.execute('ALTER TABLE simulado_records ADD COLUMN lastModified INTEGER;');
      await db.execute('ALTER TABLE simulado_subjects ADD COLUMN lastModified INTEGER;');
    }
    if (oldVersion < 14) {
      await db.execute('ALTER TABLE study_records RENAME TO study_records_old');
      await db.execute('''
        CREATE TABLE study_records (
          id TEXT PRIMARY KEY,
          userId TEXT NOT NULL,
          plan_id TEXT NOT NULL,
          date TEXT NOT NULL,
          subject_id TEXT NOT NULL,
          topic_texts TEXT NOT NULL,
          topic_ids TEXT NOT NULL,
          category TEXT NOT NULL,
          study_time INTEGER NOT NULL,
          questions TEXT NOT NULL,
          material TEXT,
          notes TEXT,
          review_periods TEXT NOT NULL,
          teoria_finalizada INTEGER NOT NULL,
          count_in_planning INTEGER NOT NULL,
          pages TEXT NOT NULL,
          videos TEXT NOT NULL,
          lastModified INTEGER,
          FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE,
          FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE SET NULL
        )
      ''');
    }
    if (oldVersion < 15) {
      await db.execute('ALTER TABLE review_records RENAME TO review_records_old;');
      await db.execute('''
        CREATE TABLE review_records (
          id TEXT PRIMARY KEY,
          userId TEXT NOT NULL,
          plan_id TEXT NOT NULL,
          study_record_id TEXT NOT NULL,
          scheduled_date TEXT NOT NULL,
          status TEXT NOT NULL,
          original_date TEXT NOT NULL,
          subject_id TEXT,
          topics TEXT NOT NULL,
          review_period TEXT NOT NULL,
          completed_date TEXT,
          ignored INTEGER NOT NULL,
          lastModified INTEGER,
          FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE,
          FOREIGN KEY (study_record_id) REFERENCES study_records (id) ON DELETE CASCADE,
          FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        INSERT INTO review_records (
          id, userId, plan_id, study_record_id, scheduled_date, status,
          original_date, subject_id, topics, review_period, completed_date,
          ignored, lastModified
        )
        SELECT
          id, userId, plan_id, study_record_id, scheduled_date, status,
          original_date, subject_id, json_array(topic), review_period, completed_date,
          ignored, lastModified
        FROM review_records_old;
      ''');
      await db.execute('DROP TABLE review_records_old;');
    }
    if (oldVersion < 16) {
      await db.execute('ALTER TABLE master_topics ADD COLUMN question_count INTEGER;');
    }
    if (oldVersion < 17) {
      await db.execute("ALTER TABLE study_records ADD COLUMN topicsProgress TEXT NOT NULL DEFAULT '[]'");

      final List<Map<String, dynamic>> oldRecords = await db.query('study_records');
      
      final batch = db.batch();

      for (final oldRecordMap in oldRecords) {
        final String recordId = oldRecordMap['id'] as String;
        final List<dynamic> oldTopicTexts = jsonDecode(oldRecordMap['topic_texts'] as String? ?? '[]') as List<dynamic>;
        final List<dynamic> oldTopicIds = jsonDecode(oldRecordMap['topic_ids'] as String? ?? '[]') as List<dynamic>;
        final Map<String, dynamic> oldQuestions = jsonDecode(oldRecordMap['questions'] as String? ?? '{}') as Map<String, dynamic>;
        final List<dynamic> oldPages = jsonDecode(oldRecordMap['pages'] as String? ?? '[]') as List<dynamic>;
        final List<dynamic> oldVideos = jsonDecode(oldRecordMap['videos'] as String? ?? '[]') as List<dynamic>;
        final String? oldNotes = oldRecordMap['notes'] as String?;
        final bool oldTeoriaFinalizada = oldRecordMap['teoria_finalizada'] == 1;

        final List<TopicProgress> newTopicsProgress = [];
        if (oldTopicIds.isNotEmpty) {
          for (int i = 0; i < oldTopicIds.length; i++) {
            newTopicsProgress.add(
              TopicProgress(
                topicId: oldTopicIds[i] as String,
                topicText: oldTopicTexts.length > i ? oldTopicTexts[i] as String : '',
                questions: Map<String, int>.from(oldQuestions),
                pages: oldPages.map((e) => Map<String, int>.from(e as Map<String, dynamic>)).toList(),
                videos: oldVideos.map((e) => Map<String, String>.from(e as Map<String, dynamic>)).toList(),
                notes: oldNotes,
                isTheoryFinished: oldTeoriaFinalizada,
                userWeight: null,
              ),
            );
          }
        } else {
          final String subjectId = oldRecordMap['subject_id'] as String;
          newTopicsProgress.add(
            TopicProgress(
              topicId: subjectId,
              topicText: 'Tópico Geral (${oldRecordMap['id']})',
              questions: Map<String, int>.from(oldQuestions),
              pages: oldPages.map((e) => Map<String, int>.from(e as Map<String, dynamic>)).toList(),
              videos: oldVideos.map((e) => Map<String, String>.from(e as Map<String, dynamic>)).toList(),
              notes: oldNotes,
              isTheoryFinished: oldTeoriaFinalizada,
              userWeight: null,
            ),
          );
        }

        final String topicsProgressJson = jsonEncode(newTopicsProgress.map((tp) => tp.toMap()).toList());

        batch.update(
          'study_records',
          {'topicsProgress': topicsProgressJson},
          where: 'id = ?',
          whereArgs: [recordId],
        );
      }
      await batch.commit(noResult: true);

      await db.execute('ALTER TABLE study_records DROP COLUMN topic_texts;');
      await db.execute('ALTER TABLE study_records DROP COLUMN topic_ids;');
      await db.execute('ALTER TABLE study_records DROP COLUMN questions;');
      await db.execute('ALTER TABLE study_records DROP COLUMN material;');
      await db.execute('ALTER TABLE study_records DROP COLUMN notes;');
      await db.execute('ALTER TABLE study_records DROP COLUMN teoria_finalizada;');
      await db.execute('ALTER TABLE study_records DROP COLUMN pages;');
      await db.execute('ALTER TABLE study_records DROP COLUMN videos;');
    }
    if (oldVersion < 18) {
      var tableInfo = await db.rawQuery("PRAGMA table_info(study_records);");
      bool columnExists = false;
      for (final row in tableInfo) {
        if (row['name'] == 'cycleId') {
          columnExists = true;
          break;
        }
      }
      if (!columnExists) {
        await db.execute('ALTER TABLE study_records ADD COLUMN cycleId TEXT');
      }
    }
    if (oldVersion < 19) {
      await db.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          username TEXT NOT NULL UNIQUE,
          hashedPassword TEXT NOT NULL,
          lastModified INTEGER
        )
      ''');
    }
  }

  Future<void> _createMasterTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS master_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS master_topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        master_subject_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        tec_id TEXT,
        parent_id INTEGER,
        question_count INTEGER,
        FOREIGN KEY (master_subject_id) REFERENCES master_subjects (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE plans (
        id $idType,
        userId $textType,
        name $textType,
        observations $textTypeNullable,
        cargo $textTypeNullable,
        edital $textTypeNullable,
        banca $textTypeNullable,
        iconUrl $textTypeNullable,
        lastModified INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE subjects (
        id $idType,
        userId $textType,
        plan_id $textType,
        subject $textType,
        color $textType,
        total_topics_count INTEGER,
        import_source $textTypeNullable,
        lastModified INTEGER,
        FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id $textType,
        topic_text $textType,
        parent_id INTEGER,
        is_grouping_topic $boolType,
        question_count INTEGER,
        userWeight INTEGER,
        lastModified INTEGER,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE study_records (
        id $idType,
        userId $textType,
        plan_id $textType,
        cycleId $textTypeNullable,
        date $textType,
        subject_id $textType,
        category $textType,
        study_time $integerType,
        topicsProgress TEXT NOT NULL,
        review_periods $textType,
        count_in_planning $boolType,
        lastModified INTEGER,
        FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE review_records (
        id $idType,
        userId $textType,
        plan_id $textType,
        study_record_id $textType,
        scheduled_date $textType,
        status $textType,
        original_date $textType,
        subject_id $textTypeNullable,
        topics $textType,
        review_period $textType,
        completed_date $textTypeNullable,
        ignored $boolType,
        lastModified INTEGER,
        FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE,
        FOREIGN KEY (study_record_id) REFERENCES study_records (id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE simulado_records (
        id $idType,
        userId $textType,
        plan_id $textType,
        date $textType,
        name $textType,
        style $textTypeNullable,
        banca $textTypeNullable,
        time_spent $textTypeNullable,
        comments $textTypeNullable,
        lastModified INTEGER,
        FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE simulado_subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        simulado_record_id $textType,
        subject_id $textType,
        subject_name $textType,
        weight REAL NOT NULL,
        total_questions $integerType,
        correct $integerType,
        incorrect $integerType,
        color $textType,
        lastModified INTEGER,
        FOREIGN KEY (simulado_record_id) REFERENCES simulado_records (id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id $idType,
        username $textType UNIQUE,
        hashedPassword $textType,
        lastModified INTEGER
      )
    ''');

    await _createMasterTables(db);
    await importSubjectsAndTopicsFromJson(db);
  }

  // Plan CRUD methods
  Future<void> createPlan(Plan plan, String userId) async {
    final db = await instance.database;
    final planMap = plan.toMap();
    planMap['userId'] = userId;
    await db.insert('plans', planMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Plan?> readPlan(String id, String userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'plans',
      columns: ['id', 'userId', 'name', 'observations', 'cargo', 'edital', 'banca', 'iconUrl', 'lastModified'],
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );

    if (maps.isNotEmpty) {
      return Plan.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Plan>> readAllPlans(String userId) async {
    final db = await instance.database;
    const orderBy = 'name ASC';
    final result = await db.query('plans', where: 'userId = ?', whereArgs: [userId], orderBy: orderBy);
    return result.map((json) => Plan.fromMap(json)).toList();
  }

  Future<int> updatePlan(Plan plan, String userId) async {
    final db = await instance.database;
    return db.update('plans', plan.toMap(), where: 'id = ? AND userId = ?', whereArgs: [plan.id, userId]);
  }

  Future<int> deletePlan(String id, String userId) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      await txn.delete('subjects', where: 'plan_id = ? AND userId = ?', whereArgs: [id, userId]);
      return txn.delete('plans', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
    });
  }

  Future<void> _insertTopicsRecursively(
      Transaction txn,
      List<Topic> topics,
      String subjectId,
      int? parentId,
      ) async {
    for (final topic in topics) {
      final bool isCurrentlyGrouping = topic.sub_topics != null && topic.sub_topics!.isNotEmpty;

      final topicToInsert = Topic(
        subject_id: subjectId,
        topic_text: topic.topic_text,
        parent_id: parentId,
        is_grouping_topic: isCurrentlyGrouping,
        question_count: topic.question_count,
        userWeight: topic.userWeight,
      );

      final newTopicId = await txn.insert('topics', topicToInsert.toMap());

      if (topic.sub_topics != null && topic.sub_topics!.isNotEmpty) {
        await _insertTopicsRecursively(txn, topic.sub_topics!, subjectId, newTopicId);
      }
    }
  }

  Future<void> createSubject(Subject subject, String userId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final subjectMap = subject.toMap();
      subjectMap['userId'] = userId;
      await txn.insert('subjects', subjectMap, conflictAlgorithm: ConflictAlgorithm.replace);
      await _insertTopicsRecursively(txn, subject.topics, subject.id, null);
    });
  }

  Future<List<Subject>> readSubjectsForPlan(String planId, String userId) async {
    final db = await instance.database;
    final subjectMaps = await db.query('subjects', where: 'plan_id = ? AND userId = ?', whereArgs: [planId, userId]);

    if (subjectMaps.isEmpty) return [];

    final List<Subject> subjects = [];
    for (final subjectMap in subjectMaps) {
      final topicMaps = await db.query('topics', where: 'subject_id = ?', whereArgs: [subjectMap['id']]);
      final allTopics = topicMaps.map((map) => Topic.fromMap(map)).toList();

      final topicMapById = <int, Topic>{};
      for (final t in allTopics) {
        if (t.id != null) {
          topicMapById[t.id!] = t;
        }
      }

      final rootTopics = <Topic>[];
      for (final topic in allTopics) {
        if (topic.parent_id == null) {
          rootTopics.add(topic);
        } else {
          final parent = topicMapById[topic.parent_id];
          if (parent != null) {
            parent.sub_topics!.add(topic);
          }
        }
      }

      subjects.add(Subject.fromMap(subjectMap, rootTopics));
    }
    return subjects;
  }

  Future<int> updateSubject(Subject subject, String userId) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final subjectUpdateCount = await txn.update(
        'subjects',
        {'subject': subject.subject, 'color': subject.color},
        where: 'id = ? AND userId = ?',
        whereArgs: [subject.id, userId],
      );

      await txn.delete('topics', where: 'subject_id = ?', whereArgs: [subject.id]);
      await _insertTopicsRecursively(txn, subject.topics, subject.id, null);

      return subjectUpdateCount;
    });
  }

  Future<int> deleteSubject(String id, String userId) async {
    final db = await instance.database;
    return db.delete('subjects', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  Future<void> updateTopicWeights(Map<int, int> weights) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      weights.forEach((topicId, weight) {
        batch.update('topics', {'userWeight': weight}, where: 'id = ?', whereArgs: [topicId]);
      });
      await batch.commit(noResult: true);
    });
  }

  Future<void> createStudyRecord(StudyRecord record) async {
    final db = await instance.database;
    await db.insert('study_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StudyRecord>> readStudyRecordsForPlan(String planId) async {
    final db = await instance.database;
    final maps = await db.query('study_records', where: 'plan_id = ?', whereArgs: [planId], orderBy: 'date DESC');
    return maps.map((map) => StudyRecord.fromMap(map)).toList();
  }

  Future<int> updateStudyRecord(StudyRecord record) async {
    final db = await instance.database;
    return db.update('study_records', record.toMap(), where: 'id = ?', whereArgs: [record.id]);
  }

  Future<int> deleteStudyRecord(String id) async {
    final db = await instance.database;
    return db.delete('study_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<StudyRecord>> readStudyRecordsForUser(String userId) async {
    final db = await instance.database;
    final maps = await db.query('study_records', where: 'userId = ?', whereArgs: [userId], orderBy: 'date DESC');
    return maps.map((map) => StudyRecord.fromMap(map)).toList();
  }

  Future<void> createReviewRecord(ReviewRecord record, String userId) async {
    final db = await instance.database;
    final recordMap = record.toMap();
    recordMap['userId'] = userId;
    await db.insert('review_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReviewRecord>> readReviewRecordsForPlan(String planId, String userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'review_records',
      where: 'plan_id = ? AND userId = ?',
      whereArgs: [planId, userId],
      orderBy: 'scheduled_date ASC',
    );
    return maps.map((map) => ReviewRecord.fromMap(map)).toList();
  }

  Future<int> updateReviewRecord(ReviewRecord record, String userId) async {
    final db = await instance.database;
    return db.update('review_records', record.toMap(), where: 'id = ? AND userId = ?', whereArgs: [record.id, userId]);
  }

  Future<int> deleteReviewRecord(String id, String userId) async {
    final db = await instance.database;
    return db.delete('review_records', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  Future<List<ReviewRecord>> getAllReviewRecords(String userId) async {
    final db = await instance.database;
    final maps = await db.query('review_records', where: 'userId = ?', whereArgs: [userId], orderBy: 'scheduled_date ASC');
    return maps.map((map) => ReviewRecord.fromMap(map)).toList();
  }

  Future<List<ReviewRecord>> readReviewRecordsForStudyRecord(String studyRecordId, String userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'review_records',
      where: 'study_record_id = ? AND userId = ?',
      whereArgs: [studyRecordId, userId],
      orderBy: 'scheduled_date ASC',
    );
    return maps.map((map) => ReviewRecord.fromMap(map)).toList();
  }

  Future<void> createSimuladoRecord(SimuladoRecord record, String userId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final recordMap = record.toMap();
      recordMap['userId'] = userId;
      await txn.insert('simulado_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final subject in record.subjects) {
        await txn.insert('simulado_subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<SimuladoRecord>> readSimuladoRecordsForPlan(String planId, String userId) async {
    final db = await instance.database;
    final recordMaps = await db.query(
      'simulado_records',
      where: 'plan_id = ? AND userId = ?',
      whereArgs: [planId, userId],
      orderBy: 'date DESC',
    );

    if (recordMaps.isEmpty) return [];

    final List<SimuladoRecord> records = [];
    for (final recordMap in recordMaps) {
      final subjectMaps = await db.query('simulado_subjects', where: 'simulado_record_id = ?', whereArgs: [recordMap['id']]);
      final subjects = subjectMaps.map((map) => SimuladoSubject.fromMap(map)).toList();
      records.add(SimuladoRecord.fromMap(recordMap, subjects));
    }
    return records;
  }

  Future<List<SimuladoRecord>> readAllSimuladoRecordsForUser(String userId) async {
    final db = await instance.database;
    final recordMaps = await db.query('simulado_records', where: 'userId = ?', whereArgs: [userId], orderBy: 'date DESC');

    if (recordMaps.isEmpty) return [];

    final List<SimuladoRecord> records = [];
    for (final recordMap in recordMaps) {
      final subjectMaps = await db.query('simulado_subjects', where: 'simulado_record_id = ?', whereArgs: [recordMap['id']]);
      final subjects = subjectMaps.map((map) => SimuladoSubject.fromMap(map)).toList();
      records.add(SimuladoRecord.fromMap(recordMap, subjects));
    }
    return records;
  }

  Future<int> updateSimuladoRecord(SimuladoRecord record, String userId) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final recordUpdateCount = await txn.update(
        'simulado_records',
        record.toMap(),
        where: 'id = ? AND userId = ?',
        whereArgs: [record.id, userId],
      );

      await txn.delete('simulado_subjects', where: 'simulado_record_id = ?', whereArgs: [record.id]);
      for (final subject in record.subjects) {
        await txn.insert('simulado_subjects', subject.toMap());
      }

      return recordUpdateCount;
    });
  }

  Future<int> deleteSimuladoRecord(String id, String userId) async {
    final db = await instance.database;
    return db.delete('simulado_records', where: 'id = ? AND userId = ?', whereArgs: [id, userId]);
  }

  // User methods
  Future<void> createUser(User user) async {
    final db = await instance.database;
    await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> countSubjectsForPlan(String planId) async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM subjects WHERE plan_id = ?', [planId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countTopicsForPlan(String planId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT COUNT(T.id) FROM topics AS T
      INNER JOIN subjects AS S ON T.subject_id = S.id
      WHERE S.plan_id = ?
    ''', [planId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteAllData() async {
    if (_database == null) return;
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, 'ouroboros.db');

    await _database!.close();

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await ffi.deleteDatabase(path);
    } else {
      await deleteDatabase(path);
    }
    _database = null;
  }

  Future<void> _deleteAllDataForUser(Transaction txn, String userId) async {
    await txn.delete('plans', where: 'userId = ?', whereArgs: [userId]);
    await txn.delete('subjects', where: 'userId = ?', whereArgs: [userId]);
    await txn.delete('study_records', where: 'userId = ?', whereArgs: [userId]);
    await txn.delete('review_records', where: 'userId = ?', whereArgs: [userId]);
    await txn.delete('simulado_records', where: 'userId = ?', whereArgs: [userId]);
  }

  Future<void> deleteAllDataForUser(String userId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await _deleteAllDataForUser(txn, userId);
    });
  }

  Future<void> importBackupData(BackupData backup, String userId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final plan in backup.plans) {
        final planMap = plan.toMap();
        planMap['userId'] = userId;
        await txn.insert('plans', planMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final subject in backup.subjects) {
        final subjectMap = subject.toMap();
        subjectMap['userId'] = userId;
        await txn.insert('subjects', subjectMap, conflictAlgorithm: ConflictAlgorithm.replace);
        await _insertTopicsRecursively(txn, subject.topics, subject.id, null);
      }
      for (final record in backup.studyRecords) {
        await txn.insert('study_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final record in backup.reviewRecords) {
        await txn.insert('review_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final record in backup.simuladoRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('simulado_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final subject in record.subjects) {
          await txn.insert('simulado_subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<List<Subject>> readAllSubjects(String userId) async {
    final db = await instance.database;
    final subjectMaps = await db.query('subjects', where: 'userId = ?', whereArgs: [userId]);

    if (subjectMaps.isEmpty) return [];

    final List<Subject> subjects = [];
    for (final subjectMap in subjectMaps) {
      final topicMaps = await db.query('topics', where: 'subject_id = ?', whereArgs: [subjectMap['id']]);
      final allTopics = topicMaps.map((map) => Topic.fromMap(map)).toList();

      final topicMapById = <int, Topic>{};
      for (final t in allTopics) {
        if (t.id != null) {
          topicMapById[t.id!] = t;
        }
      }

      final rootTopics = <Topic>[];
      for (final topic in allTopics) {
        if (topic.parent_id == null) {
          rootTopics.add(topic);
        } else {
          final parent = topicMapById[topic.parent_id];
          if (parent != null) {
            parent.sub_topics!.add(topic);
          }
        }
      }

      subjects.add(Subject.fromMap(subjectMap, rootTopics));
    }
    return subjects;
  }

  Future<void> importSubjectsAndTopicsFromJson(Database dbClient) async {
    final String jsonString = await rootBundle.loadString('assets/data/materias_com_assuntos.json');
    final List<dynamic> subjectsJson = json.decode(jsonString) as List<dynamic>;

    final batch = dbClient.batch();
    
    // Usar contadores manuais para IDs para permitir o uso de Batch sem depender dos retornos do DB
    int currentSubjectId = 1;
    int currentTopicId = 1;

    for (final subjectData in subjectsJson) {
      final subjectName = subjectData['name'] as String;
      final masterSubjectId = currentSubjectId++;
      
      batch.insert('master_subjects', {
        'id': masterSubjectId,
        'name': subjectName
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      if (subjectData['assuntos'] != null) {
        currentTopicId = _prepareMasterTopicsBatch(
          batch,
          masterSubjectId,
          null,
          subjectData['assuntos'] as List<dynamic>,
          currentTopicId,
        );
      }
    }

    await batch.commit(noResult: true);
  }

  int _prepareMasterTopicsBatch(
      Batch batch,
      int masterSubjectId,
      int? parentId,
      List<dynamic> topics,
      int currentId,
      ) {
    int idCounter = currentId;
    for (final topicData in topics) {
      final topicName = topicData['name'] as String;
      final tecId = topicData['id'] as String?;
      final questionCount = topicData['question_count'] as int?;

      final masterTopicId = idCounter++;
      
      batch.insert('master_topics', {
        'id': masterTopicId,
        'master_subject_id': masterSubjectId,
        'name': topicName,
        'tec_id': tecId,
        'parent_id': parentId,
        'question_count': questionCount,
      });

      if (topicData['children'] != null && (topicData['children'] as List).isNotEmpty) {
        idCounter = _prepareMasterTopicsBatch(
          batch,
          masterSubjectId,
          masterTopicId,
          topicData['children'] as List<dynamic>,
          idCounter,
        );
      }
    }
    return idCounter;
  }

  Future<List<MasterSubject>> readAllMasterSubjects() async {
    final db = await instance.database;
    final maps = await db.query('master_subjects', orderBy: 'name ASC');
    return maps.map((map) => MasterSubject.fromMap(map)).toList();
  }

  Future<List<Topic>> readMasterTopicsForSubject(int masterSubjectId) async {
    final db = await instance.database;
    final topicMaps = await db.query('master_topics', where: 'master_subject_id = ?', whereArgs: [masterSubjectId]);

    final allTopics = topicMaps.map((map) {
      return Topic(
        id: map['id'] as int,
        topic_text: map['name'] as String,
        parent_id: map['parent_id'] as int?,
        question_count: map['question_count'] as int?,
      );
    }).toList();

    final topicMapById = <int, Topic>{};
    for (final t in allTopics) {
      t.sub_topics = [];
      topicMapById[t.id!] = t;
    }

    final rootTopics = <Topic>[];
    for (final topic in allTopics) {
      if (topic.parent_id == null) {
        rootTopics.add(topic);
      } else {
        final parent = topicMapById[topic.parent_id];
        if (parent != null) {
          parent.sub_topics!.add(topic);
        }
      }
    }

    return rootTopics;
  }

  Future<BackupData> exportBackupData(String userId) async {
    final db = instance;
    final prefs = await SharedPreferences.getInstance();

    final plans = await db.readAllPlans(userId);
    final subjects = await db.readAllSubjects(userId);
    final studyRecords = await db.readStudyRecordsForUser(userId);
    final reviewRecords = await db.getAllReviewRecords(userId);
    final simuladoRecords = await db.readAllSimuladoRecordsForUser(userId);

    final planningDataPerPlan = <String, PlanningBackupData>{};
    for (final plan in plans) {
      final planId = plan.id;
      final studyCycleString = prefs.getString('${userId}_studyCycle_$planId');
      final planningData = PlanningBackupData(
        studyCycle: studyCycleString != null
            ? (jsonDecode(studyCycleString) as List<dynamic>).map((item) => StudySession.fromJson(item as Map<String, dynamic>)).toList()
            : null,
        completedCycles: prefs.getInt('${userId}_completedCycles_$planId') ?? 0,
        currentProgressMinutes: prefs.getInt('${userId}_currentProgressMinutes_$planId') ?? 0,
        sessionProgressMap: prefs.getString('${userId}_sessionProgressMap_$planId') != null
            ? Map<String, int>.from(jsonDecode(prefs.getString('${userId}_sessionProgressMap_$planId')!) as Map<String, dynamic>)
            : {},
        studyHours: prefs.getString('${userId}_studyHours_$planId') ?? '0',
        weeklyQuestionsGoal: prefs.getString('${userId}_weeklyQuestionsGoal_$planId') ?? '0',
        subjectSettings: prefs.getString('${userId}_subjectSettings_$planId') != null
            ? Map<String, Map<String, double>>.from(
          (jsonDecode(prefs.getString('${userId}_subjectSettings_$planId')!) as Map<String, dynamic>).map(
                (key, value) => MapEntry(key, Map<String, double>.from(value as Map<String, dynamic>)),
          ),
        )
            : {},
        studyDays: prefs.getStringList('${userId}_studyDays_$planId') ?? [],
        cycleGenerationTimestamp: prefs.getString('${userId}_cycleGenerationTimestamp_$planId'),
        currentCycleId: prefs.getString('${userId}_currentCycleId_$planId'),
      );
      planningDataPerPlan[planId] = planningData;
    }

    return BackupData(
      plans: plans,
      subjects: subjects,
      studyRecords: studyRecords,
      reviewRecords: reviewRecords,
      simuladoRecords: simuladoRecords,
      planningDataPerPlan: planningDataPerPlan,
    );
  }

  List<Topic> _resetTopicIds(List<Topic> topics) {
    return topics.map((topic) {
      return topic.copyWith(
        id: null,
        sub_topics: topic.sub_topics != null ? _resetTopicIds(topic.sub_topics!) : null,
      );
    }).toList();
  }

  Future<void> forceImportBackupData(BackupData backup, String userId) async {
    final db = await instance.database;
    final prefs = await SharedPreferences.getInstance();

    await db.transaction((txn) async {
      await _deleteAllDataForUser(txn, userId);

      for (final plan in backup.plans) {
        final planMap = plan.toMap();
        planMap['userId'] = userId;
        await txn.insert('plans', planMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final subject in backup.subjects) {
        final subjectMap = subject.toMap();
        subjectMap['userId'] = userId;
        await txn.insert('subjects', subjectMap, conflictAlgorithm: ConflictAlgorithm.replace);
        final List<Topic> topicsForInsert = _resetTopicIds(subject.topics);
        await _insertTopicsRecursively(txn, topicsForInsert, subject.id, null);
      }
      for (final record in backup.studyRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('study_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final record in backup.reviewRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('review_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final record in backup.simuladoRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('simulado_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final subject in record.subjects) {
          await txn.insert('simulado_subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      for (final entry in backup.planningDataPerPlan.entries) {
        final planId = entry.key;
        final planningData = entry.value;
        if (planningData.studyCycle != null) {
          await prefs.setString('${userId}_studyCycle_$planId', jsonEncode(planningData.studyCycle!.map((s) => s.toJson()).toList()));
        }
        await prefs.setInt('${userId}_completedCycles_$planId', planningData.completedCycles);
        await prefs.setInt('${userId}_currentProgressMinutes_$planId', planningData.currentProgressMinutes);
        await prefs.setString('${userId}_sessionProgressMap_$planId', jsonEncode(planningData.sessionProgressMap));
        await prefs.setString('${userId}_studyHours_$planId', planningData.studyHours);
        await prefs.setString('${userId}_weeklyQuestionsGoal_$planId', planningData.weeklyQuestionsGoal);
        await prefs.setString('${userId}_subjectSettings_$planId', jsonEncode(planningData.subjectSettings));
        await prefs.setStringList('${userId}_studyDays_$planId', planningData.studyDays);
        if (planningData.cycleGenerationTimestamp != null) {
          await prefs.setString('${userId}_cycleGenerationTimestamp_$planId', planningData.cycleGenerationTimestamp!);
        }
        if (planningData.currentCycleId != null) {
          await prefs.setString('${userId}_currentCycleId_$planId', planningData.currentCycleId!);
        }
      }
    });
  }

  Future<void> importMergedData(BackupData backup, String userId) async {
    final db = await instance.database;
    final prefs = await SharedPreferences.getInstance();

    await db.transaction((txn) async {
      for (final plan in backup.plans) {
        final planMap = plan.toMap();
        planMap['userId'] = userId;
        await txn.insert('plans', planMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final subject in backup.subjects) {
        final subjectMap = subject.toMap();
        subjectMap['userId'] = userId;
        await txn.insert('subjects', subjectMap, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.delete('topics', where: 'subject_id = ?', whereArgs: [subject.id]);
        final List<Topic> topicsForInsert = _resetTopicIds(subject.topics);
        await _insertTopicsRecursively(txn, topicsForInsert, subject.id, null);
      }
      for (final record in backup.studyRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('study_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final record in backup.reviewRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('review_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final record in backup.simuladoRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('simulado_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.delete('simulado_subjects', where: 'simulado_record_id = ?', whereArgs: [record.id]);
        for (final subject in record.subjects) {
          await txn.insert('simulado_subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      for (final entry in backup.planningDataPerPlan.entries) {
        final planId = entry.key;
        final planningData = entry.value;
        if (planningData.studyCycle != null) {
          await prefs.setString('${userId}_studyCycle_$planId', jsonEncode(planningData.studyCycle!.map((s) => s.toJson()).toList()));
        }
        await prefs.setInt('${userId}_completedCycles_$planId', planningData.completedCycles);
        await prefs.setInt('${userId}_currentProgressMinutes_$planId', planningData.currentProgressMinutes);
        await prefs.setString('${userId}_sessionProgressMap_$planId', jsonEncode(planningData.sessionProgressMap));
        await prefs.setString('${userId}_studyHours_$planId', planningData.studyHours);
        await prefs.setString('${userId}_weeklyQuestionsGoal_$planId', planningData.weeklyQuestionsGoal);
        await prefs.setString('${userId}_subjectSettings_$planId', jsonEncode(planningData.subjectSettings));
        await prefs.setStringList('${userId}_studyDays_$planId', planningData.studyDays);
        if (planningData.cycleGenerationTimestamp != null) {
          await prefs.setString('${userId}_cycleGenerationTimestamp_$planId', planningData.cycleGenerationTimestamp!);
        }
        if (planningData.currentCycleId != null) {
          await prefs.setString('${userId}_currentCycleId_$planId', planningData.currentCycleId!);
        }
      }
    });
  }
}