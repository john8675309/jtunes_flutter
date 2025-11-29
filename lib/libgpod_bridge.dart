import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Load the shared library
final DynamicLibrary libgpod = Platform.isLinux
    ? DynamicLibrary.open('/home/john/Downloads/libgpod-dev/libgpod-0.8.3/src/.libs/libgpod.so')
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

final class Statvfs extends Struct {
  @Uint64()
  external int f_bsize; // File system block size
  @Uint64()
  external int f_frsize; // Fragment size
  @Uint64()
  external int f_blocks; // Size of fs in f_frsize units
  @Uint64()
  external int f_bfree; // Number of free blocks
  @Uint64()
  external int f_bavail; // Number of free blocks for unprivileged users
  @Uint64()
  external int f_files; // Number of inodes
  @Uint64()
  external int f_ffree; // Number of free inodes
  @Uint64()
  external int f_favail; // Number of free inodes for unprivileged users
  @Uint64()
  external int f_fsid; // File system ID
  @Uint64()
  external int f_flag; // Mount flags
  @Uint64()
  external int f_namemax; // Maximum filename length
  @Array(6)
  external Array<Uint64> f_spare; // Spare bytes
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

final class ItdbIpodInfo extends Struct {
  @Uint64() // Use 64-bit alignment
  external int _padding1; // Add padding to match C struct alignment

  external Pointer<Utf8> modelNumber;
  external Pointer<Utf8> capacity;
  external Pointer<Utf8> ipodModel;

  @Int32()
  external int generation;

  @Int32()
  external int _padding2; // Add 32-bit padding

  external Pointer<Utf8> serialNumber;
}

final class ItdbDevice extends Struct {
  external Pointer<Utf8> mountpoint;

  @Int32()
  external int byteOrder;

  @Int32()
  external int _padding; // Add padding for alignment

