import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Load the shared library
final DynamicLibrary libgpod = Platform.isLinux
    ? DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libgpod.so')
    : throw UnsupportedError('This platform is not supported');

// Helper function to safely convert native string to Dart string
String safeString(Pointer<Utf8> ptr) {
  if (ptr.address == 0) return '';
  try {
    return ptr.toDartString();
  } catch (e) {
    print('Error converting string: $e');
    return '';
  }
}

// GList structure from glib
final class GList extends Struct {
  external Pointer<Void> data;
  external Pointer<GList> next;
  external Pointer<GList> prev;
}

// Native structs - following exact order from itdb.h
final class ItdbTrack extends Struct {
  external Pointer<ItdbITunesDB> itdb; // Pointer to parent database
  external Pointer<Utf8> title;
  external Pointer<Utf8> ipod_path;
  external Pointer<Utf8> album;
  external Pointer<Utf8> artist;
  external Pointer<Utf8> genre;
  external Pointer<Utf8> filetype;
  external Pointer<Utf8> comment;
  external Pointer<Utf8> category;
  external Pointer<Utf8> composer;
  external Pointer<Utf8> grouping;
  external Pointer<Utf8> description;
  external Pointer<Utf8> podcasturl;
  external Pointer<Utf8> podcastrss;
  external Pointer<Void> chapterdata; // We'll handle this separately if needed
  external Pointer<Utf8> subtitle;
  external Pointer<Utf8> tvshow;
  external Pointer<Utf8> tvepisode;
  external Pointer<Utf8> tvnetwork;
  external Pointer<Utf8> albumartist;
  external Pointer<Utf8> keywords;
  external Pointer<Utf8> sort_artist;
  external Pointer<Utf8> sort_title;
  external Pointer<Utf8> sort_album;
  external Pointer<Utf8> sort_albumartist;
  external Pointer<Utf8> sort_composer;
  external Pointer<Utf8> sort_tvshow;

  @Uint32()
  external int id;
  @Int32()
  external int size;
  @Int32()
  external int tracklen;
  @Int32()
  external int cd_nr;
  @Int32()
  external int cds;
  @Int32()
  external int track_nr;
  @Int32()
  external int tracks;
  @Int32()
  external int bitrate;
  @Uint16()
  external int samplerate;
  @Uint16()
  external int samplerate_low;
  @Int32()
  external int year;
  @Int32()
  external int volume;
  @Uint32()
  external int soundcheck;
  @Uint64()
  external int time_added;
  @Uint64()
  external int time_modified;
  @Uint64()
  external int time_played;
  @Uint32()
  external int bookmark_time;
  @Uint32()
  external int rating;
  @Uint32()
  external int playcount;
  @Uint32()
  external int playcount2;
  @Uint32()
  external int recent_playcount;
  @Uint8()
  external int transferred;
  @Int16()
  external int BPM;
  @Uint8()
  external int app_rating;
  @Uint8()
  external int type1;
  @Uint8()
  external int type2;
  @Uint8()
  external int compilation;
}

final class ItdbITunesDB extends Struct {
  external Pointer<GList> tracks;
  external Pointer<GList> playlists;
  external Pointer<Utf8> filename;
  external Pointer<Void> device;
  @Uint32()
  external int version;
  @Uint64()
  external int id;
  @Int32()
  external int tzoffset;
  @Int32()
  external int reserved_int2;
  external Pointer<Void> priv;
  external Pointer<Void> reserved2;
}

// Native function definitions
typedef ItdbNewNative = Pointer<ItdbITunesDB> Function();
typedef ItdbNew = Pointer<ItdbITunesDB> Function();

typedef ItdbParseNative = Pointer<ItdbITunesDB> Function(
    Pointer<Utf8> mountpoint, Pointer<Pointer<Void>> error);
typedef ItdbParse = Pointer<ItdbITunesDB> Function(
    Pointer<Utf8> mountpoint, Pointer<Pointer<Void>> error);

typedef ItdbFreeNative = Void Function(Pointer<ItdbITunesDB> db);
typedef ItdbFree = void Function(Pointer<ItdbITunesDB> db);

// Bind native functions
final ItdbNew itdbNew = libgpod
    .lookup<NativeFunction<ItdbNewNative>>('itdb_new')
    .asFunction<ItdbNew>();

final ItdbParse itdbParse = libgpod
    .lookup<NativeFunction<ItdbParseNative>>('itdb_parse')
    .asFunction<ItdbParse>();

final ItdbFree itdbFree = libgpod
    .lookup<NativeFunction<ItdbFreeNative>>('itdb_free')
    .asFunction<ItdbFree>();

// High-level wrapper class
class IpodDatabase {
  Pointer<ItdbITunesDB>? _db;
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  String getDatabaseId() {
    if (_db == null) return '';
    return _db!.ref.id.toString();
  }

  int getDatabaseVersion() {
    if (_db == null) return 0;
    return _db!.ref.version;
  }

  Future<bool> open(String mountPoint) async {
    if (_isOpen) return true;

    Pointer<Utf8>? mountPointPtr;
    Pointer<Pointer<Void>>? error;

    try {
      mountPointPtr = mountPoint.toNativeUtf8();
      error = calloc<Pointer<Void>>();

      _db = itdbParse(mountPointPtr, error);

      if (_db == null || error.value != nullptr) {
        print('Failed to parse iTunesDB');
        return false;
      }

      // Verify the database structure
      if (_db!.ref.tracks.address == 0) {
        print('No tracks list found in database');
        return false;
      }

      _isOpen = true;
      return true;
    } catch (e) {
      print('Error opening database: $e');
      return false;
    } finally {
      //mountPointPtr?.free();
      //error?.free();
    }
  }

  List<Map<String, dynamic>> getTracks() {
    if (!_isOpen || _db == null) {
      return [];
    }

    final tracks = <Map<String, dynamic>>[];
    try {
      var currentNode = _db!.ref.tracks;
      var count = 0;

      while (currentNode != nullptr && currentNode.address != 0) {
        try {
          final trackPtr = currentNode.ref.data.cast<ItdbTrack>();

          if (trackPtr.address != 0) {
            final track = trackPtr.ref;

            // Debug print
            print('Raw track data:');
            print('Title address: ${track.title.address}');
            print('Artist address: ${track.artist.address}');
            print('Album address: ${track.album.address}');

            tracks.add({
              'title': safeString(track.title),
              'artist': safeString(track.artist),
              'album': safeString(track.album),
              'genre': safeString(track.genre),
              'path': safeString(track.ipod_path),
              'duration': track.tracklen,
              'size': track.size,
              'bitrate': track.bitrate,
              'track_number': track.track_nr,
              'disc_number': track.cd_nr,
              'year': track.year,
              'rating': track.rating,
              'play_count': track.playcount,
              'compilation': track.compilation,
              'type': '${track.type1},${track.type2}',
            });
          }

          currentNode = currentNode.ref.next;
          count++;

          if (count > 100000) {
            print('Warning: Possible infinite loop detected');
            break;
          }
        } catch (e) {
          print('Error processing track: $e');
          currentNode = currentNode.ref.next;
        }
      }
    } catch (e) {
      print('Error getting tracks: $e');
    }

    return tracks;
  }

  void close() {
    if (_db != null) {
      try {
        itdbFree(_db!);
      } catch (e) {
        print('Error closing database: $e');
      }
      _db = null;
      _isOpen = false;
    }
  }
}
