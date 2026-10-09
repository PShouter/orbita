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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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
        priority TEXT DEFAULT 'none',
        done INTEGER DEFAULT 0,
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

    // 5. Очередь удаления
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
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) await db.close();
  }
}
