import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('orbita_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 17, // Повышено до 17 для миграции колонки history
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE task_categories (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.insert('task_categories', {
      'id': 'cat_personal',
      'name': 'Личное',
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT,
        time TEXT,
        is_no_date INTEGER DEFAULT 0,
        is_all_day INTEGER DEFAULT 0,
        priority TEXT DEFAULT 'normal',
        status TEXT DEFAULT 'todo',
        done INTEGER DEFAULT 0,
        category TEXT DEFAULT 'Личное',
        color INTEGER DEFAULT 4281373137,
        reminder_minutes INTEGER DEFAULT -1,
        recurrence TEXT DEFAULT 'none',
        attachments TEXT,
        subtasks TEXT,
        tags TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE calendar_events (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        end_date TEXT,
        start_time TEXT,
        end_time TEXT,
        is_all_day INTEGER DEFAULT 0,
        calendar TEXT,
        color INTEGER,
        description TEXT,
        location TEXT,
        reminder_minutes INTEGER DEFAULT -1,
        recurrence TEXT DEFAULT 'none',
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        question TEXT,
        description TEXT,
        type TEXT DEFAULT 'boolean',
        target_value REAL DEFAULT 1.0,
        unit TEXT,
        color INTEGER NOT NULL,
        frequency_type TEXT DEFAULT 'daily',
        frequency_days TEXT,
        frequency_count INTEGER DEFAULT 1,
        reminder_time TEXT,
        history TEXT,
        position INTEGER DEFAULT 0,
        streak INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_logs (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        date TEXT NOT NULL,
        value REAL NOT NULL DEFAULT 1.0,
        completed INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL,
        UNIQUE(habit_id, date),
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        body TEXT,
        image_path TEXT,
        attachments TEXT,
        tags TEXT,
        category TEXT DEFAULT 'Общее',
        is_pinned INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_accounts (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        currency TEXT DEFAULT '₽',
        color INTEGER DEFAULT 4281373137,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_categories (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT DEFAULT 'category',
        color INTEGER DEFAULT 4281373137,
        monthly_limit REAL DEFAULT 0.0,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        account_id TEXT,
        date TEXT NOT NULL,
        is_planned INTEGER DEFAULT 0,
        is_completed INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE diary_entries (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        date TEXT NOT NULL,
        mood TEXT DEFAULT 'neutral',
        content TEXT NOT NULL,
        tags TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE diaries (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT,
        content TEXT,
        date TEXT NOT NULL,
        mood TEXT DEFAULT 'good',
        images TEXT,
        is_draft INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE shift_schedules (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        cycle_days TEXT NOT NULL,
        overrides TEXT,
        custom_types TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE vault_documents (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        encrypted_title TEXT NOT NULL,
        category TEXT DEFAULT 'document',
        encrypted_payload TEXT NOT NULL,
        iv TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_calendars (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        color INTEGER NOT NULL,
        is_visible INTEGER DEFAULT 1,
        account_type TEXT DEFAULT 'local',
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE delete_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_gamification (
        user_id TEXT PRIMARY KEY,
        total_exp INTEGER DEFAULT 0,
        weekly_exp INTEGER DEFAULT 0,
        last_week_reset TEXT,
        habits_exp INTEGER DEFAULT 0,
        diary_exp INTEGER DEFAULT 0,
        budget_exp INTEGER DEFAULT 0,
        tasks_exp INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_achievements (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        achievement_key TEXT NOT NULL UNIQUE,
        current_value INTEGER DEFAULT 0,
        target_value INTEGER NOT NULL,
        is_unlocked INTEGER DEFAULT 0,
        unlocked_at TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_habit_logs_date ON habit_logs(habit_id, date);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_calendar_user_id ON calendar_events(user_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_habits_user_id ON habits(user_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_diary_user_id ON diary_entries(user_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_shifts_user_id ON shift_schedules(user_id);',
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_gamification (
          user_id TEXT PRIMARY KEY,
          total_exp INTEGER DEFAULT 0,
          weekly_exp INTEGER DEFAULT 0,
          last_week_reset TEXT,
          habits_exp INTEGER DEFAULT 0,
          diary_exp INTEGER DEFAULT 0,
          budget_exp INTEGER DEFAULT 0,
          tasks_exp INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 15) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_achievements (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          achievement_key TEXT NOT NULL UNIQUE,
          current_value INTEGER DEFAULT 0,
          target_value INTEGER NOT NULL,
          is_unlocked INTEGER DEFAULT 0,
          unlocked_at TEXT,
          is_synced INTEGER DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 16) {
      final shiftCols = await db.rawQuery('PRAGMA table_info(shift_schedules)');
      final colNames = shiftCols.map((c) => c['name'] as String).toSet();
      if (!colNames.contains('custom_types')) {
        await db.execute(
          'ALTER TABLE shift_schedules ADD COLUMN custom_types TEXT',
        );
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS diaries (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          title TEXT,
          content TEXT,
          date TEXT NOT NULL,
          mood TEXT DEFAULT 'good',
          images TEXT,
          is_draft INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await _createIndexes(db);
    }
    if (oldVersion < 17) {
      // Добавляем недостающую колонку history в таблицу habits
      final habitCols = await db.rawQuery('PRAGMA table_info(habits)');
      final colNames = habitCols.map((c) => c['name'] as String).toSet();
      if (!colNames.contains('history')) {
        await db.execute('ALTER TABLE habits ADD COLUMN history TEXT;');
      }
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('task_categories');
      await txn.delete('tasks');
      await txn.delete('calendar_events');
      await txn.delete('habits');
      await txn.delete('habit_logs');
      await txn.delete('notes');
      await txn.delete('budget_accounts');
      await txn.delete('budget_categories');
      await txn.delete('budget_transactions');
      await txn.delete('diary_entries');
      await txn.delete('diaries');
      await txn.delete('shift_schedules');
      await txn.delete('vault_documents');
      await txn.delete('user_calendars');
      await txn.delete('delete_queue');
      await txn.delete('app_settings');
      await txn.delete('user_gamification');
      await txn.delete('user_achievements');
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) await db.close();
  }
}
