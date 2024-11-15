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
  final String? ipodDbId;
  final int? dbVersion;

  const MediaList({
    super.key,
    required this.selectedItem,
    this.tracks,
    this.ipodDbId,
    this.dbVersion,
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
  Isolate? _isolate;
  ReceivePort? _receivePort;

  @override
  void initState() {
    super.initState();
    print("Initializing MediaList...");
    _loadTracksInBackground();
  }

  @override
  void didUpdateWidget(MediaList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tracks != oldWidget.tracks) {
      print("Tracks updated, reloading...");
      _isolate?.kill();
      _receivePort?.close();
      _loadTracksInBackground();
    }
  }

  Future<void> _loadTracksInBackground() async {
    if (widget.tracks == null || widget.tracks!.isEmpty) {
      print("No tracks to process.");
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
    _receivePort = receivePort;

    print("Spawning isolate for track processing...");
    await Isolate.spawn(
      _processTracks,
      {
        'sendPort': receivePort.sendPort,
        'tracks': widget.tracks,
        'batchSize': 50,
      },
    );

    receivePort.listen((message) {
      if (message is LoadingProgress) {
        print("Progress: ${message.processedTracks}/${message.totalTracks}");
        setState(() {
          _processedTracks = message.tracks;
          _isLoading = message.processedTracks < message.totalTracks;
        });
      }
    });
  }

  static void _processTracks(Map<String, dynamic> message) {
    final SendPort sendPort = message['sendPort'];
    final List<Map<String, dynamic>> tracks = message['tracks'];
    final int batchSize = message['batchSize'];
    final processedTracks = <Map<String, dynamic>>[];

    print("Processing ${tracks.length} tracks in batches of $batchSize...");
    for (var i = 0; i < tracks.length; i += batchSize) {
      final endIndex =
          (i + batchSize < tracks.length) ? i + batchSize : tracks.length;
      final batch = tracks.sublist(i, endIndex);

      for (var track in batch) {
        processedTracks.add({...track, 'processed': true});
      }

      sendPort.send(LoadingProgress(
        List.from(processedTracks),
        tracks.length,
        processedTracks.length,
      ));
    }
    print("Finished processing tracks.");
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _stopPlayback();
    _checkProcessTimer?.cancel();
    _isolate?.kill();
    _receivePort?.close();
    super.dispose();
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
      await _stopPlayback();

      final path = track['path'] as String;
      if (path.isEmpty) return;

      final fullPath = path.replaceAll(':', '/');
      final mountPoint = '/media/john/IPOD';
      final filePath = '$mountPoint/$fullPath';

      if (!await File(filePath).exists()) {
        print('File not found: $filePath');
        return;
      }

      _playerProcess = await Process.start('mpv', [
        '--no-video',
        '--no-terminal',
        '--no-config',
        filePath,
      ]);

      setState(() {
        _playingIndex = index;
      });

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
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        "Building MediaList widget. Processed tracks: ${_processedTracks.length}");

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectedItem),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _processedTracks.isEmpty
              ? Center(child: Text("No tracks available"))
              : ListView.builder(
                  controller: _verticalController,
                  itemCount: _processedTracks.length,
                  itemBuilder: (context, index) {
                    final track = _processedTracks[index];
                    final isPlaying = _playingIndex == index;
                    return ListTile(
                      leading: Icon(
                        isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle_outline,
                      ),
                      title: Text(track['title'] ?? 'Unknown'),
                      subtitle: Text(track['artist'] ?? 'Unknown Artist'),
                      trailing: Text(_formatTime(track['duration'] ?? 0)),
                      onTap: () => playTrack(track, index),
                    );
                  },
                ),
    );
  }

  String _formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
