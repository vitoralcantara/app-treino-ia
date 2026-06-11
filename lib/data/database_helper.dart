import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/exercise_set.dart';
import '../models/routine.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workout_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 12, // Aumentei a versão para 12
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE exercises ADD COLUMN image_url TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE exercises ADD COLUMN is_available INTEGER DEFAULT 1');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE exercises ADD COLUMN video_url TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE exercises ADD COLUMN suggested_sets INTEGER');
      await db.execute('ALTER TABLE exercises ADD COLUMN suggested_reps INTEGER');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE workouts ADD COLUMN is_active INTEGER DEFAULT 1');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE routines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          is_active INTEGER DEFAULT 1
        )
      ''');
      await db.execute('ALTER TABLE workouts ADD COLUMN routine_id INTEGER');
      
      final now = DateTime.now().toIso8601String();
      final routineId = await db.insert('routines', {
        'name': 'Minha Rotina',
        'created_at': now,
        'is_active': 1
      });
      
      await db.update('workouts', {'routine_id': routineId}, where: 'is_active = 1');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE workout_exercises ADD COLUMN notes TEXT');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE workout_exercises ADD COLUMN group_id TEXT');
      await db.execute('ALTER TABLE exercises ADD COLUMN technique TEXT');
      await db.execute('ALTER TABLE exercise_sets ADD COLUMN technique TEXT');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE routines ADD COLUMN suggested_duration_weeks INTEGER');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE routines ADD COLUMN frequency_type TEXT');
      await db.execute('ALTER TABLE routines ADD COLUMN frequency_value TEXT');
    }
    if (oldVersion < 12) {
      // Adicionando colunas que podem estar faltando se o onCreate anterior foi usado
      try {
        await db.execute('ALTER TABLE exercises ADD COLUMN suggested_sets INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE exercises ADD COLUMN suggested_reps INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE exercises ADD COLUMN workout_specific_notes TEXT');
      } catch (_) {}
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';
    const doubleType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE exercises (
        id $idType,
        name $textType,
        category $textTypeNullable,
        instructions $textTypeNullable,
        image_url $textTypeNullable,
        is_available INTEGER DEFAULT 1,
        video_url TEXT,
        suggested_sets INTEGER,
        suggested_reps INTEGER,
        technique TEXT,
        workout_specific_notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE routines (
        id $idType,
        name $textType,
        created_at $textType,
        is_active INTEGER DEFAULT 1,
        suggested_duration_weeks INTEGER,
        frequency_type TEXT,
        frequency_value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        id $idType,
        routine_id INTEGER,
        name $textType,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (routine_id) REFERENCES routines (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_exercises (
        id $idType,
        workout_id $intType,
        exercise_id $intType,
        position $intType,
        notes TEXT,
        group_id TEXT,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sessions (
        id $idType,
        workout_id $intType,
        workout_name $textType,
        date $textType,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_sets (
        id $idType,
        session_id $intType,
        exercise_id $intType,
        reps $intType,
        weight $doubleType,
        timestamp $textType,
        technique TEXT,
        FOREIGN KEY (session_id) REFERENCES workout_sessions (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      )
    ''');

    await _seedExercises(db);
  }

  Future _seedExercises(Database db) async {
    final basicExercises = [
      {'name': 'Supino Reto', 'category': 'Peito', 'image_url': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&q=80&w=400'},
      {'name': 'Agachamento Livre', 'category': 'Pernas', 'image_url': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?auto=format&fit=crop&q=80&w=400'},
      {'name': 'Levantamento Terra', 'category': 'Costas', 'image_url': 'https://images.unsplash.com/photo-1603287681836-b174ce5074c2?auto=format&fit=crop&q=80&w=400'},
      {'name': 'Desenvolvimento Militar', 'category': 'Ombros', 'image_url': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?auto=format&fit=crop&q=80&w=400'},
      {'name': 'Rosca Direta', 'category': 'Bíceps', 'image_url': 'https://images.unsplash.com/photo-1581009137042-c552e485697a?auto=format&fit=crop&q=80&w=400'},
      {'name': 'Tríceps Pulley', 'category': 'Tríceps', 'image_url': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&q=80&w=400'},
    ];

    for (var exercise in basicExercises) {
      await db.insert('exercises', exercise);
    }
  }

  // --- Routine Operations ---
  Future<int> createRoutine(String name, {int? durationWeeks, String? frequencyType, String? frequencyValue}) async {
    final db = await instance.database;
    return await db.insert('routines', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
      'is_active': 1,
      'suggested_duration_weeks': durationWeeks,
      'frequency_type': frequencyType,
      'frequency_value': frequencyValue,
    });
  }

  Future<void> updateRoutineFrequency(int routineId, String? type, String? value) async {
    final db = await instance.database;
    await db.update(
      'routines', 
      {'frequency_type': type, 'frequency_value': value}, 
      where: 'id = ?', 
      whereArgs: [routineId]
    );
  }

  Future<Routine?> getActiveRoutine() async {
    final db = await instance.database;
    final result = await db.query('routines', where: 'is_active = 1', limit: 1);
    if (result.isEmpty) return null;
    return Routine.fromJson(result.first);
  }

  Future<void> archiveCurrentRoutine() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.update('routines', {'is_active': 0}, where: 'is_active = 1');
      await txn.update('workouts', {'is_active': 0}, where: 'is_active = 1');
    });
  }

  Future<void> activateRoutine(int routineId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.update('routines', {'is_active': 0}, where: 'is_active = 1');
      await txn.update('workouts', {'is_active': 0}, where: 'is_active = 1');
      
      await txn.update('routines', {'is_active': 1}, where: 'id = ?', whereArgs: [routineId]);
      await txn.update('workouts', {'is_active': 1}, where: 'routine_id = ?', whereArgs: [routineId]);
    });
  }

  Future<List<Routine>> getArchivedRoutines() async {
    final db = await instance.database;
    final result = await db.query('routines', where: 'is_active = 0', orderBy: 'created_at DESC');
    
    List<Routine> routines = [];
    for (var row in result) {
      final id = row['id'] as int;
      final workoutsRows = await db.query('workouts', where: 'routine_id = ?', whereArgs: [id]);
      
      final List<Workout> workouts = [];
      for (var wRow in workoutsRows) {
        final wId = wRow['id'] as int;
        final exercisesRows = await db.rawQuery('''
          SELECT e.*, we.notes, we.group_id FROM exercises e
          JOIN workout_exercises we ON e.id = we.exercise_id
          WHERE we.workout_id = ?
          ORDER BY we.position
        ''', [wId]);
        
        workouts.add(Workout(
          id: wId,
          routineId: id,
          name: wRow['name'] as String,
          isActive: false,
          exercises: exercisesRows.map((e) => Exercise.fromJson(e)).toList(),
        ));
      }

      routines.add(Routine.fromJson(row).copyWith(workouts: workouts));
    }
    return routines;
  }

  // --- Exercise Operations ---
  Future<List<Exercise>> getAllExercises() async {
    final db = await instance.database;
    final result = await db.query('exercises', orderBy: 'name');
    return result.map((json) => Exercise.fromJson(json)).toList();
  }

  Future<int> createExercise(Exercise exercise) async {
    final db = await instance.database;
    
    final exerciseMap = exercise.toJson();
    exerciseMap.remove('group_id');
    
    return await db.insert('exercises', exerciseMap);
  }

  Future<void> deleteExercise(int id) async {
    final db = await instance.database;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateExercise(Exercise exercise) async {
    final db = await instance.database;
    final exerciseMap = exercise.toJson();
    exerciseMap.remove('group_id');
    
    await db.update(
      'exercises',
      exerciseMap,
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<void> toggleExerciseAvailability(int id, bool isAvailable) async {
    final db = await instance.database;
    await db.update(
      'exercises',
      {'is_available': isAvailable ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Workout Operations ---
  Future<int> createWorkout(Workout workout) async {
    final db = await instance.database;
    
    int? routineId = workout.routineId;
    if (routineId == null) {
      final activeRoutines = await db.query('routines', where: 'is_active = 1', limit: 1);
      if (activeRoutines.isNotEmpty) {
        routineId = activeRoutines.first['id'] as int;
      } else {
        routineId = await createRoutine('Nova Rotina');
      }
    }

    final id = await db.insert('workouts', {
      'routine_id': routineId,
      'name': workout.name,
      'is_active': workout.isActive ? 1 : 0,
    });
    
    for (int i = 0; i < workout.exercises.length; i++) {
      final exercise = workout.exercises[i];
      int exerciseId = exercise.id ?? 0;
      
      if (exerciseId == 0) {
         final exerciseMap = exercise.toJson();
         exerciseMap.remove('group_id');
         exerciseId = await db.insert('exercises', exerciseMap);
      }

      await db.insert('workout_exercises', {
        'workout_id': id,
        'exercise_id': exerciseId,
        'position': i,
        'notes': exercise.workoutSpecificNotes,
        'group_id': exercise.groupId,
      });
    }
    return id;
  }

  Future<void> toggleWorkoutActivity(int id, bool isActive) async {
    final db = await instance.database;
    await db.update('workouts', {'is_active': isActive ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateExerciseNotesInWorkout(int workoutId, int exerciseId, String notes) async {
    final db = await instance.database;
    await db.update(
      'workout_exercises',
      {'notes': notes},
      where: 'workout_id = ? AND exercise_id = ?',
      whereArgs: [workoutId, exerciseId],
    );
  }

  Future<void> addExerciseToWorkout(int workoutId, int exerciseId, {String? notes, String? groupId}) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT MAX(position) as max_pos FROM workout_exercises WHERE workout_id = ?',
      [workoutId],
    );
    int nextPos = (result.first['max_pos'] as int? ?? -1) + 1;

    await db.insert('workout_exercises', {
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'position': nextPos,
      'notes': notes,
      'group_id': groupId,
    });
  }

  Future<void> removeExerciseFromWorkout(int workoutId, int exerciseId) async {
    final db = await instance.database;
    await db.delete(
      'workout_exercises',
      where: 'workout_id = ? AND exercise_id = ?',
      whereArgs: [workoutId, exerciseId],
    );
  }

  Future<void> deleteWorkout(int id) async {
    final db = await instance.database;
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Workout>> getAllWorkouts({bool? activeOnly}) async {
    final db = await instance.database;
    final String? where = activeOnly == null ? null : (activeOnly ? 'is_active = 1' : 'is_active = 0');
    final result = await db.query('workouts', where: where);
    
    List<Workout> workouts = [];
    for (var row in result) {
      final id = row['id'] as int;
      final exercisesRows = await db.rawQuery('''
        SELECT e.*, we.notes, we.group_id FROM exercises e
        JOIN workout_exercises we ON e.id = we.exercise_id
        WHERE we.workout_id = ?
        ORDER BY we.position
      ''', [id]);

      workouts.add(Workout(
        id: id,
        routineId: row['routine_id'] as int?,
        name: row['name'] as String,
        isActive: (row['is_active'] as int? ?? 1) == 1,
        exercises: exercisesRows.map((e) => Exercise.fromJson(e)).toList(),
      ));
    }
    return workouts;
  }

  // --- Session Operations ---
  Future<int> createWorkoutSession(WorkoutSession session) async {
    final db = await instance.database;
    final id = await db.insert('workout_sessions', {
      'workout_id': session.workoutId,
      'workout_name': session.workoutName,
      'date': session.date.toIso8601String(),
    });

    for (var set in session.sets) {
      await db.insert('exercise_sets', {
        'session_id': id,
        'exercise_id': set.exerciseId,
        'reps': set.reps,
        'weight': set.weight,
        'timestamp': DateTime.now().toIso8601String(),
        'technique': set.technique,
      });
    }
    return id;
  }

  Future<List<WorkoutSession>> getAllSessions() async {
    final db = await instance.database;
    final result = await db.query('workout_sessions', orderBy: 'date DESC');
    
    List<WorkoutSession> sessions = [];
    for (var row in result) {
      final id = row['id'] as int;
      final setsRows = await db.query('exercise_sets', where: 'session_id = ?', whereArgs: [id]);

      sessions.add(WorkoutSession(
        id: id,
        workoutId: row['workout_id'] as int,
        workoutName: row['workout_name'] as String,
        date: DateTime.parse(row['date'] as String),
        sets: setsRows.map((s) => ExerciseSet.fromJson(s)).toList(),
      ));
    }
    return sessions;
  }

  Future<List<Map<String, dynamic>>> getExerciseHistory(int exerciseId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT ws.date, es.reps, es.weight, es.technique
      FROM exercise_sets es
      JOIN workout_sessions ws ON es.session_id = ws.id
      WHERE es.exercise_id = ?
      ORDER BY ws.date DESC, es.id ASC
    ''', [exerciseId]);
    return result;
  }

  Future<int> getSessionsCountForRoutine(int routineId) async {
    final db = await instance.database;
    final workouts = await db.query('workouts', where: 'routine_id = ?', whereArgs: [routineId]);
    if (workouts.isEmpty) return 0;
    
    final workoutIds = workouts.map((w) => w['id']).join(',');
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM workout_sessions WHERE workout_id IN ($workoutIds)');
    return result.first['count'] as int? ?? 0;
  }

  Future<void> restoreFromBackup(Map<String, dynamic> backupData) async {
    final db = await instance.database;
    
    await db.transaction((txn) async {
      // 1. Limpar todas as tabelas (ordem reversa de dependência)
      await txn.delete('exercise_sets');
      await txn.delete('workout_sessions');
      await txn.delete('workout_exercises');
      await txn.delete('workouts');
      await txn.delete('routines');
      await txn.delete('exercises');

      // 2. Restaurar Exercícios
      final List<dynamic> exercises = backupData['exercises'] ?? [];
      for (var exJson in exercises) {
        await txn.insert('exercises', exJson as Map<String, dynamic>);
      }

      // 3. Restaurar Rotinas
      final List<dynamic> routines = backupData['archived_routines'] ?? [];
      for (var rJson in routines) {
        // Remove 'workouts' se vier no JSON pois é carregado dinamicamente
        final Map<String, dynamic> cleanR = Map.from(rJson as Map<String, dynamic>);
        cleanR.remove('workouts');
        await txn.insert('routines', cleanR);
      }

      // 4. Restaurar Treinos
      final List<dynamic> workouts = backupData['workouts'] ?? [];
      for (var wJson in workouts) {
        final Map<String, dynamic> cleanW = Map.from(wJson as Map<String, dynamic>);
        final List<dynamic> exercisesList = cleanW.remove('exercises') ?? [];
        
        final workoutId = await txn.insert('workouts', cleanW);

        // Restaurar Vínculo Treino-Exercício
        for (int i = 0; i < exercisesList.length; i++) {
          final ex = exercisesList[i];
          await txn.insert('workout_exercises', {
            'workout_id': workoutId,
            'exercise_id': ex['id'],
            'position': i,
            'notes': ex['workout_specific_notes'] ?? ex['notes'],
            'group_id': ex['group_id'],
          });
        }
      }

      // 5. Restaurar Sessões e Séries
      final List<dynamic> sessions = backupData['sessions'] ?? [];
      for (var sJson in sessions) {
        final Map<String, dynamic> cleanS = Map.from(sJson as Map<String, dynamic>);
        final List<dynamic> setsList = cleanS.remove('sets') ?? [];
        
        final sessionId = await txn.insert('workout_sessions', cleanS);

        for (var setJson in setsList) {
          await txn.insert('exercise_sets', {
            ...setJson as Map<String, dynamic>,
            'session_id': sessionId,
          });
        }
      }
    });
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
