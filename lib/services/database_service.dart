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
      version: 12, // Подняли до 12 для модуля Бюджета
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 0. Категории задач
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

    // 1. Задачи
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

    // 2. События Календаря
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

    // 3. Привычки
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
        position INTEGER DEFAULT 0,
        streak INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 3.1 Логи привычек
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
      CREATE INDEX idx_habit_logs_date ON habit_logs(habit_id, date);
    ''');

    // 4. Заметки
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

    // 5. Бюджет: Счета (Accounts)
    await db.execute('''
      CREATE TABLE budget_accounts (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'card', 'saving', 'debt', 'credit'
        balance REAL NOT NULL DEFAULT 0.0,
        currency TEXT DEFAULT '₽',
        color INTEGER DEFAULT 4281373137,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 5.1 Бюджет: Категории (Categories)
    await db.execute('''
      CREATE TABLE budget_categories (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'expense', 'income'
        icon TEXT DEFAULT 'category',
        color INTEGER DEFAULT 4281373137,
        monthly_limit REAL DEFAULT 0.0,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 5.2 Бюджет: Транзакции (Transactions)
    await db.execute('''
      CREATE TABLE budget_transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL, -- 'expense', 'income'
        category TEXT NOT NULL,
        account_id TEXT,
        date TEXT NOT NULL,
        is_planned INTEGER DEFAULT 0,
        is_completed INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 6. Дневник
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

    // 7. График смен
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

    // 8. Сейф
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

    // 9. Календари
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

    // 10. Очередь удаления
    await db.execute('''
      CREATE TABLE delete_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 11. Настройки
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 12) {
      // Создаем счета
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budget_accounts (
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

      // Создаем категории бюджета
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budget_categories (
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

      // Дополняем существующую таблицу budget_transactions новыми колонками
      final txCols = await db.rawQuery(
        'PRAGMA table_info(budget_transactions)',
      );
      final colNames = txCols.map((c) => c['name'] as String).toSet();

      if (!colNames.contains('account_id')) {
        await db.execute(
          "ALTER TABLE budget_transactions ADD COLUMN account_id TEXT",
        );
      }
      if (!colNames.contains('is_planned')) {
        await db.execute(
          "ALTER TABLE budget_transactions ADD COLUMN is_planned INTEGER DEFAULT 0",
        );
      }
      if (!colNames.contains('is_completed')) {
        await db.execute(
          "ALTER TABLE budget_transactions ADD COLUMN is_completed INTEGER DEFAULT 1",
        );
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
      await txn.delete('shift_schedules');
      await txn.delete('vault_documents');
      await txn.delete('user_calendars');
      await txn.delete('delete_queue');
      await txn.delete('app_settings');
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) await db.close();
  }
}
