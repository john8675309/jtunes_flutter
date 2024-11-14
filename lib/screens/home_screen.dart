import 'package:flutter/material.dart';
import '../widgets/top_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/media_list.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedItem = 'Recently Added';
  List<Map<String, dynamic>>? ipodTracks;
  String? ipodDbId;
  int? dbVersion;
  bool isIpodSelected = false;

  int getTotalTime() {
    if (isIpodSelected && ipodTracks != null) {
      return ipodTracks!.fold<int>(0, (sum, item) {
        // Ensure we're returning an integer
        final duration = item['duration'] as int? ?? 0;
        return sum + (duration ~/ 1000); // Use integer division
      });
    }
    return 0;
  }

  double getTotalSize() {
    if (isIpodSelected && ipodTracks != null) {
      return ipodTracks!.fold<double>(
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
  }) {
    setState(() {
      selectedItem = item;
      isIpodSelected = item == 'iPod';
      if (isIpodSelected) {
        ipodTracks = tracks;
        ipodDbId = dbId;
        dbVersion = version;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalTime = getTotalTime();
    double totalSize = getTotalSize();
    final trackCount = isIpodSelected ? (ipodTracks?.length ?? 0) : 0;

    return Scaffold(
      body: Column(
        children: [
          TopBar(),
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
                            selectedItem: selectedItem,
                            tracks: isIpodSelected ? ipodTracks : null,
                            ipodDbId: isIpodSelected ? ipodDbId : null,
                            dbVersion: isIpodSelected ? dbVersion : null,
                          ),
                        ),
                      ),
                      Container(
                        height: 50.0,
                        color: Colors.grey[850],
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$trackCount items',
                              style: TextStyle(color: Colors.white),
                            ),
                            SizedBox(width: 16.0),
                            Text(
                              'Total Time: ${formatTime(totalTime)}',
                              style: TextStyle(color: Colors.white),
                            ),
                            SizedBox(width: 16.0),
                            Text(
                              'Total Size: ${totalSize.toStringAsFixed(2)} MB',
                              style: TextStyle(color: Colors.white),
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
