import 'package:flutter/material.dart';

class NowPlayingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60.0,
      color: Colors.grey[900],
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(Icons.music_note),
          SizedBox(width: 16),
          Text('Now Playing: Song Name'),
          Spacer(),
          IconButton(onPressed: () {}, icon: Icon(Icons.skip_previous)),
          IconButton(onPressed: () {}, icon: Icon(Icons.play_arrow)),
          IconButton(onPressed: () {}, icon: Icon(Icons.skip_next)),
        ],
      ),
    );
  }
}
