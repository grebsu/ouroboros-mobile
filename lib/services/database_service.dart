
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/data_models.dart';
import '../models/backup_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<void> forceDeleteDatabase() async {
    // Close the database if it's open
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    // Get the path and delete the file
    try {
      final dbPath = await getApplicationDocumentsDirectory();
      final path = join(dbPath.path, 'ouroboros.db');
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print('!!!!!!!!!! Database file deleted successfully. !!!!!!!!!!');
      } else {
        print('!!!!!!!!!! Database file not found, nothing to delete. !!!!!!!!!!');
      }
    } catch (e) {
      print('!!!!!!!!!! Error deleting database file: $e !!!!!!!!!!');
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ouroboros.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);
    return await openDatabase(path, version: 16, onCreate: _createDB, onUpgrade: _onUpgrade, onConfigure: _onConfigure); // VERSÃO ATUALIZADA PARA 16
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
      await db.execute('ALTER TABLE study_records ADD COLUMN userId TEXT NOT NULL DEFAULT \'\'');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE subjects ADD COLUMN userId TEXT NOT NULL DEFAULT \'\'');
      await db.execute('ALTER TABLE simulado_records ADD COLUMN userId TEXT NOT NULL DEFAULT \'\'');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE review_records ADD COLUMN userId TEXT NOT NULL DEFAULT \'\'');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE plans ADD COLUMN userId TEXT NOT NULL DEFAULT \'\'');
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
    if (oldVersion < 14) { // NOVA MIGRAÇÃO PARA MULTI-TÓPICOS
      // Renomeia a tabela existente para não perder os dados
      await db.execute('ALTER TABLE study_records RENAME TO study_records_old');

      // Cria a nova tabela com a estrutura atualizada
      await db.execute('''
        CREATE TABLE study_records (
          id TEXT PRIMARY KEY,
          userId TEXT NOT NULL,
          plan_id TEXT NOT NULL,
          date TEXT NOT NULL,
          subject_id TEXT NOT NULL,
          topic_texts TEXT NOT NULL, -- Nova coluna para lista de textos de tópicos (JSON)
          topic_ids TEXT NOT NULL,   -- Nova coluna para lista de IDs de tópicos (JSON)
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
      
      // Idealmente, aqui ocorreria a migração dos dados de study_records_old para study_records.
      // Como o schema antigo é incerto, manter a tabela _old previne a perda de dados
      // e resolve o erro de "no such table" caso algum trigger a referencie.
    }
    if (oldVersion < 15) {
      // 1. Renomear a tabela antiga
      await db.execute('ALTER TABLE review_records RENAME TO review_records_old;');

      // 2. Criar a nova tabela com a coluna 'topics' (TEXT) e sem a coluna 'topic'
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
          topics TEXT NOT NULL, -- Nova coluna para lista de tópicos (JSON)
          review_period TEXT NOT NULL,
          completed_date TEXT,
          ignored INTEGER NOT NULL,
          lastModified INTEGER,
          FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE,
          FOREIGN KEY (study_record_id) REFERENCES study_records (id) ON DELETE CASCADE,
          FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE SET NULL
        )
      ''');

      // 3. Copiar os dados da tabela antiga para a nova, transformando 'topic' em 'topics' (JSON Array)
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

      // 4. Apagar a tabela antiga
      await db.execute('DROP TABLE review_records_old;');
    }
    if (oldVersion < 16) { // Migração para adicionar question_count à master_topics
      await db.execute('ALTER TABLE master_topics ADD COLUMN question_count INTEGER;');
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
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

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL'; // SQLite uses INTEGER 0 (false) or 1 (true) for booleans

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
        date $textType,
        subject_id $textType,
        topic_texts $textType, -- Nova coluna para lista de textos de tópicos (JSON)
        topic_ids $textType,   -- Nova coluna para lista de IDs de tópicos (JSON)
        category $textType,
        study_time $integerType,
        questions $textType, -- JSON stored as TEXT
        material $textTypeNullable,
        notes $textTypeNullable,
        review_periods $textType, -- JSON stored as TEXT
        teoria_finalizada $boolType,
        count_in_planning $boolType,
        pages $textType, -- JSON stored as TEXT
        videos $textType, -- JSON stored as TEXT
        lastModified INTEGER,
        FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE SET NULL
      )
    ''');

    // TODO: Create tables for ReviewRecord, SimuladoRecord, etc.
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

    await _createMasterTables(db);
    await importSubjectsAndTopicsFromJson(db); // Importar dados mestre
  }

  // TODO: Implement CRUD methods for each data model

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
    return db.update(
      'plans',
      plan.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [plan.id, userId],
    );
  }

  Future<int> deletePlan(String id, String userId) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // Primeiro, deletar todas as matérias associadas a este plano
      await txn.delete(
        'subjects',
        where: 'plan_id = ? AND userId = ?',
        whereArgs: [id, userId],
      );
      // Em seguida, deletar o plano
      return txn.delete(
        'plans',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, userId],
      );
    });
  }

  // Subject and Topic CRUD methods
  Future<void> _insertTopicsRecursively(Transaction txn, List<Topic> topics, String subjectId, int? parentId) async {
    for (final topic in topics) {
      // Determine if this topic should be a grouping topic based on its sub_topics
      final bool isCurrentlyGrouping = topic.sub_topics != null && topic.sub_topics!.isNotEmpty;

      final topicToInsert = Topic(
        subject_id: subjectId,
        topic_text: topic.topic_text,
        parent_id: parentId,
        is_grouping_topic: isCurrentlyGrouping, // CORRIGIDO AQUI
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
      for (var t in allTopics) {
        if (t.id != null) {
          // REMOVER ESTA LINHA: t.sub_topics = [];
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
        {
          'subject': subject.subject,
          'color': subject.color,
        },
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
    return db.delete(
      'subjects',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<void> updateTopicWeights(Map<int, int> weights) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      weights.forEach((topicId, weight) {
        batch.update(
          'topics',
          {'userWeight': weight},
          where: 'id = ?',
          whereArgs: [topicId],
        );
      });
      await batch.commit(noResult: true);
    });
  }

  // StudyRecord CRUD methods
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
    return db.update(
      'study_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteStudyRecord(String id) async {
    final db = await instance.database;
    return db.delete(
      'study_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<StudyRecord>> readStudyRecordsForUser(String userId) async {
    final db = await instance.database;
    final maps = await db.query('study_records', where: 'userId = ?', whereArgs: [userId], orderBy: 'date DESC');
    return maps.map((map) => StudyRecord.fromMap(map)).toList();
  }

  // ReviewRecord CRUD methods
  Future<void> createReviewRecord(ReviewRecord record, String userId) async {
    final db = await instance.database;
    final recordMap = record.toMap();
    recordMap['userId'] = userId;
    await db.insert('review_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReviewRecord>> readReviewRecordsForPlan(String planId, String userId) async {
    final db = await instance.database;
    final maps = await db.query('review_records', where: 'plan_id = ? AND userId = ?', whereArgs: [planId, userId], orderBy: 'scheduled_date ASC');
    return maps.map((map) => ReviewRecord.fromMap(map)).toList();
  }

  Future<int> updateReviewRecord(ReviewRecord record, String userId) async {
    final db = await instance.database;
    return db.update(
      'review_records',
      record.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [record.id, userId],
    );
  }

  Future<int> deleteReviewRecord(String id, String userId) async {
    final db = await instance.database;
    return db.delete(
      'review_records',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
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

  // SimuladoRecord CRUD methods
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
    final recordMaps = await db.query('simulado_records', where: 'plan_id = ? AND userId = ?', whereArgs: [planId, userId], orderBy: 'date DESC');

    if (recordMaps.isEmpty) {
      return [];
    }

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

    if (recordMaps.isEmpty) {
      return [];
    }

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
    // Deleting a simulado_record will also delete its simulado_subjects due to ON DELETE CASCADE
    return db.delete(
      'simulado_records',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  // Count methods for stats
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
    if (_database == null) {
      return;
    }
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, 'ouroboros.db');
    
    await _database!.close();
    await deleteDatabase(path);
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
      // Inserir planos
      for (final plan in backup.plans) {
        final planMap = plan.toMap();
        planMap['userId'] = userId;
        await txn.insert('plans', planMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Inserir matérias e tópicos
      for (final subject in backup.subjects) {
        final subjectMap = subject.toMap();
        subjectMap['userId'] = userId;
        await txn.insert('subjects', subjectMap, conflictAlgorithm: ConflictAlgorithm.replace);
        await _insertTopicsRecursively(txn, subject.topics, subject.id, null);
      }
      // Inserir registros de estudo
      for (final record in backup.studyRecords) {
        await txn.insert('study_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Inserir registros de revisão
      for (final record in backup.reviewRecords) {
        await txn.insert('review_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Inserir registros de simulado
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
      for (var t in allTopics) {
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

  // Master Subject/Topic Import
  Future<void> importSubjectsAndTopicsFromJson(Database dbClient) async {
    final String jsonString = await rootBundle.loadString('assets/data/materias_com_assuntos.json');
    final List<dynamic> subjectsJson = json.decode(jsonString);

    await dbClient.transaction((txn) async {
      final existingSubjects = await txn.query('master_subjects');
      if (existingSubjects.isNotEmpty) {
        // Se já existem dados, não faz nada para evitar duplicação.
        // Uma lógica mais avançada poderia ser de atualização (merge).
        return;
      }

      for (var subjectData in subjectsJson) {
        final subjectName = subjectData['name'];
        final masterSubjectId = await txn.insert(
          'master_subjects',
          {'name': subjectName},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        if (subjectData['assuntos'] != null) {
          await _insertMasterTopicsRecursive(
            txn,
            masterSubjectId,
            null,
            subjectData['assuntos'],
          );
        }
      }
    });
  }

  Future<void> _insertMasterTopicsRecursive(
    Transaction txn,
    int masterSubjectId,
    int? parentId,
    List<dynamic> topics,
  ) async {
    for (var topicData in topics) {
      final topicName = topicData['name'];
      final tecId = topicData['id'];

      final questionCount = topicData['question_count']; // Obter question_count do JSON

      final masterTopicId = await txn.insert('master_topics', {
        'master_subject_id': masterSubjectId,
        'name': topicName,
        'tec_id': tecId,
        'parent_id': parentId,
        'question_count': questionCount, // Inserir question_count
      });

      if (topicData['children'] != null && (topicData['children'] as List).isNotEmpty) {
        await _insertMasterTopicsRecursive(
          txn,
          masterSubjectId,
          masterTopicId,
          topicData['children'],
        );
      }
    }
  }

  // Master Subject/Topic Read
  Future<List<MasterSubject>> readAllMasterSubjects() async {
    final db = await instance.database;
    final maps = await db.query('master_subjects', orderBy: 'name ASC');
    return maps.map((map) => MasterSubject.fromMap(map)).toList();
  }

  Future<List<Topic>> readMasterTopicsForSubject(int masterSubjectId) async {
    final db = await instance.database;
    final topicMaps = await db.query('master_topics', where: 'master_subject_id = ?', whereArgs: [masterSubjectId]);
    
    final allTopics = topicMaps.map((map) {
      // Converte o MasterTopic em um Topic para compatibilidade com o resto do app
      return Topic(
        id: map['id'] as int, // Usamos o ID do master_topic para reconstruir a árvore
        topic_text: map['name'] as String,
        parent_id: map['parent_id'] as int?,
        question_count: map['question_count'] as int?,
      );
    }).toList();

    final topicMapById = <int, Topic>{};
    for (var t in allTopics) {
      t.sub_topics = [];
      // Usa o 'id' do master_topic como chave
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
    final db = instance; // Já é um singleton
    final prefs = await SharedPreferences.getInstance();

    final plans = await db.readAllPlans(userId);
    final subjects = await db.readAllSubjects(userId); // subjects here should have full hierarchy
    final studyRecords = await db.readStudyRecordsForUser(userId);
    final reviewRecords = await db.getAllReviewRecords(userId);
    final simuladoRecords = await db.readAllSimuladoRecordsForUser(userId);

    final planningDataPerPlan = <String, PlanningBackupData>{};
    for (final plan in plans) {
      final planId = plan.id;
      final studyCycleString = prefs.getString('${userId}_studyCycle_$planId');
      final planningData = PlanningBackupData(
        studyCycle: studyCycleString != null
            ? (jsonDecode(studyCycleString) as List).map((item) => StudySession.fromJson(item)).toList()
            : null,
        completedCycles: prefs.getInt('${userId}_completedCycles_$planId') ?? 0,
        currentProgressMinutes: prefs.getInt('${userId}_currentProgressMinutes_$planId') ?? 0,
        sessionProgressMap: prefs.getString('${userId}_sessionProgressMap_$planId') != null
            ? Map<String, int>.from(jsonDecode(prefs.getString('${userId}_sessionProgressMap_$planId')!))
            : {},
        studyHours: prefs.getString('${userId}_studyHours_$planId') ?? '0',
        weeklyQuestionsGoal: prefs.getString('${userId}_weeklyQuestionsGoal_$planId') ?? '0',
        subjectSettings: prefs.getString('${userId}_subjectSettings_$planId') != null
            ? Map<String, Map<String, double>>.from(
                jsonDecode(prefs.getString('${userId}_subjectSettings_$planId')!).map((key, value) => MapEntry(key, Map<String, double>.from(value))))
            : {},
        studyDays: prefs.getStringList('${userId}_studyDays_$planId') ?? [],
        cycleGenerationTimestamp: prefs.getString('${userId}_cycleGenerationTimestamp_$planId'),
      );
      planningDataPerPlan[planId] = planningData;
    }

    return BackupData(
      plans: plans,
      subjects: subjects, // Directly use subjects which already contain the hierarchy
      studyRecords: studyRecords,
      reviewRecords: reviewRecords,
      simuladoRecords: simuladoRecords,
      planningDataPerPlan: planningDataPerPlan,
    );
  }

  Future<void> forceImportBackupData(BackupData backup, String userId) async {
    final db = await instance.database;
    final prefs = await SharedPreferences.getInstance();

    await db.transaction((txn) async {
      // 1. Apagar todos os dados existentes para o usuário
      await _deleteAllDataForUser(txn, userId);

      // 2. Inserir planos
      for (final plan in backup.plans) {
        final planMap = plan.toMap();
        planMap['userId'] = userId;
        await txn.insert('plans', planMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // 3. Inserir matérias e tópicos
      for (final subject in backup.subjects) {
        final subjectMap = subject.toMap();
        subjectMap['userId'] = userId;
        await txn.insert('subjects', subjectMap, conflictAlgorithm: ConflictAlgorithm.replace);
        // Garante que os IDs dos tópicos sejam null para serem auto-incrementados novamente
        // e reconstrói a árvore para ser imune a erros de deserialização.
        
        // A lista de tópicos do backup agora deve ser hierárquica.
        List<Topic> topicsForInsert = _resetTopicIds(subject.topics);
        await _insertTopicsRecursively(txn, topicsForInsert, subject.id, null);
      }
      // 4. Inserir registros de estudo
      for (final record in backup.studyRecords) {
        // Garante que o userId esteja correto no registro
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('study_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // 5. Inserir registros de revisão
      for (final record in backup.reviewRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('review_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // 6. Inserir registros de simulado
      for (final record in backup.simuladoRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('simulado_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final subject in record.subjects) {
          await txn.insert('simulado_subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 7. Atualizar SharedPreferences para planejamento
      for (var entry in backup.planningDataPerPlan.entries) {
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
      }
    });
  }

  Future<void> importMergedData(BackupData backup, String userId) async {
    final db = await instance.database;
    final prefs = await SharedPreferences.getInstance();

    await db.transaction((txn) async {
      // Planos
      for (final plan in backup.plans) {
        final planMap = plan.toMap();
        planMap['userId'] = userId;
        await txn.insert('plans', planMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Matérias e tópicos
      for (final subject in backup.subjects) {
        final subjectMap = subject.toMap();
        subjectMap['userId'] = userId;
        await txn.insert('subjects', subjectMap, conflictAlgorithm: ConflictAlgorithm.replace);
        // Excluir e reinserir tópicos para garantir consistência
        await txn.delete('topics', where: 'subject_id = ?', whereArgs: [subject.id]);
        List<Topic> topicsForInsert = _resetTopicIds(subject.topics);
        await _insertTopicsRecursively(txn, topicsForInsert, subject.id, null);
      }
      // Registros de estudo
      for (final record in backup.studyRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('study_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Registros de revisão
      for (final record in backup.reviewRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('review_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Registros de simulado
      for (final record in backup.simuladoRecords) {
        final recordMap = record.toMap();
        recordMap['userId'] = userId;
        await txn.insert('simulado_records', recordMap, conflictAlgorithm: ConflictAlgorithm.replace);
        // Excluir e reinserir simulado_subjects
        await txn.delete('simulado_subjects', where: 'simulado_record_id = ?', whereArgs: [record.id]);
        for (final subject in record.subjects) {
          await txn.insert('simulado_subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Atualizar SharedPreferences para planejamento
      for (var entry in backup.planningDataPerPlan.entries) {
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
      }
    });
  }

  // Helper para resetar IDs de tópicos para auto-incremento
  List<Topic> _resetTopicIds(List<Topic> topics) {
    return topics.map((topic) {
      return topic.copyWith(
        id: null,
        sub_topics: topic.sub_topics != null ? _resetTopicIds(topic.sub_topics!) : null,
      );
    }).toList();
  }


}
