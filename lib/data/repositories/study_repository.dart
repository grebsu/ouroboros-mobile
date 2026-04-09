/*
 * Ouroboros Mobile - Estudo inteligente e autônomo
 * Copyright (C) 2025 Glebson (grebsu)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyRepository {
  final Database db;
  final SharedPreferences prefs;
  final Map<String, dynamic> _memoryCache = {};
  
  StudyRepository({required this.db, required this.prefs});
  
  // --- Interface NoSQL-like (útil para UI) ---
  Future<List<Map<String, dynamic>>> getSessionsByTopic(String topicName, {bool forceRefresh = false}) async {
    final cacheKey = 'sessions_topic_$topicName';
    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }
    
    final result = await db.rawQuery('''
      SELECT 
        s.*,
        json_object('id', t.id, 'name', t.name, 'area', sa.name) as topic_info
      FROM study_sessions s
      JOIN topics t ON s.topic_id = t.id
      JOIN subject_areas sa ON t.subject_area_id = sa.id
      WHERE t.name = ?
      ORDER BY s.study_date DESC
    ''', [topicName]);
    
    _memoryCache[cacheKey] = result;
    return result;
  }
  
  // --- Método para relatório agregado (poder do SQL) ---
  Future<List<Map<String, dynamic>>> getHoursPerSubjectArea(DateTime start, DateTime end) async {
    return await db.rawQuery('''
      SELECT 
        sa.name as area,
        SUM(s.minutes) / 60.0 as hours,
        COUNT(DISTINCT s.topic_id) as topics_count
      FROM study_sessions s
      JOIN topics t ON s.topic_id = t.id
      JOIN subject_areas sa ON t.subject_area_id = sa.id
      WHERE s.study_date BETWEEN ? AND ?
      GROUP BY sa.id
      ORDER BY hours DESC
    ''', [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
  }
  
  // --- Sincronização (crítica para Wi-Fi sync) ---
  Future<void> syncSessions(List<Map<String, dynamic>> remoteSessions) async {
    await db.transaction((txn) async {
      for (final session in remoteSessions) {
        // Upsert com resolução por updated_at
        await txn.rawInsert('''
          INSERT OR REPLACE INTO study_sessions 
            (id, topic_id, study_date, minutes, session_type, correct_answers, wrong_answers, metadata, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          session['id'],
          session['topic_id'],
          session['study_date'],
          session['minutes'],
          session['session_type'],
          session['correct_answers'],
          session['wrong_answers'],
          session['metadata'],
          DateTime.now().millisecondsSinceEpoch
        ]);
      }
    });
    _memoryCache.clear(); // invalida todo cache
  }
  
  // Limpeza de cache (útil em logout)
  void clearCache() => _memoryCache.clear();
}
