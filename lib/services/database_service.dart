import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:progress/models/category.dart';
import 'package:progress/models/progress_entry.dart';
import 'dart:io';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('progress_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1, 
      onConfigure: _onConfigure, // Necessary for "Foreign keys"
      onCreate: _createDB,
    );
  }

  // Turn on foreign key support for SQLite
  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // 1. Categories table (Must be created first since images depend on it)
    await db.execute('''
      CREATE TABLE categories (
        name TEXT PRIMARY KEY,
        reminder_type TEXT NOT NULL,
        reminder_day INTEGER NOT NULL,
        reminder_hour INTEGER NOT NULL,
        reminder_minute INTEGER NOT NULL
      )
    ''');

    // 2. Images table (Uses your preferred name)
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

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close(); // Ask the database to finish any pending operations and release the file
      _database = null; // Set the database instance to null to allow for re-initialization
    }
  }

  // ==========================================
  // CATEGORY-FUNCTIONS
  // ==========================================

  Future<List<ProgressCategory>> getCategories() async {
    final db = await instance.database;
    final maps = await db.query('categories');
    
    // Fetch all Maps from the database and convert them to ProgressCategory objects
    return maps.map((map) => ProgressCategory.fromMap(map)).toList();
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

  // Deletes a category and all associated images from the database and the device storage
  Future<void> deleteCategory(String name) async {
    final db = await instance.database;

    // 1. Gets all images associated with the category and deletes them from storage
    final images = await getEntriesByCategory(name);
    for (var image in images) {
      final file = File(image.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // 2. Delete the category from the database
    await db.delete(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  // ==========================================
  // IMAGE-FUNCTIONS
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

  Future<String> _getFullImagePath(String dbPath) async {
    final directory = await getApplicationDocumentsDirectory();
    
    // 1. If the path is relative, we assume it's stored in the app's documents directory
    if (!isAbsolute(dbPath)) {
      return join(directory.path, dbPath);
    }
    
    // 2. If the path is absolute AND the file actually exists there (same phone)
    if (await File(dbPath).exists()) {
      return dbPath;
    }
    
    // If the path is absolute, but the file does not exist (new phone / different file structure).
    // In this case, we simply extract the filename (e.g., "image1.jpg") and append it to the current directory!
    return join(directory.path, basename(dbPath));
  }

  Future<List<ProgressEntry>> getEntriesByCategory(String category) async {
    final db = await instance.database;
    final maps = await db.query(
      'progress_images',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'date_taken DESC',
    );

    // Resolves the image paths to full paths AND converts them to objects
    List<ProgressEntry> resolvedEntries = [];
    for (var map in maps) {
      final mutableMap = Map<String, dynamic>.from(map);
      mutableMap['image_path'] = await _getFullImagePath(map['image_path'] as String);
      resolvedEntries.add(ProgressEntry.fromMap(mutableMap));
    }
    return resolvedEntries;
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
      // Returns the full path of the latest image for the given category
      return await _getFullImagePath(result.first['image_path'] as String);
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