  external Pointer<ItdbIpodInfo> info;
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

typedef ItdbDeviceGetIpodInfoNative = Pointer<ItdbIpodInfo> Function(
    Pointer<ItdbDevice> device);
typedef ItdbDeviceGetIpodInfo = Pointer<ItdbIpodInfo> Function(
    Pointer<ItdbDevice> device);

typedef GTypeInitNative = Void Function();
typedef GTypeInit = void Function();

typedef ItdbInfoGetIpodInfoNative = Pointer<ItdbIpodInfo> Function(
    Pointer<Utf8> mountpoint);
typedef ItdbInfoGetIpodInfo = Pointer<ItdbIpodInfo> Function(
    Pointer<Utf8> mountpoint);

typedef ItdbDeviceGetSysInfoNative = Pointer<Utf8> Function(
    Pointer<ItdbDevice> device, Pointer<Utf8> field);
typedef ItdbDeviceGetSysInfo = Pointer<Utf8> Function(
    Pointer<ItdbDevice> device, Pointer<Utf8> field);

// ... existing typedefs ...

typedef ItdbTrackNewNative = Pointer<ItdbTrack> Function();
typedef ItdbTrackNew = Pointer<ItdbTrack> Function();

typedef ItdbTrackAddNative = Void Function(
    Pointer<ItdbITunesDB> itdb, Pointer<ItdbTrack> track, Int32 pos);
typedef ItdbTrackAdd = void Function(
    Pointer<ItdbITunesDB> itdb, Pointer<ItdbTrack> track, int pos);

typedef ItdbWriteNative = Int32 Function(
    Pointer<ItdbITunesDB> itdb, Pointer<Pointer<Void>> error);
typedef ItdbWrite = int Function(
    Pointer<ItdbITunesDB> itdb, Pointer<Pointer<Void>> error);

typedef ItdbCpTrackToIpodNative = Int32 Function(
    Pointer<ItdbTrack> track, Pointer<Utf8> filename, Pointer<Pointer<Void>> error);
typedef ItdbCpTrackToIpod = int Function(
    Pointer<ItdbTrack> track, Pointer<Utf8> filename, Pointer<Pointer<Void>> error);

// ... bindings ...

final ItdbTrackNew itdbTrackNew = libgpod
    .lookup<NativeFunction<ItdbTrackNewNative>>('itdb_track_new')
    .asFunction<ItdbTrackNew>();

final ItdbTrackAdd itdbTrackAdd = libgpod
    .lookup<NativeFunction<ItdbTrackAddNative>>('itdb_track_add')
    .asFunction<ItdbTrackAdd>();

final ItdbWrite itdbWrite = libgpod
    .lookup<NativeFunction<ItdbWriteNative>>('itdb_write')
    .asFunction<ItdbWrite>();

final ItdbCpTrackToIpod itdbCpTrackToIpod = libgpod
    .lookup<NativeFunction<ItdbCpTrackToIpodNative>>('itdb_cp_track_to_ipod')
    .asFunction<ItdbCpTrackToIpod>();

// ... bindings ...

typedef GStrDupNative = Pointer<Utf8> Function(Pointer<Utf8> str);
typedef GStrDup = Pointer<Utf8> Function(Pointer<Utf8> str);

final GStrDup gStrDup = libgpod
    .lookup<NativeFunction<GStrDupNative>>('g_strdup')
    .asFunction<GStrDup>();

// ... IpodDatabase class ...





final ItdbNew itdbNew = libgpod
    .lookup<NativeFunction<ItdbNewNative>>('itdb_new')
    .asFunction<ItdbNew>();

final ItdbParse itdbParse = libgpod
    .lookup<NativeFunction<ItdbParseNative>>('itdb_parse')
    .asFunction<ItdbParse>();

final ItdbFree itdbFree = libgpod
    .lookup<NativeFunction<ItdbFreeNative>>('itdb_free')
    .asFunction<ItdbFree>();
typedef StatvfsNative = Int32 Function(
    Pointer<Utf8> path, Pointer<Statvfs> buf);
typedef Statvfs_t = int Function(Pointer<Utf8> path, Pointer<Statvfs> buf);

// High-level wrapper class
class IpodDatabase {
  Pointer<ItdbITunesDB>? _db;
  bool _isOpen = false;
  static bool _glibInitialized = false;
  late final ItdbDeviceGetSysInfo getDeviceSysInfo;

  bool get isOpen => _isOpen;

  static const Map<String, String> modelNumberToName = {
    'xA101': 'iPod Classic 1st Generation',
    'xA102': 'iPod Classic 2nd Generation',
    'xA103': 'iPod Classic 3rd Generation',
    'xA104': 'iPod Classic 4th Generation',
    'xA105': 'iPod Classic 5th Generation',
    'xB150': 'iPod Classic 6th Generation (160GB)',
    'xB120': 'iPod Classic 6th Generation (120GB)',
    'xB147': 'iPod Classic 7th Generation',
    'xA130': 'iPod Mini 1st Generation',
    'xA131': 'iPod Mini 2nd Generation',
    'xA204': 'iPod Nano 1st Generation',
    'xA205': 'iPod Nano 2nd Generation',
    'xA206': 'iPod Nano 3rd Generation',
    'xA211': 'iPod Nano 4th Generation',
    'xA212': 'iPod Nano 5th Generation',
    'xA213': 'iPod Nano 6th Generation',
    'xA214': 'iPod Nano 7th Generation',
  };

  void _initGLib() {
    if (!_glibInitialized) {
      try {
        final gTypeInit = libgpod
            .lookup<NativeFunction<GTypeInitNative>>('g_type_init')
            .asFunction<GTypeInit>();
        gTypeInit();
        _glibInitialized = true;
        print('GLib initialized successfully');
      } catch (e) {
        print('Error initializing GLib: $e');
      }
    }
  }

  String _formatSize(double sizeInBytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = sizeInBytes;
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }

