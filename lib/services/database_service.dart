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
      version: 9,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 0. Категории задач (Task Categories)
    await db.execute('''
      CREATE TABLE task_categories (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // Дефолтная категория
    await db.insert('task_categories', {
      'id': 'cat_personal',
      'name': 'Личное',
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // 1. Задачи (Tasks)
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

    // 2. События Календаря (Calendar Events)
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

    // 3. Привычки (Habits)
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        type TEXT DEFAULT 'binary',
        target_value REAL DEFAULT 1.0,
        unit TEXT,
        color INTEGER,
        reminder_time TEXT,
        history TEXT,
        streak INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 4. Заметки (Notes)
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        body TEXT,
        image_path TEXT,
        category TEXT DEFAULT 'Общее',
        is_pinned INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 5. Транзакции бюджета (Budget Transactions)
    await db.execute('''
      CREATE TABLE budget_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 6. Записи дневника (Diary Entries)
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

    // 7. График смен (Shift Schedules)
    await db.execute('''
      CREATE TABLE shift_schedules (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        cycle_days TEXT NOT NULL,
        overrides TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 8. Сейф - зашифрованные документы (Vault Documents)
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

    // 9. Календари пользователя (User Calendars)
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

    // 10. Очередь удаления (Delete Queue)
    await db.execute('''
      CREATE TABLE delete_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // 0. Категории задач
    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_categories (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    final catCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM task_categories'),
    );
    if (catCount == 0) {
      await db.insert('task_categories', {
        'id': 'cat_personal',
        'name': 'Личное',
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    // 1. Задачи
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
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

    // Добавляем новые колонки в tasks при необходимости
    final taskColumns = await db.rawQuery('PRAGMA table_info(tasks)');
    final colNames = taskColumns.map((c) => c['name'] as String).toSet();

    if (!colNames.contains('status')) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN status TEXT DEFAULT 'todo'",
      );
    }
    if (!colNames.contains('category')) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN category TEXT DEFAULT 'Личное'",
      );
    }
    if (!colNames.contains('color')) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN color INTEGER DEFAULT 4281373137",
      );
    }
    if (!colNames.contains('reminder_minutes')) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN reminder_minutes INTEGER DEFAULT -1",
      );
    }
    if (!colNames.contains('recurrence')) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN recurrence TEXT DEFAULT 'none'",
      );
    }
    if (!colNames.contains('attachments')) {
      await db.execute("ALTER TABLE tasks ADD COLUMN attachments TEXT");
    }

    // 2. События
    await db.execute('''
      CREATE TABLE IF NOT EXISTS calendar_events (
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

    // 3. Привычки
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        type TEXT DEFAULT 'binary',
        target_value REAL DEFAULT 1.0,
        unit TEXT,
        color INTEGER,
        reminder_time TEXT,
        history TEXT,
        streak INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 4. Заметки
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        body TEXT,
        image_path TEXT,
        category TEXT DEFAULT 'Общее',
        is_pinned INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 5. Бюджет
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budget_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 6. Дневник
    await db.execute('''
      CREATE TABLE IF NOT EXISTS diary_entries (
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

    // 7. График смен
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shift_schedules (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        cycle_days TEXT NOT NULL,
        overrides TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 8. Сейф
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vault_documents (
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

    // 9. Календари
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_calendars (
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

    // 10. Очередь удаления
    await db.execute('''
      CREATE TABLE IF NOT EXISTS delete_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('task_categories');
      await txn.delete('tasks');
      await txn.delete('calendar_events');
      await txn.delete('habits');
      await txn.delete('notes');
      await txn.delete('budget_transactions');
      await txn.delete('diary_entries');
      await txn.delete('shift_schedules');
      await txn.delete('vault_documents');
      await txn.delete('user_calendars');
      await txn.delete('delete_queue');
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) await db.close();
  }
}
