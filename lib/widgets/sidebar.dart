import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../libgpod_bridge.dart';
import '../services/db_service.dart';
import '../services/database_helper.dart';

class Sidebar extends StatefulWidget {
  final void Function(
    String item, {
    List<Map<String, dynamic>>? tracks,
    String? dbId,
    int? version,
    String? deviceInfo,
  }) onItemSelected;

  const Sidebar({
    super.key,
    required this.onItemSelected,
  });

  @override
  _SidebarState createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  IpodDatabase? _ipodDb;
  bool _isIpodConnected = false;
  List<Map<String, dynamic>>? _ipodTracks;
  String? _ipodDbId;
  int? _dbVersion;
  String? _modelInfo;
  
  // Local Library State
  String? _libraryPath;
  List<Map<String, dynamic>> _localTracks = [];
  bool _isLoadingLibrary = false;

  @override
  void initState() {
    super.initState();
    _checkForIpod();
    _initLibrary();
  }

  Future<void> _initLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('library_path');

    if (savedPath != null) {
      setState(() {
        _libraryPath = savedPath;
      });
      // Load from DB first for speed
      _loadFromDatabase();
      // Then sync with file system
      _syncLibrary(savedPath);
    } else {
      // First run: prompt user to select library
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectLibraryPath();
      });
    }
  }

  Future<void> _selectLibraryPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('library_path', selectedDirectory);
      
      // Clear existing DB if library path changes (optional, but safer for now)
      await DatabaseHelper().clearLibrary();

      setState(() {
        _libraryPath = selectedDirectory;
        _localTracks = []; // Clear current view
      });
      _syncLibrary(selectedDirectory);
    }
  }

  Future<void> _checkForIpod() async {
    try {
      _ipodDb = IpodDatabase();
      bool connected = await _ipodDb!.open('/media/john/iPod');

      if (connected) {
        List<Map<String, dynamic>>? tracks;
        String? dbId;
        int? version;
        String? modelInfo;

        try {
          tracks = _ipodDb!.getTracks();
          print('Got ${tracks?.length ?? 0} tracks');
        } catch (e) {
          print('Error getting tracks: $e');
          tracks = [];
        }

        try {
          dbId = _ipodDb!.getDatabaseId();
          print('Got database ID: $dbId');
        } catch (e) {
          print('Error getting database ID: $e');
        }

        try {
          version = _ipodDb!.getDatabaseVersion();
          print('Got database version: $version');
        } catch (e) {
          print('Error getting database version: $e');
        }

        try {
          modelInfo = _ipodDb!.getModelInfo();
          print('Got model info: $modelInfo');
        } catch (e) {
          print('Error getting model info: $e');
          modelInfo = 'Error getting device info';
        }

        setState(() {
          _isIpodConnected = true;
          _ipodTracks = tracks;
          _ipodDbId = dbId;
          _dbVersion = version;
          _modelInfo = modelInfo;
        });
      } else {
        print('Failed to connect to iPod');
      }
    } catch (e) {
      print('Error in _checkForIpod: $e');
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      final tracks = await DatabaseHelper().getTracks();
      if (tracks.isNotEmpty) {
        setState(() {
          _localTracks = tracks;
        });
        widget.onItemSelected('Recently Added', tracks: _localTracks);
      }
    } catch (e) {
      print('Error loading from database: $e');
    }
  }

  Future<void> _syncLibrary(String directoryPath) async {
    setState(() {
      _isLoadingLibrary = true;
    });

    try {
      final dir = Directory(directoryPath);
      List<FileSystemEntity> files =
          dir.listSync(recursive: true, followLinks: false);
      
      final dbHelper = DatabaseHelper();
      bool dbUpdated = false;

      // Get all existing paths from DB to check for deletions
      final existingTracks = await dbHelper.getTracks();
      final existingPaths = existingTracks.map((t) => t['path'] as String).toSet();
      final currentPaths = <String>{};

      for (var file in files) {
        if (file is File) {
          String path = file.path;
          String ext = path.split('.').last.toLowerCase();
          if (['mp3', 'm4a', 'wav', 'flac', 'ogg', 'm4v', 'mov', 'mp4'].contains(ext)) {
            currentPaths.add(path);
            
            // Check if track exists in DB
            final existingTrack = await dbHelper.getTrackByPath(path);
            
            // For now, we only insert if not exists. 
            // TODO: Check modified time to update existing tracks
            if (existingTrack == null) {
              String filename = path.split('/').last;
              String title = filename.substring(0, filename.lastIndexOf('.'));
              String artist = 'Unknown';
              String album = 'Local File';
              String genre = 'Unknown';
              int duration = 0;
              int trackNumber = 0;
              int year = 0;

              try {
                Tag? tag = await AudioTags.read(path);
                if (tag != null) {
                  title = tag.title ?? title;
                  artist = tag.trackArtist ?? 'Unknown';
                  album = tag.album ?? 'Local File';
                  genre = tag.genre?.split(';').first.trim() ?? 'Unknown';
                  duration = (tag.duration ?? 0) * 1000; // Convert to ms
                  trackNumber = tag.trackNumber ?? 0;
                  year = tag.year ?? 0;
                }
              } catch (e) {
                print('Error reading tags for $path: $e');
              }

              final stat = await file.stat();
              await dbHelper.insertTrack({
                'title': title,
                'artist': artist,
                'album': album,
                'path': path,
                'size': await file.length(),
                'duration': duration,
                'genre': genre,
                'track_number': trackNumber,
                'year': year,
                'date_added': stat.modified.millisecondsSinceEpoch,
                'modified_time': stat.modified.millisecondsSinceEpoch,
              });
              dbUpdated = true;
            }
          }
        }
      }

      // Check for deletions
      for (final path in existingPaths) {
        if (!currentPaths.contains(path)) {
          await dbHelper.deleteTrack(path);
          dbUpdated = true;
        }
      }

      if (dbUpdated || _localTracks.isEmpty) {
        _loadFromDatabase();
      }

      setState(() {
        _isLoadingLibrary = false;
      });

    } catch (e) {
      print('Error syncing library: $e');
      setState(() {
        _isLoadingLibrary = false;
      });
    }
  }

  @override
  void dispose() {
    _ipodDb?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200.0,
      color: Colors.grey[850],
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SidebarSection(
                  title: 'Library',
                  items: [
                    SidebarItem(label: 'Recently Added', icon: Icons.access_time),
                    SidebarItem(label: 'Music', icon: Icons.music_note),
                    SidebarItem(label: 'Videos', icon: Icons.video_library),
                    SidebarItem(label: 'Podcasts', icon: Icons.podcasts),
                    SidebarItem(label: 'Genres', icon: Icons.category),
                    SidebarItem(label: 'Radio', icon: Icons.radio),
                  ],
                  initiallyExpanded: true,
                  onItemSelected: (item) {
                     widget.onItemSelected(item, tracks: _localTracks);
                  },
                ),
                if (_isIpodConnected) ...[
                  DragTarget<List<Map<String, dynamic>>>(
                    onWillAccept: (data) => data != null && data.isNotEmpty,
                    onAccept: (data) async {
                      if (_ipodDb != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copying ${data.length} tracks to iPod...')),
                        );
                        
                        int successCount = 0;
                        for (final track in data) {
                          final success = await _ipodDb!.addTrack(track);
                          if (success) successCount++;
                        }

                        if (successCount > 0) {
                          await _ipodDb!.save();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$successCount tracks copied to iPod!')),
                          );
                          // Refresh iPod tracks
                          _checkForIpod();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to copy tracks.')),
                          );
                        }
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        color: candidateData.isNotEmpty
                            ? Colors.blue.withOpacity(0.5)
                            : null,
                        child: ListTile(
                          leading: const Icon(Icons.devices, color: Colors.white),
                          title: const Text(
                            'iPod',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            widget.onItemSelected(
                              'iPod',
                              tracks: _ipodTracks,
                              dbId: _ipodDbId,
                              version: _dbVersion,
                              deviceInfo: _modelInfo,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Text(
                      '${_ipodTracks?.length ?? 0} songs',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isLoadingLibrary)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white),
            title: const Text('Settings', style: TextStyle(color: Colors.white)),
            onTap: _selectLibraryPath, // Allow changing library
          ),
        ],
      ),
    );
  }
}

class SidebarSection extends StatelessWidget {
  final String title;
  final List<SidebarItem> items;
  final void Function(String) onItemSelected;
  final bool initiallyExpanded;
  final List<Widget>? extraItems;

  const SidebarSection({
    super.key,
    required this.title,
    required this.items,
    required this.onItemSelected,
    this.initiallyExpanded = false,
    this.extraItems,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        title,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      initiallyExpanded: initiallyExpanded,
      iconColor: Colors.white,
      collapsedIconColor: Colors.white,
      children: [
        ...items.map((item) => ListTile(
              leading: Icon(item.icon, color: Colors.white),
              title: Text(
                item.label,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                onItemSelected(item.label);
              },
            )),
        if (extraItems != null) ...extraItems!,
      ],
    );
  }
}

class SidebarItem {
  final String label;
  final IconData icon;

  SidebarItem({required this.label, required this.icon});
}
