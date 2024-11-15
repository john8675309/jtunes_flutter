import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import '../services/db_service.dart';
import 'package:audioplayers/audioplayers.dart';

class LoadingProgress {
  final List<Map<String, dynamic>> tracks;
  final int totalTracks;
  final int processedTracks;

  LoadingProgress(this.tracks, this.totalTracks, this.processedTracks);
  //LoadingProgress(this.tracks, this.totalTracks, this.processedTracks);
}

class MediaList extends StatefulWidget {
  final String selectedItem;
  final List<Map<String, dynamic>>? tracks;
  final String? ipodDbId;
  final int? dbVersion;
  final AudioPlayer audioPlayer;
  final Function(String?, String?) onTrackChange;

  const MediaList({
    super.key,
    required this.selectedItem,
    this.tracks,
    this.ipodDbId,
    this.dbVersion,
    required this.audioPlayer,
    required this.onTrackChange,
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

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
    void _setupAudioPlayer() {
      _audioPlayer.onPlayerStateChanged.listen((state) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      });

      setState(() {
        _isLoading = true;
        _processedTracks = [];
      });
      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() {
          _playingIndex = null;
          _isPlaying = false;
        });
      });
    }

    Future<void> _stopPlayback() async {
      await _audioPlayer.stop();
      setState(() {
        _playingIndex = null;
        _isPlaying = false;
      });
    }

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
    _audioPlayer.dispose();
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
      if (_playingIndex == index && _isPlaying) {
        await _audioPlayer.pause();
        return;
      } else if (_playingIndex == index && !_isPlaying) {
        await _audioPlayer.resume();
        return;
      }

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

      final source = DeviceFileSource(filePath);
      await _audioPlayer.play(source);
      setState(() {
        _playingIndex = index;
        _isPlaying = true;
      });
      widget.onTrackChange(track['title'], track['artist']);
    } catch (e) {
      print('Error playing track: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectedItem),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _processedTracks.isEmpty
              ? Center(child: Text("No tracks available"))
              : Column(
                  children: [
                    // Header Row
                    Container(
                      color: Colors.grey[850],
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          SizedBox(width: 50), // Play button space
                          Expanded(
                              flex: 3,
                              child: Text('Title',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text('Artist',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Text('Album',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              child: Text('Time',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              child: Text('Genre',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              child: Text('Track #',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              child: Text('Rating',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                              child: Text('Plays',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    // Tracks List
                    Expanded(
                      child: ListView.builder(
                        controller: _verticalController,
                        itemCount: _processedTracks.length,
                        itemBuilder: (context, index) {
                          final track = _processedTracks[index];
                          final isPlaying = _playingIndex == index;

                          return Container(
                            color:
                                isPlaying ? Colors.blue.withOpacity(0.3) : null,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: IconButton(
                                    icon: Icon(isPlaying
                                        ? Icons.pause_circle
                                        : Icons.play_circle_outline),
                                    onPressed: () => playTrack(track, index),
                                  ),
                                ),
                                Expanded(
                                    flex: 3,
                                    child: Text(track['title'] ?? 'Unknown')),
                                Expanded(
                                    flex: 2,
                                    child: Text(track['artist'] ?? '')),
                                Expanded(
                                    flex: 2, child: Text(track['album'] ?? '')),
                                Expanded(
                                    child: Text(
                                        _formatTime(track['duration'] ?? 0))),
                                Expanded(child: Text(track['genre'] ?? '')),
                                Expanded(
                                    child: Text(
                                        track['track_number']?.toString() ??
                                            '')),
                                Expanded(
                                    child: Text(
                                        track['rating']?.toString() ?? '')),
                                Expanded(
                                    child: Text(
                                        track['play_count']?.toString() ?? '')),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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