  Map<String, String> getDiskInfo(String mountPoint) {
    final path = mountPoint.toNativeUtf8();
    final stat = calloc<Statvfs>();

    try {
      // Load libc
      final libc = DynamicLibrary.open('libc.so.6');
      final statvfs = libc
          .lookup<NativeFunction<StatvfsNative>>('statvfs')
          .asFunction<Statvfs_t>();

      if (statvfs(path, stat) == 0) {
        final blockSize = stat.ref.f_bsize;
        final totalBlocks = stat.ref.f_blocks;
        final freeBlocks = stat.ref.f_bfree;
        final availableBlocks = stat.ref.f_bavail;

        final totalSize = blockSize * totalBlocks;
        final freeSize = blockSize * freeBlocks;
        final usedSize = totalSize - freeSize;
        final availableSize = blockSize * availableBlocks;

        return {
          'total': _formatSize(totalSize.toDouble()),
          'used': _formatSize(usedSize.toDouble()),
          'free': _formatSize(freeSize.toDouble()),
          'available': _formatSize(availableSize.toDouble()),
          'usage_percent': ((usedSize / totalSize) * 100).toStringAsFixed(1),
        };
      }
    } catch (e) {
      print('Error getting disk info: $e');
    } finally {
      calloc.free(path);
      calloc.free(stat);
    }

    return {};
  }

  IpodDatabase() {
    try {
      getDeviceSysInfo = libgpod
          .lookup<NativeFunction<ItdbDeviceGetSysInfoNative>>(
              'itdb_device_get_sysinfo')
          .asFunction<ItdbDeviceGetSysInfo>();
    } catch (e) {
      print('Error looking up sysinfo function: $e');
    }
  }
  String? _getSysInfo(Pointer<ItdbDevice> device, String field) {
    try {
      final fieldPtr = field.toNativeUtf8();
      try {
        final resultPtr = getDeviceSysInfo(device, fieldPtr);
        if (resultPtr != nullptr) {
          return safeString(resultPtr);
        }
      } finally {
        calloc.free(fieldPtr);
      }
    } catch (e) {
      print('Error getting sysinfo for $field: $e');
    }
    return null;
  }

  int correctEndianness(int value, bool isBigEndian) {
    if (!isBigEndian) return value;

    // Swap bytes for 32-bit integer
    return ((value & 0xFF) << 24) |
        ((value & 0xFF00) << 8) |
        ((value & 0xFF0000) >> 8) |
        ((value & 0xFF000000) >> 24);
  }

  String getDatabaseId() {
    if (_db == null) return '';
    try {
      return _db!.ref.id.toString();
    } catch (e) {
      print('Error getting database ID: $e');
      return '';
    }
  }

