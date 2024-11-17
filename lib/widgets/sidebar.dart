import 'package:flutter/material.dart';
import '../libgpod_bridge.dart';
import '../services/db_service.dart';

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

  @override
  void initState() {
    super.initState();
    _checkForIpod();
  }

  Future<void> _checkForIpod() async {
    try {
      _ipodDb = IpodDatabase();
      bool connected = await _ipodDb!.open('/media/john/IPOD');

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
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SidebarSection(
            title: 'Library',
            items: [
              SidebarItem(label: 'Recently Added', icon: Icons.access_time),
              SidebarItem(label: 'Artists', icon: Icons.person),
              SidebarItem(label: 'Albums', icon: Icons.album),
              SidebarItem(label: 'Songs', icon: Icons.music_note),
              SidebarItem(label: 'Genres', icon: Icons.category),
              SidebarItem(label: 'Video', icon: Icons.video_library),
              SidebarItem(label: 'Radio', icon: Icons.radio),
            ],
            initiallyExpanded: true,
            onItemSelected: (item) => widget.onItemSelected(item),
          ),
          SidebarSection(
            title: 'Playlists',
            items: [
              SidebarItem(label: 'Playlist 1', icon: Icons.playlist_play),
              SidebarItem(label: 'Playlist 2', icon: Icons.playlist_play),
            ],
            initiallyExpanded: true,
            onItemSelected: (item) => widget.onItemSelected(item),
          ),
          if (_isIpodConnected) ...[
            ListTile(
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
    );
  }
}

class SidebarSection extends StatelessWidget {
  final String title;
  final List<SidebarItem> items;
  final void Function(String) onItemSelected;
  final bool initiallyExpanded;

  const SidebarSection({
    super.key,
    required this.title,
    required this.items,
    required this.onItemSelected,
    this.initiallyExpanded = false,
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
      children: items
          .map((item) => ListTile(
                leading: Icon(item.icon, color: Colors.white),
                title: Text(
                  item.label,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  onItemSelected(item.label);
                },
              ))
          .toList(),
    );
  }
}

class SidebarItem {
  final String label;
  final IconData icon;

  SidebarItem({required this.label, required this.icon});
}
