import 'package:flutter/material.dart';

class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60.0,
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const Icon(Icons.music_note),
          const SizedBox(width: 16),
          const Text('Now Playing: Song Name'),
          const Spacer(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.skip_previous)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.play_arrow)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.skip_next)),
        ],
      ),
    );
  }
}
