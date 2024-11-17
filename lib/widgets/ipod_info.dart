import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'media_list.dart';

class IpodInfo extends StatefulWidget {
  final List<Map<String, dynamic>>? tracks;
  final String? ipodDbId;
  final int? dbVersion;
  final String? modelInfo;
  final AudioPlayer audioPlayer;
  final Function(String?, String?) onTrackChange;

  const IpodInfo({
    super.key,
    this.tracks,
    this.ipodDbId,
    this.dbVersion,
    this.modelInfo,
    required this.audioPlayer,
    required this.onTrackChange,
  });

  @override
  _IpodInfoState createState() => _IpodInfoState();
}

class _IpodInfoState extends State<IpodInfo>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _playingIndex;
  bool _isPlaying = false;
  static const Map<String, String> modelToImage = {
    'xA101': 'assets/ipods/ipod_1g.png',
    'xA102': 'assets/ipods/ipod_2g.png',
    'xA103': 'assets/ipods/ipod_3g.png',
    'xA104': 'assets/ipods/ipod_4g.png',
    'xA105': 'assets/ipods/ipod_5g.png',
    'xB150': 'assets/ipods/ipod_6g.png', // 160GB Classic
    'xB120': 'assets/ipods/ipod_6g.png', // 120GB Classic
    'xB147': 'assets/ipods/ipod_7g.png',
    'xA130': 'assets/ipods/ipod_mini_1g.png',
    'xA131': 'assets/ipods/ipod_mini_2g.png',
    'xA204': 'assets/ipods/ipod_nano_1g.png',
    'xA205': 'assets/ipods/ipod_nano_2g.png',
    'xA206': 'assets/ipods/ipod_nano_3g.png',
    'xA211': 'assets/ipods/ipod_nano_4g.png',
    'xA212': 'assets/ipods/ipod_nano_5g.png',
    'xA213': 'assets/ipods/ipod_nano_6g.png',
    'xA214': 'assets/ipods/ipod_nano_7g.png',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingIndex = null;
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void updatePlayingState(int? index, bool isPlaying) {
    setState(() {
      _playingIndex = index;
      _isPlaying = isPlaying;
    });
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          const Text(
            'iPod',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          // iPod Info Section - Content Centered
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // iPod Icon
                  Container(
                    width: 120,
                    height: 200,
                    child: _buildIpodImage(),
                  ),
                  const SizedBox(width: 20),
                  // iPod Details
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.modelInfo
                                ?.split('\n')
                                .firstWhere(
                                    (line) => line.contains('Model Name:'),
                                    orElse: () => 'iPod')
                                .split(': ')
                                .last ??
                            'iPod',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                          'Serial Number:',
                          widget.modelInfo
                                  ?.split('\n')
                                  .firstWhere(
                                      (line) => line.contains('FirewireGuid:'),
                                      orElse: () => '')
                                  .split(': ')
                                  .last ??
                              ''),
                      _buildInfoRow('Software Version:', 'v2.0.1'),
                      _buildInfoRow('Format:', 'Normal'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          // Options Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 300,
                  child: _buildOptions(),
                ),
              ),
            ],
          ),
          const Divider(),
          // Capacity Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Capacity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildCapacityBar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIpodImage() {
    print('Full modelInfo: ${widget.modelInfo}');
    final modelNumber = widget.modelInfo
        ?.split('\n')
        .firstWhere((line) => line.contains('ModelNumStr:'), orElse: () => '')
        .split(': ')
        .last;

    final imagePath = modelToImage[modelNumber];
    print(widget.modelInfo);
    return Container(
      width: 120,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: imagePath != null
          ? Image.asset(
              imagePath,
              fit: BoxFit.contain,
            )
          : const Icon(Icons.music_note, size: 60, color: Colors.grey),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildCapacityBar() {
    // Extract disk info from modelInfo
    final lines = widget.modelInfo?.split('\n') ?? [];
    Map<String, String> diskInfo = {};

    // Look for disk information section
    bool inDiskSection = false;
    for (var line in lines) {
      if (line.contains('Disk Information:')) {
        inDiskSection = true;
        continue;
      }
      if (inDiskSection && line.contains(':')) {
        final parts = line.split(':');
        if (parts.length == 2) {
          diskInfo[parts[0].trim()] = parts[1].trim();
        }
      }
      if (inDiskSection && line.contains('Media Statistics')) {
        break;
      }
    }

    // Extract audio size from Media Statistics section
    String audioSize = '';
    bool inMediaSection = false;
    for (var line in lines) {
      if (line.contains('Media Statistics:')) {
        inMediaSection = true;
        continue;
      }
      if (inMediaSection && line.contains('Total Media Size:')) {
        audioSize = line.split(':')[1].trim();
        break;
      }
    }

    // Calculate proportions for the bar
    double totalGB = _parseSize(diskInfo['Total Size'] ?? '0 GB');
    double usedGB =
        _parseSize(diskInfo['Used Space']?.split('(')[0].trim() ?? '0 GB');
    double audioGB = _parseSize(audioSize);

    // Calculate flex values (as percentages of total)
    int audioFlex = ((audioGB / totalGB) * 100).round();
    int freeFlex = 100 - audioFlex;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 20,
            child: Row(
              children: [
                Expanded(
                  flex: audioFlex,
                  child: Container(
                    color: Colors.blue,
                    child: Center(
                      child: Text(
                        'Audio',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: freeFlex,
                  child: Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Text(
                        'Free Space',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLegendItem(
              Colors.blue,
              'Audio',
              audioSize,
            ),
            _buildLegendItem(
              Colors.grey[300]!,
              'Free Space',
              diskInfo['Free Space'] ?? 'N/A',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, String size) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text('$label: $size'),
      ],
    );
  }

  Widget _buildOptions() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Open iTunes when this iPod is connected'),
          value: false,
          onChanged: (bool? value) {},
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          title: const Text('Enable disk use'),
          value: false,
          onChanged: (bool? value) {},
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          title: const Text('Only sync checked songs and videos'),
          value: false,
          onChanged: (bool? value) {},
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          title: const Text('Manually manage music'),
          value: false,
          onChanged: (bool? value) {},
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iPod'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Music'),
            Tab(text: 'Photos'),
            Tab(text: 'Contacts'),
            Tab(text: 'Calendar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          MediaList(
            selectedItem: 'Music',
            tracks: widget.tracks,
            ipodDbId: widget.ipodDbId,
            dbVersion: widget.dbVersion,
            modelInfo: widget.modelInfo,
            audioPlayer: widget.audioPlayer,
            onTrackChange: widget.onTrackChange,
            playingIndex: _playingIndex, // Pass current playing state
            isPlaying: _isPlaying,
            onPlayingStateChanged: updatePlayingState,
          ),
          const Center(child: Text('Photos tab content')),
          const Center(child: Text('Contacts tab content')),
          const Center(child: Text('Calendar tab content')),
        ],
      ),
    );
  }

  double _parseSize(String sizeStr) {
    try {
      final numStr = sizeStr.split(' ')[0];
      return double.parse(numStr);
    } catch (e) {
      print('Error parsing size: $sizeStr');
      return 0.0;
    }
  }
}
