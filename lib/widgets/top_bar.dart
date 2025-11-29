import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:audiotags/audiotags.dart';
import 'dart:io';
import 'dart:typed_data';

class TopBar extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final String? currentSong;
  final String? currentArtist;
  final String? currentTrackPath;
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const TopBar({
    super.key,
    required this.audioPlayer,
    this.currentSong,
    this.currentArtist,
    this.currentTrackPath,
    this.isPlaying = false,
    this.onPlayPause,
    this.onNext,
    this.onPrevious,
  });
  @override
  // ignore: library_private_types_in_public_api
  _TopBarState createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  double _volume = 1.0;
  bool _isMuted = false;
  double _lastVolume = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  Future<Uint8List?>? _artworkFuture;

  @override
  void initState() {
    super.initState();
    // Set initial volume
    widget.audioPlayer.setVolume(_volume);
    _updateArtworkFuture();

    _positionSubscription = widget.audioPlayer.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });

    _durationSubscription = widget.audioPlayer.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });
  }

  @override
  void didUpdateWidget(TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTrackPath != oldWidget.currentTrackPath) {
      _updateArtworkFuture();
    }
  }

  void _updateArtworkFuture() {
    if (widget.currentTrackPath != null) {
      _artworkFuture = _loadArtwork(widget.currentTrackPath!);
    } else {
      _artworkFuture = null;
    }
  }

  Future<Uint8List?> _loadArtwork(String path) async {
    try {
      // 1. Priority: Try reading from tags (User confirmed correct metadata exists)
      // print("TopBar: Checking tags for artwork...");
      final tag = await AudioTags.read(path);
      if (tag != null && tag.pictures.isNotEmpty) {
        // print("TopBar: Loaded artwork from tags");
        return Uint8List.fromList(tag.pictures.first.bytes);
      }

      // 2. Fallback: Look for images in the directory
      // print("TopBar: No tag artwork, looking in directory...");
      final file = File(path);
      final directory = file.parent;
      if (await directory.exists()) {
        final files = directory.listSync();
        for (var f in files) {
          if (f is File) {
            final name = f.path.toLowerCase();
            if (name.endsWith('.jpg') ||
                name.endsWith('.jpeg') ||
                name.endsWith('.png')) {
              // print("TopBar: Found external artwork: ${f.path}");
              return await f.readAsBytes();
            }
          }
        }
      }
    } catch (e) {
      print("TopBar: Error loading artwork: $e");
    }
    return null;
  }



  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      if (_isMuted) {
        _volume = _lastVolume;
        _isMuted = false;
      } else {
        _lastVolume = _volume;
        _volume = 0;
        _isMuted = true;
      }
    });
    widget.audioPlayer.setVolume(_volume);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100.0, // Increased height to prevent overflow
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              // ... (keep Playback Controls)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: widget.onPrevious,
                  ),
                  IconButton(
                    icon: Icon(
                      widget.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: widget.onPlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: widget.onNext,
                  ),
                  const SizedBox(
                      width: 16.0), // Add spacing between buttons and slider

                  // Volume Slider
                  Row(
                    children: [
                      Slider(
                        value: _volume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged: (value) {
                          setState(() {
                            _volume = value;
                            _isMuted = value == 0;
                          });
                          widget.audioPlayer.setVolume(value);
                        },
                        activeColor: Colors.white,
                        inactiveColor: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Now Playing Box (Centered)
              Container(
                width: constraints.maxWidth > 600
                    ? 400.0
                    : constraints.maxWidth * 0.5,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Album Art
                    // Album Art
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 12.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4.0),
                        color: Colors.grey[700],
                      ),
                      child: _artworkFuture != null
                          ? FutureBuilder<Uint8List?>(
                              future: _artworkFuture,
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(4.0),
                                    child: Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        print("TopBar: Image render error: $error");
                                        return const Icon(Icons.broken_image,
                                            color: Colors.white54);
                                      },
                                    ),
                                  );
                                }
                                return const Icon(Icons.music_note,
                                    color: Colors.white54);
                              },
                            )
                          : const Icon(Icons.music_note, color: Colors.white54),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center, // Centered alignment
                        children: [
                          Text(
                            widget.currentSong != null
                                ? 'Now Playing: ${widget.currentSong}'
                                : 'Not Playing',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            widget.currentArtist ?? '',
                            style: TextStyle(color: Colors.grey[400]),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          if (widget.currentSong != null) ...[
                            SizedBox(
                              height: 20,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2.0,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6.0),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14.0),
                                ),
                                child: Slider(
                                  value: _position.inSeconds
                                      .toDouble()
                                      .clamp(
                                          0.0, _duration.inSeconds.toDouble()),
                                  min: 0.0,
                                  max: _duration.inSeconds.toDouble() > 0
                                      ? _duration.inSeconds.toDouble()
                                      : 1.0,
                                  onChanged: (value) {
                                    final position =
                                        Duration(seconds: value.toInt());
                                    widget.audioPlayer.seek(position);
                                  },
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.grey,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_position),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10),
                                  ),
                                  Text(
                                    _formatDuration(_duration),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Search Box (Right-Aligned)
              constraints.maxWidth > 600
                  ? Container(
                      width: 300.0,
                      height: 40.0,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(Icons.search, color: Colors.white),
                          ),
                          Expanded(
                            child: TextField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                              ),
                              onChanged: (value) {
                                // Add search functionality
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: () {
                        // Open a modal or navigate to a search page
                      },
                    ),
            ],
          );
        },
      ),
    );
  }
}
