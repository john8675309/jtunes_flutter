import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import '../services/db_service.dart';

class LoadingProgress {
  final List<Map<String, dynamic>> tracks;
  final int totalTracks;
  final int processedTracks;

  LoadingProgress(this.tracks, this.totalTracks, this.processedTracks);
}

class MediaList extends StatefulWidget {
  final String selectedItem;
  final List<Map<String, dynamic>>? tracks;
  final String? ipodDbId; // Changed from dbId to ipodDbId for clarity
  final int? dbVersion; // Changed from version to dbVersion for clarity

  const MediaList({
    super.key,
    required this.selectedItem,
    this.tracks,
    this.ipodDbId, // Add this property
    this.dbVersion, // Add this property
  });

  @override
  _MediaListState createState() => _MediaListState();
}

class _MediaListState extends State<MediaList> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  Process? _playerProcess;
  int? _playingIndex;
  Timer? _checkProcessTimer;
  List<Map<String, dynamic>> _processedTracks = [];
  bool _isLoading = false;
  int _processedCount = 0;
  int _totalTracks = 0;
  bool _loadingFromCache = false;
  Isolate? _isolate;
  ReceivePort? _receivePort;

  @override
  void initState() {
    super.initState();
    _loadTracksInBackground();
  }

  @override
  void didUpdateWidget(MediaList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tracks != oldWidget.tracks) {
      _isolate?.kill();
      _receivePort?.close();
      _loadTracksInBackground();
    }
  }

  Future<void> _loadTracksWithCache() async {
    if (widget.ipodDbId == null || widget.dbVersion == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingFromCache = true;
    });

    try {
      if (await DbService.needsUpdate(widget.ipodDbId!, widget.dbVersion!)) {
        _loadingFromCache = false;
        if (widget.tracks != null) {
          await _loadTracksInBackground();
        }
      } else {
        final cachedTracks = await DbService.getCachedTracks(widget.ipodDbId!);
        setState(() {
          _processedTracks = cachedTracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error accessing cache: $e');
      if (widget.tracks != null) {
        _loadingFromCache = false;
        await _loadTracksInBackground();
      }
    }
  }

  Future<void> _loadTracksInBackground() async {
    if (widget.tracks == null || widget.tracks!.isEmpty) {
      setState(() {
        _processedTracks = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _processedTracks = [];
    });

    final receivePort = ReceivePort();

    await Isolate.spawn(
      _processTracks,
      {
        'sendPort': receivePort.sendPort,
        'tracks': widget.tracks,
        'batchSize': 50, // Now we're passing the batch size
      },
    );

    await for (final message in receivePort) {
      if (message is LoadingProgress) {
        if (mounted) {
          setState(() {
            _processedTracks = message.tracks;
            _processedCount = message.processedTracks;
            if (message.processedTracks >= message.totalTracks) {
              _isLoading = false;
            }
          });
        }
      }
    }
  }

  static void _processTracks(Map<String, dynamic> message) {
    final SendPort sendPort = message['sendPort'];
    final List<Map<String, dynamic>> tracks = message['tracks'];
    final int batchSize =
        message['batchSize'] as int; // Cast to ensure type safety
    final processedTracks = <Map<String, dynamic>>[];

    for (var i = 0; i < tracks.length; i += batchSize) {
      final endIndex =
          (i + batchSize < tracks.length) ? i + batchSize : tracks.length;
      final batch = tracks.sublist(i, endIndex);

      // Process batch
      for (var track in batch) {
        processedTracks.add({
          ...track,
          'processed': true,
        });
      }

      // Send progress update
      sendPort.send(LoadingProgress(
        List.from(processedTracks),
        tracks.length,
        processedTracks.length,
      ));
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _stopPlayback();
    _checkProcessTimer?.cancel();
    super.dispose();
  }

  String formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _stopPlayback() async {
    _checkProcessTimer?.cancel();
    if (_playerProcess != null) {
      _playerProcess!.kill();
      _playerProcess = null;
      setState(() {
        _playingIndex = null;
      });
    }
  }

  Future<void> playTrack(Map<String, dynamic> track, int index) async {
    try {
      // Stop current playback if any
      await _stopPlayback();

      // Get the file path from the track data
      final path = track['path'] as String;
      if (path.isEmpty) return;

      // Convert iPod path to actual file system path
      final fullPath = path.replaceAll(':', '/');
      final mountPoint = '/media/john/IPOD'; // Adjust this to your mount point
      final filePath = '$mountPoint/$fullPath';

      // Check if file exists
      if (!await File(filePath).exists()) {
        print('File not found: $filePath');
        return;
      }

      // Start playback using mpv
      _playerProcess = await Process.start('mpv', [
        '--no-video',
        '--no-terminal',
        '--no-config',
        filePath,
      ]);

      setState(() {
        _playingIndex = index;
      });

      // Start checking if process is still running
      _checkProcessTimer?.cancel();
      _checkProcessTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (_playerProcess == null) {
          timer.cancel();
          setState(() {
            _playingIndex = null;
          });
        }
      });

      // Handle process exit
      _playerProcess!.exitCode.then((_) {
        if (mounted) {
          setState(() {
            _playingIndex = null;
            _playerProcess = null;
          });
        }
      });
    } catch (e) {
      print('Error playing track: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing track: ${e.toString()}')),
      );
    }
  }

  Future<void> togglePlayPause(Map<String, dynamic> track, int index) async {
    if (_playingIndex == index) {
      await _stopPlayback();
    } else {
      await playTrack(track, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scrollbar(
          controller: _verticalController,
          thumbVisibility: true,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            notificationPredicate: (notification) => notification.depth == 1,
            child: SingleChildScrollView(
              controller: _verticalController,
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dataTableTheme: DataTableThemeData(
                      headingTextStyle: _headerStyle(),
                      dataTextStyle: _cellStyle(),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width,
                    ),
                    child: _isLoading
                        ? _buildLoadingIndicator()
                        : _buildDataTable(),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: Center(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading tracks...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      height: 300,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildDataTable() {
    return DataTable(
      headingRowColor: MaterialStateProperty.all(Colors.grey[850]),
      dataRowColor: MaterialStateProperty.resolveWith<Color>((states) {
        return Colors.grey[800]!;
      }),
      columns: [
        DataColumn(label: SizedBox.shrink()),
        DataColumn(label: Text('Song')),
        DataColumn(label: Text('Time')),
        DataColumn(label: Text('Artist')),
        DataColumn(label: Text('Album')),
        DataColumn(label: Text('Genre')),
        DataColumn(label: Text('Rating')),
        DataColumn(label: Text('Play Count')),
        DataColumn(label: Text('Track #')),
        DataColumn(label: Text('Year')),
      ],
      rows: List.generate(_processedTracks.length, (index) {
        final track = _processedTracks[index];
        final isPlaying = _playingIndex == index;

        return DataRow(
          selected: isPlaying,
          color: MaterialStateProperty.resolveWith<Color>((states) {
            if (isPlaying) {
              return Colors.blue.withOpacity(0.3);
            }
            return Colors.grey[800]!;
          }),
          cells: [
            DataCell(
              Icon(
                isPlaying ? Icons.pause_circle : Icons.play_circle_outline,
                color: Colors.white,
              ),
              onTap: () => togglePlayPause(track, index),
            ),
            DataCell(
              Text(track['title'] ?? ''),
              onDoubleTap: () => playTrack(track, index),
            ),
            DataCell(Text(formatTime(track['duration'] ?? 0))),
            DataCell(Text(track['artist'] ?? '')),
            DataCell(Text(track['album'] ?? '')),
            DataCell(Text(track['genre'] ?? '')),
            DataCell(Text(track['rating']?.toString() ?? '')),
            DataCell(Text(track['play_count']?.toString() ?? '')),
            DataCell(Text(track['track_number']?.toString() ?? '')),
            DataCell(Text(track['year']?.toString() ?? '')),
          ],
        );
      }),
    );
  }

  TextStyle _headerStyle() {
    return TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
  }

  TextStyle _cellStyle() {
    return TextStyle(color: Colors.white);
  }
}