  String getModelInfo() {
    print('Starting getModelInfo()...');
    if (_db == null) {
      print('Database is null');
      return 'Database not initialized';
    }

    _initGLib();

    String basicInfo;
    try {
      basicInfo = '''
Database Version: ${_db!.ref.version}
Database ID: ${_db!.ref.id}'''
          .trim();
      print('Got basic info: $basicInfo');
    } catch (e) {
      print('Error getting basic info: $e');
      return 'Error getting basic database info';
    }

    try {
      if (_db!.ref.device == nullptr) {
        print('Device pointer is null');
        return basicInfo;
      }

      final devicePtr = _db!.ref.device.cast<ItdbDevice>();
      print('Device struct size: ${sizeOf<ItdbDevice>()}');

      // Add mountpoint info
      if (devicePtr.ref.mountpoint != nullptr) {
        final mountpoint = safeString(devicePtr.ref.mountpoint);
        basicInfo += '\nMount Point: $mountpoint';
      }

      // Try to get sysinfo fields
      final fields = [
        'ModelNumStr',
        'ModelStr',
        'GenerationStr',
        'FirewireGuid',
        'DeviceVersion',
        'FamilyId',
        'SerialNumber',
        'ProductType',
        'BoardHwRev',
        'BoardRevision',
        'HardwarePlatform',
        'RegionInfo',
        'PolicyFlags'
      ];

      print('Attempting to read device system info...');
      String? modelNumber;

      for (final field in fields) {
        final value = _getSysInfo(devicePtr, field);
        if (value != null && value.isNotEmpty) {
          print('Got $field: $value');

          // Store model number for later use
          if (field == 'ModelNumStr') {
            modelNumber = value;
          }

          basicInfo += '\n$field: $value';
        }
      }

      // Add human-readable model name if available
      if (modelNumber != null) {
        final modelName = modelNumberToName[modelNumber];
        if (modelName != null) {
          basicInfo += '\nModel Name: $modelName';
        }
      }

      try {
        // Try to get byte order
        final byteOrder = devicePtr.ref.byteOrder;
        print('Byte order: $byteOrder');
        basicInfo +=
            '\nByte Order: ${byteOrder == 0 ? "Big Endian" : "Little Endian"}';
      } catch (e) {
        print('Error getting byte order: $e');
      }

      // Add disk space information
      try {
        final diskInfo = getDiskInfo('/media/john/iPod');
        if (diskInfo.isNotEmpty) {
          basicInfo += '\n\nDisk Information:';
          basicInfo += '\nTotal Size: ${diskInfo['total']}';
          basicInfo +=
              '\nUsed Space: ${diskInfo['used']} (${diskInfo['usage_percent']}%)';
          basicInfo += '\nFree Space: ${diskInfo['free']}';
          basicInfo += '\nAvailable Space: ${diskInfo['available']}';
        }

        // Add media statistics
        final tracks = getTracks();
        final totalMediaSize = tracks.fold<double>(
            0, (sum, item) => sum + ((item['size'] ?? 0) / (1024 * 1024)));
        final totalTracks = tracks.length;

        basicInfo += '\n\nMedia Statistics:';
        basicInfo += '\nTotal Tracks: $totalTracks';
        basicInfo +=
            '\nTotal Media Size: ${_formatSize(totalMediaSize * 1024 * 1024)}';

        // Calculate average track size
        if (totalTracks > 0) {
          final averageTrackSize = totalMediaSize / totalTracks;
          basicInfo +=
              '\nAverage Track Size: ${_formatSize(averageTrackSize * 1024 * 1024)}';
        }

        // Add audio format statistics
        final formatStats = <String, int>{};
        int totalBitrate = 0;
        int bitrateCount = 0;

        for (final track in tracks) {
          final String type = (track['type'] ?? '').toString();
          formatStats[type] = (formatStats[type] ?? 0) + 1;

          final int? bitrate = track['bitrate'] as int?;
          if (bitrate != null && bitrate > 0) {
            totalBitrate += bitrate;
            bitrateCount++;
          }
        }

        if (formatStats.isNotEmpty) {
          basicInfo += '\n\nAudio Format Statistics:';
          formatStats.forEach((format, count) {
            final percentage = (count / totalTracks * 100).toStringAsFixed(1);
            basicInfo += '\n$format: $count tracks ($percentage%)';
          });
        }

        if (bitrateCount > 0) {
          final averageBitrate = totalBitrate / bitrateCount;
          basicInfo +=
              '\nAverage Bitrate: ${averageBitrate.toStringAsFixed(0)} kbps';
        }
      } catch (e) {
        print('Error calculating additional info: $e');
      }

      return basicInfo;
    } catch (e) {
      print('Error in getModelInfo: $e');
      return basicInfo;
    }
  }

  int getDatabaseVersion() {
    if (_db == null) return 0;
    try {
      return _db!.ref.version;
    } catch (e) {
      print('Error getting database version: $e');
      return 0;
    }
  }

