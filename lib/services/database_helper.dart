import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cache.db');
    
    print('Initializing database at: $path');

    // Ensure directory exists
    try {
      await Directory(dirname(path)).create(recursive: true);
    } catch (e) {
      print('Error creating database directory: $e');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tracks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        artist TEXT,
        album TEXT,
        path TEXT UNIQUE,
        duration INTEGER,
        genre TEXT,
        track_number INTEGER,
        year INTEGER,
        date_added INTEGER,
        modified_time INTEGER,
        size INTEGER,
        rating INTEGER DEFAULT 0,
        play_count INTEGER DEFAULT 0
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getTracks() async {
    final db = await database;
    return await db.query('tracks', orderBy: 'artist, album, track_number');
  }

  Future<int> insertTrack(Map<String, dynamic> track) async {
    final db = await database;
    return await db.insert(
      'tracks',
      track,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTrack(Map<String, dynamic> track) async {
    final db = await database;
    return await db.update(
      'tracks',
      track,
      where: 'path = ?',
      whereArgs: [track['path']],
    );
  }

  Future<int> deleteTrack(String path) async {
    final db = await database;
    return await db.delete(
      'tracks',
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<Map<String, dynamic>?> getTrackByPath(String path) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tracks',
      where: 'path = ?',
      whereArgs: [path],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
  
  Future<void> clearLibrary() async {
    final db = await database;
    await db.delete('tracks');
  }
}
