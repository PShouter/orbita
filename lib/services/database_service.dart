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
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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
        priority TEXT DEFAULT 'none',
        done INTEGER DEFAULT 0,
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

    // 9. Очередь удаления для оффлайн-синхронизации (Delete Queue)
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
    if (oldVersion < 2) {
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
    }
    if (oldVersion < 3) {
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
    }
    if (oldVersion < 4) {
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
    }
    if (oldVersion < 5) {
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
    }
    if (oldVersion < 6) {
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
    }
  }

  /// Полная очистка пользовательских данных при выходе (Logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('calendar_events');
      await txn.delete('habits');
      await txn.delete('notes');
      await txn.delete('budget_transactions');
      await txn.delete('diary_entries');
      await txn.delete('shift_schedules');
      await txn.delete('vault_documents');
      await txn.delete('delete_queue');
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) await db.close();
  }
}