  Future<bool> open(String mountPoint) async {
    if (_isOpen) return true;

    _initGLib();

    late final Pointer<Utf8> mountPointPtr;
    late final Pointer<Pointer<Void>> error;

    try {
      mountPointPtr = mountPoint.toNativeUtf8();
      error = calloc<Pointer<Void>>();
      error.value = nullptr;

      _db = itdbParse(mountPointPtr, error);

      if (_db == null || error.value != nullptr) {
        print('Failed to parse iTunesDB');
        return false;
      }

      if (_db!.ref.tracks == nullptr || _db!.ref.tracks.address == 0) {
        print('No tracks list found in database');
        return false;
      }

      _isOpen = true;
      return true;
    } catch (e) {
      print('Error opening database: $e');
      return false;
    } finally {
      try {
        calloc.free(mountPointPtr);
        calloc.free(error);
      } catch (e) {
        print('Error freeing memory: $e');
      }
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
            /*
            print('Raw track data:');
            print('Title address: ${track.title.address}');
            print('Artist address: ${track.artist.address}');
            print('Album address: ${track.album.address}');
            */
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
              'podcast_url': safeString(track.podcasturl),
              'tv_show': safeString(track.tvshow),
              'file_type': safeString(track.filetype),
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

  Future<bool> addTrack(Map<String, dynamic> trackData) async {
    if (!_isOpen || _db == null) return false;

    Pointer<Utf8>? filenamePtr;
    Pointer<Pointer<Void>>? error;

    try {
      final trackPtr = itdbTrackNew();
      final track = trackPtr.ref;

      // Add to database first to set track->itdb
      // -1 adds to the end of the master playlist (and main library)
      itdbTrackAdd(_db!, trackPtr, -1);

      // Copy file to iPod
      final path = trackData['path'] as String;
      filenamePtr = path.toNativeUtf8();
      error = calloc<Pointer<Void>>();
      error.value = nullptr;

      final success = itdbCpTrackToIpod(trackPtr, filenamePtr, error);
      if (success != 1) {
        print('Error copying track to iPod');
        // If copy fails, we should probably remove the track?
        // But for now let's just return false.
        return false;
      }

      // Helper to set string fields using g_strdup
      void setField(String? value, void Function(Pointer<Utf8>) setter) {
        if (value != null) {
          final tempPtr = value.toNativeUtf8();
          final dupPtr = gStrDup(tempPtr);
          setter(dupPtr);
          calloc.free(tempPtr);
        }
      }

      // Set metadata
      // We have to manually set the pointer fields on the struct
      // Since we can't pass a setter for a field, we do it directly
      
      if (trackData['title'] != null) {
        final tempPtr = (trackData['title'] as String).toNativeUtf8();
        track.title = gStrDup(tempPtr);
        calloc.free(tempPtr);
      }
      
      if (trackData['artist'] != null) {
        final tempPtr = (trackData['artist'] as String).toNativeUtf8();
        track.artist = gStrDup(tempPtr);
        calloc.free(tempPtr);
      }

      if (trackData['album'] != null) {
        final tempPtr = (trackData['album'] as String).toNativeUtf8();
        track.album = gStrDup(tempPtr);
        calloc.free(tempPtr);
      }
      
      if (trackData['genre'] != null) {
        final tempPtr = (trackData['genre'] as String).toNativeUtf8();
        track.genre = gStrDup(tempPtr);
        calloc.free(tempPtr);
      }
      
      if (trackData['file_type'] != null) {
        final tempPtr = (trackData['file_type'] as String).toNativeUtf8();
        track.filetype = gStrDup(tempPtr);
        calloc.free(tempPtr);
      }

      // Set numeric fields
      track.tracklen = trackData['duration'] ?? 0;
      track.size = trackData['size'] ?? 0;
      track.track_nr = trackData['track_number'] ?? 0;
      track.year = trackData['year'] ?? 0;
      track.time_added = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      track.time_modified = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      return true;
    } catch (e) {
      print('Error adding track: $e');
      return false;
    } finally {
      if (filenamePtr != null) calloc.free(filenamePtr);
      if (error != null) calloc.free(error);
    }
  }

  Future<bool> save() async {
    if (!_isOpen || _db == null) return false;
    
    final error = calloc<Pointer<Void>>();
    error.value = nullptr;
    
    try {
      final success = itdbWrite(_db!, error);
      if (success != 1) {
        print('Error saving database');
        return false;
      }
      return true;
    } catch (e) {
      print('Error saving database: $e');
      return false;
    } finally {
      calloc.free(error);
    }
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
