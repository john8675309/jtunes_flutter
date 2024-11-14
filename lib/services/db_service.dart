import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbService {
  static Database? _database;

  static Future<void> initializeDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = join(
        Platform.environment['HOME'] ?? '', '.local/share/jtunes/cache.db');

    await Directory(dirname(dbPath)).create(recursive: true);

    _database = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDb,
        onUpgrade: _upgradeDb,
      ),
    );
  }

  static Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ipod_info (
        id TEXT PRIMARY KEY,
        db_version INTEGER,
        last_updated INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE tracks (
        id INTEGER PRIMARY KEY,
        ipod_id TEXT,
        title TEXT,
        artist TEXT,
        album TEXT,
        genre TEXT,
        duration INTEGER,
        track_number INTEGER,
        disc_number INTEGER,
        year INTEGER,
        rating INTEGER,
        play_count INTEGER,
        path TEXT,
        size INTEGER,
        bitrate INTEGER,
        FOREIGN KEY (ipod_id) REFERENCES ipod_info (id)
      )
    ''');

    // Add any indexes you need
    await db.execute('CREATE INDEX idx_ipod_id ON tracks(ipod_id)');
    await db.execute('CREATE INDEX idx_artist ON tracks(artist)');
    await db.execute('CREATE INDEX idx_album ON tracks(album)');
  }

  static Future<void> _upgradeDb(
      Database db, int oldVersion, int newVersion) async {
    // Handle future database upgrades here
  }

  static Future<bool> needsUpdate(String dbId, int version) async {
    final result = await _database?.query(
      'ipod_info',
      where: 'id = ? AND db_version = ?',
      whereArgs: [dbId, version],
    );

    return result == null || result.isEmpty;
  }

  static Future<List<Map<String, dynamic>>> getCachedTracks(String dbId) async {
    final result = await _database?.query(
      'tracks',
      where: 'ipod_id = ?',
      whereArgs: [dbId],
    );

    return result?.map((track) {
          return {
            'title': track['title'],
            'artist': track['artist'],
            'album': track['album'],
            'genre': track['genre'],
            'duration': track['duration'],
            'track_number': track['track_number'],
            'disc_number': track['disc_number'],
            'year': track['year'],
            'rating': track['rating'],
            'play_count': track['play_count'],
            'path': track['path'],
            'size': track['size'],
            'bitrate': track['bitrate'],
          };
        }).toList() ??
        [];
  }

  static Future<void> updateCache(
    String dbId,
    int version,
    List<Map<String, dynamic>> tracks,
  ) async {
    await _database?.transaction((txn) async {
      // Delete old data for this iPod
      await txn.delete(
        'tracks',
        where: 'ipod_id = ?',
        whereArgs: [dbId],
      );

      await txn.delete(
        'ipod_info',
        where: 'id = ?',
        whereArgs: [dbId],
      );

      // Insert new iPod info
      await txn.insert('ipod_info', {
        'id': dbId,
        'db_version': version,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });

      // Insert all tracks
      for (final track in tracks) {
        await txn.insert('tracks', {
          'ipod_id': dbId,
          'title': track['title'],
          'artist': track['artist'],
          'album': track['album'],
          'genre': track['genre'],
          'duration': track['duration'],
          'track_number': track['track_number'],
          'disc_number': track['disc_number'],
          'year': track['year'],
          'rating': track['rating'],
          'play_count': track['play_count'],
          'path': track['path'],
          'size': track['size'],
          'bitrate': track['bitrate'],
        });
      }
    });
  }

  // Helper methods for querying
  static Future<List<String>> getUniqueArtists(String dbId) async {
    final result = await _database?.rawQuery(
      'SELECT DISTINCT artist FROM tracks WHERE ipod_id = ? ORDER BY artist',
      [dbId],
    );
    return result?.map((r) => r['artist'] as String).toList() ?? [];
  }

  static Future<List<String>> getUniqueAlbums(String dbId) async {
    final result = await _database?.rawQuery(
      'SELECT DISTINCT album FROM tracks WHERE ipod_id = ? ORDER BY album',
      [dbId],
    );
    return result?.map((r) => r['album'] as String).toList() ?? [];
  }

  static Future<List<String>> getUniqueGenres(String dbId) async {
    final result = await _database?.rawQuery(
      'SELECT DISTINCT genre FROM tracks WHERE ipod_id = ? ORDER BY genre',
      [dbId],
    );
    return result?.map((r) => r['genre'] as String).toList() ?? [];
  }
}
