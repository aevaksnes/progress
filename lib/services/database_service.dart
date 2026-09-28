import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Nytt, rent navn på databasen!
    _database = await _initDB('progress_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1, // Vi starter med blanke ark på versjon 1
      onConfigure: _onConfigure, // Må til for å slå på "Foreign keys"
      onCreate: _createDB,
    );
  }

  // Slår på SQLite sin evne til å la tabeller snakke sammen
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // 1. Kategoritabellen (Må opprettes først siden bilder er avhengig av den)
    await db.execute('''
      CREATE TABLE categories (
        name TEXT PRIMARY KEY,
        reminder_type TEXT NOT NULL,
        reminder_day INTEGER NOT NULL,
        reminder_hour INTEGER NOT NULL,
        reminder_minute INTEGER NOT NULL
      )
    ''');

    // 2. Bildetabellen (Bruker ditt foretrukne navn)
    await db.execute('''
      CREATE TABLE progress_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        category TEXT NOT NULL,
        date_taken TEXT NOT NULL,
        FOREIGN KEY (category) REFERENCES categories (name) ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');
  }

  // ==========================================
  // KATEGORI-FUNKSJONER
  // ==========================================

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<void> insertCategory(String name, String reminderType, int day, int hour, int minute) async {
    final db = await instance.database;
    await db.insert(
      'categories',
      {
        'name': name,
        'reminder_type': reminderType,
        'reminder_day': day,
        'reminder_hour': hour,
        'reminder_minute': minute
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Endrer du navnet på en kategori her, vil ON UPDATE CASCADE 
  // automatisk oppdatere navnet på alle bildene i progress_images!
  Future<void> updateCategory(String oldName, String newName, String reminderType, int day, int hour, int minute) async {
    final db = await instance.database;
    await db.update(
      'categories',
      {
        'name': newName,
        'reminder_type': reminderType,
        'reminder_day': day,
        'reminder_hour': hour, 
        'reminder_minute': minute
      },
      where: 'name = ?',
      whereArgs: [oldName],
    );
  }

  // Sletter en kategori og fjerner automatisk alle fysiske bildefiler
  Future<void> deleteCategory(String name) async {
    final db = await instance.database;

    // 1. Vi må hente ut alle bilder i denne kategorien og slette bildefilene fra telefonen
    final images = await getEntriesByCategory(name);
    for (var image in images) {
      final file = File(image['image_path'] as String);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // 2. Slett selve kategorien
    // (ON DELETE CASCADE sørger for at dataradene i progress_images slettes automatisk)
    await db.delete(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  // ==========================================
  // BILDE-FUNKSJONER
  // ==========================================

  Future<int> insertEntry(String imagePath, String category, DateTime dateTaken) async {
    final db = await instance.database;
    final data = {
      'image_path': imagePath,
      'category': category,
      'date_taken': dateTaken.toIso8601String(),
    };
    return await db.insert('progress_images', data);
  }

  Future<List<Map<String, dynamic>>> getEntriesByCategory(String category) async {
    final db = await instance.database;
    return await db.query(
      'progress_images',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'date_taken DESC',
    );
  }

  Future<String?> getLatestGhostOverlay(String category) async {
    final db = await instance.database;
    final result = await db.query(
      'progress_images',
      columns: ['image_path'],
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'date_taken DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first['image_path'] as String;
    }
    return null;
  }

  Future<void> deleteProgressImage(int id, String imagePath) async {
    final db = await instance.database;
    await db.delete(
      'progress_images',
      where: 'id = ?',
      whereArgs: [id],
    );

    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}