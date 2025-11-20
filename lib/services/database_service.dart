
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/data_models.dart';
import '../models/backup_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ouroboros.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);
    return await openDatabase(path, version: 11, onCreate: _createDB, onUpgrade: _onUpgrade);
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
        iconUrl $textTypeNullable
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
        topic $textType,
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
        topic $textType,
        review_period $textType,
        completed_date $textTypeNullable,
        ignored $boolType,
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
        FOREIGN KEY (simulado_record_id) REFERENCES simulado_records (id) ON DELETE CASCADE,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');
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
      columns: ['id', 'userId', 'name', 'observations', 'cargo', 'edital', 'banca', 'iconUrl'],
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
      final topicToInsert = Topic(
        subject_id: subjectId,
        topic_text: topic.topic_text,
        parent_id: parentId,
        is_grouping_topic: topic.is_grouping_topic,
        question_count: topic.question_count,
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
          // Garante que a lista de sub_topics seja inicializada para todos os tópicos
          t.sub_topics = [];
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

  Future<void> deleteAllDataForUser(String userId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      txn.delete('plans', where: 'userId = ?', whereArgs: [userId]);
      txn.delete('subjects', where: 'userId = ?', whereArgs: [userId]);
      txn.delete('study_records', where: 'userId = ?', whereArgs: [userId]);
      txn.delete('review_records', where: 'userId = ?', whereArgs: [userId]);
      txn.delete('simulado_records', where: 'userId = ?', whereArgs: [userId]);
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
          // Garante que a lista de sub_topics seja inicializada para todos os tópicos
          t.sub_topics = []; 
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
}
