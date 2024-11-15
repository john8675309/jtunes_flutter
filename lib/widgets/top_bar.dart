import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class TopBar extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final String? currentSong;
  final String? currentArtist;
  const TopBar({
    super.key,
    required this.audioPlayer,
    this.currentSong,
    this.currentArtist,
  });
  @override
  _TopBarState createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  double _volume = 1.0;
  bool _isMuted = false;
  double _lastVolume = 1.0;
  @override
  void initState() {
    super.initState();
    // Set initial volume
    widget.audioPlayer.setVolume(_volume);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80.0,
      color: Colors.grey[900],
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              // Playback Controls (Left-Aligned)
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: () {
                      // Add Back Functionality
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.play_arrow, color: Colors.white, size: 32),
                    onPressed: () {
                      // Add Play/Pause Functionality
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: Colors.white),
                    onPressed: () {
                      // Add Forward Functionality
                    },
                  ),
                  SizedBox(
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

              Spacer(),

              // Now Playing Box (Centered)
              Container(
                width: constraints.maxWidth > 600
                    ? 400.0
                    : constraints.maxWidth * 0.5,
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Now Playing: Song Title',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      'Artist Name',
                      style: TextStyle(color: Colors.grey[400]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),

              Spacer(),

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
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(Icons.search, color: Colors.white),
                          ),
                          Expanded(
                            child: TextField(
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 8.0),
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
                      icon: Icon(Icons.search, color: Colors.white),
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
