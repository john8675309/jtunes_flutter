import 'package:flutter/material.dart';
import '../widgets/top_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/media_list.dart';
import '../widgets/ipod_info.dart';
import 'package:audioplayers/audioplayers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer audioPlayer = AudioPlayer();
  final GlobalKey<MediaListState> _mediaListKey = GlobalKey<MediaListState>();
  String selectedItem = 'Recently Added';
  List<Map<String, dynamic>>? currentTracks; // Renamed from ipodTracks to be more generic
  String? ipodDbId;
  int? dbVersion;
  String? currentSong;
  String? modelInfo;
  String? currentArtist;
  String? currentTrackPath; // Add this field
  bool isIpodSelected = false;
  int? _playingIndex;
  bool _isPlaying = false;

  void updateCurrentTrack(String? song, String? artist, String? path) {
    setState(() {
      currentSong = song;
      currentArtist = artist;
      currentTrackPath = path;
    });
  }

  void updatePlayingState(int? index, bool isPlaying) {
    setState(() {
      _playingIndex = index;
      _isPlaying = isPlaying;
    });
  }

  void _handlePlayPause() {
    _mediaListKey.currentState?.togglePlayPause();
  }

  void _handleNext() {
    _mediaListKey.currentState?.playNext();
  }

  void _handlePrevious() {
    _mediaListKey.currentState?.playPrevious();
  }

  int getTotalTime() {
    if (currentTracks != null) {
      return currentTracks!.fold<int>(0, (sum, item) {
        // Ensure we're returning an integer
        final duration = item['duration'] as int? ?? 0;
        return sum + (duration ~/ 1000); // Use integer division
      });
    }
    return 0;
  }

  double getTotalSize() {
    if (currentTracks != null) {
      return currentTracks!.fold<double>(
          0, (sum, item) => sum + ((item['size'] ?? 0) / (1024 * 1024)));
    }
    return 0.0;
  }

  String formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void updateSelectedItem(
    String item, {
    List<Map<String, dynamic>>? tracks,
    String? dbId,
    int? version,
    String? deviceInfo,
  }) {
    setState(() {
      selectedItem = item;
      isIpodSelected = item == 'iPod';
      currentTracks = tracks; // Always update tracks
      if (isIpodSelected) {
        ipodDbId = dbId;
        dbVersion = version;
        modelInfo = deviceInfo;
      }
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int totalTime = getTotalTime();
    double totalSize = getTotalSize();
    final trackCount = currentTracks?.length ?? 0;

    return Scaffold(
      body: Column(
        children: [
          TopBar(
            audioPlayer: audioPlayer,
            currentSong: currentSong,
            currentArtist: currentArtist,
            currentTrackPath: currentTrackPath,
            isPlaying: _isPlaying,
            onPlayPause: _handlePlayPause,
            onNext: _handleNext,
            onPrevious: _handlePrevious,
          ),
          Expanded(
            child: Row(
              children: [
                Sidebar(onItemSelected: updateSelectedItem),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: MediaList(
                            key: _mediaListKey,
                            selectedItem: selectedItem,
                            tracks: currentTracks, // Pass currentTracks
                            ipodDbId: isIpodSelected ? ipodDbId : null,
                            dbVersion: isIpodSelected ? dbVersion : null,
                            modelInfo: isIpodSelected ? modelInfo : null,
                            audioPlayer: audioPlayer,
                            onTrackChange: updateCurrentTrack,
                            playingIndex: _playingIndex,
                            isPlaying: _isPlaying,
                            onPlayingStateChanged: updatePlayingState,
                          ),
                        ),
                      ),
                      Container(
                        height: 50.0,
                        color: Colors.grey[850],
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$trackCount items',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(width: 16.0),
                            Text(
                              'Total Time: ${formatTime(totalTime)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(width: 16.0),
                            Text(
                              'Total Size: ${totalSize.toStringAsFixed(2)} MB',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
