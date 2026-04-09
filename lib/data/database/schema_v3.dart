const String schemaV3 = '''
-- Áreas de conhecimento
CREATE TABLE subject_areas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  display_order INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL
);

-- Tópicos (normalizados)
CREATE TABLE topics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_area_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  estimated_hours REAL,
  difficulty_level INTEGER CHECK (difficulty_level BETWEEN 1 AND 5),
  is_active INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (subject_area_id) REFERENCES subject_areas(id) ON DELETE CASCADE,
  UNIQUE(subject_area_id, name)
);

CREATE INDEX idx_topics_subject_area ON topics(subject_area_id);
CREATE INDEX idx_topics_name ON topics(name);

-- Sessões de estudo (fatos)
CREATE TABLE study_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  topic_id INTEGER NOT NULL,
  cycle_id INTEGER,                   -- opcional, se você já tem ciclo
  study_date INTEGER NOT NULL,        -- timestamp
  minutes INTEGER NOT NULL CHECK (minutes > 0),
  session_type TEXT CHECK (session_type IN ('theory', 'questions', 'video', 'reading')),
  correct_answers INTEGER,
  wrong_answers INTEGER,
  pages_read INTEGER,
  metadata TEXT,                      -- JSON para campos dinâmicos
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
);

CREATE INDEX idx_sessions_topic_date ON study_sessions(topic_id, study_date);
CREATE INDEX idx_sessions_cycle ON study_sessions(cycle_id);

-- Progresso por tópico (materialized view atualizada via trigger)
CREATE TABLE topic_progress (
  topic_id INTEGER PRIMARY KEY,
  total_minutes INTEGER DEFAULT 0,
  last_studied_at INTEGER,
  mastery_level REAL DEFAULT 0.0,     -- 0..1
  review_count INTEGER DEFAULT 0,
  FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
);

-- Trigger para manter topic_progress atualizado
CREATE TRIGGER update_topic_progress_after_insert
AFTER INSERT ON study_sessions
BEGIN
  INSERT OR REPLACE INTO topic_progress (topic_id, total_minutes, last_studied_at, mastery_level)
  VALUES (
    NEW.topic_id,
    COALESCE((SELECT total_minutes FROM topic_progress WHERE topic_id = NEW.topic_id), 0) + NEW.minutes,
    MAX(COALESCE((SELECT last_studied_at FROM topic_progress WHERE topic_id = NEW.topic_id), 0), NEW.study_date),
    -- mastery_level simples: baseado em minutos vs estimado (pode ser substituído por fórmula melhor)
    CASE 
      WHEN (SELECT estimated_hours FROM topics WHERE id = NEW.topic_id) IS NULL THEN 0.0
      ELSE MIN(1.0, (COALESCE((SELECT total_minutes FROM topic_progress WHERE topic_id = NEW.topic_id), 0) + NEW.minutes) / 
                    ((SELECT estimated_hours FROM topics WHERE id = NEW.topic_id) * 60.0))
    END
  );
END;

-- Trigger similar para UPDATE (omito por brevidade, mas essencial)
''';