import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:audiotags/audiotags.dart';

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
  final String? modelInfo;
  final AudioPlayer audioPlayer;
  final Function(String?, String?, String?) onTrackChange;
  final int? playingIndex; // Add these new properties
  final bool isPlaying;
  final Function(int?, bool) onPlayingStateChanged;

  const MediaList({
    super.key,
    required this.selectedItem,
    this.tracks,
    this.ipodDbId,
    this.dbVersion,
    required this.audioPlayer,
    required this.onTrackChange,
    this.modelInfo,
    this.playingIndex, // Add these new properties
    this.isPlaying = false,
    required this.onPlayingStateChanged,
  });

  @override
  MediaListState createState() => MediaListState();
}

enum ViewLevel { artists, albums, songs }

class MediaListState extends State<MediaList> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  Process? _playerProcess;
  int? _playingIndex;
  Timer? _checkProcessTimer;
  List<Map<String, dynamic>> _processedTracks = [];
  bool _isLoading = false;
  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerCompleteSubscription;
  // final AudioPlayer _audioPlayer = AudioPlayer(); // Removed local instance
  bool _isPlaying = false;

  // Hierarchy state
  ViewLevel _viewLevel = ViewLevel.artists;
  String? _selectedArtist;
  String? _selectedAlbum;

  // Public methods for HomeScreen to call
  void playNext() {
    if (_playingIndex != null && _playingIndex! < _processedTracks.length - 1) {
      int nextIndex = _playingIndex! + 1;
      playTrack(_processedTracks[nextIndex], nextIndex);
    }
  }

  void playPrevious() {
    if (_playingIndex != null && _playingIndex! > 0) {
      int prevIndex = _playingIndex! - 1;
      playTrack(_processedTracks[prevIndex], prevIndex);
    }
  }

  void togglePlayPause() async {
    if (_playingIndex == null && _processedTracks.isNotEmpty) {
      // Start playing first track if nothing is playing
      playTrack(_processedTracks[0], 0);
    } else if (_playingIndex != null) {
      if (_isPlaying) {
        await widget.audioPlayer.pause();
        widget.onPlayingStateChanged(_playingIndex, false);
      } else {
        await widget.audioPlayer.resume();
        widget.onPlayingStateChanged(_playingIndex, true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    print("Initializing MediaList...");
    print(widget.modelInfo);
    _playingIndex = widget.playingIndex;
    _isPlaying = widget.isPlaying;

    _playerStateSubscription = widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _playerCompleteSubscription = widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        if (_playingIndex != null &&
            _playingIndex! < _processedTracks.length - 1) {
          // Auto-advance to next track
          int nextIndex = _playingIndex! + 1;
          playTrack(_processedTracks[nextIndex], nextIndex);
        } else {
          setState(() {
            _playingIndex = null;
            _isPlaying = false;
          });
        }
      }
    });

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
      // Reset hierarchy when tracks change (e.g. new directory loaded)
      if (widget.selectedItem == 'Local Music') {
        setState(() {
          _viewLevel = ViewLevel.artists;
          _selectedArtist = null;
          _selectedAlbum = null;
        });
      }
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

    // Future<void> stopPlayback() async {
    //   await _audioPlayer.stop();
    //   setState(() {
    //     _playingIndex = null;
    //     _isPlaying = false;
    //   });
    // }

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
        //print("Progress: ${message.processedTracks}/${message.totalTracks}");
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

      for (var originalTrack in batch) {
        // Create a mutable copy of the track map
        final track = Map<String, dynamic>.from(originalTrack);

        // Clean genre
        if (track['genre'] != null) {
          track['genre'] = track['genre'].toString().split(';').first.trim();
        }

        // Determine category
        String category = 'music';
        final podcastUrl = track['podcast_url']?.toString() ?? '';
        final tvShow = track['tv_show']?.toString() ?? '';
        final fileType = track['file_type']?.toString().toLowerCase() ?? '';
        final genre = track['genre']?.toString().toLowerCase() ?? '';

        if (podcastUrl.isNotEmpty || genre.contains('podcast')) {
          category = 'podcast';
        } else if (tvShow.isNotEmpty || ['m4v', 'mov', 'mp4'].contains(fileType)) {
           // Note: mp4 can be audio, but often video on iPods. 
           // We might need better logic later, but this is a start.
           // If type1 is available we could use that.
           category = 'video';
        }
        
        // Debug print to force isolate update
        // print('Processing track: ${track['title']} -> $category');

        processedTracks.add({...track, 'processed': true, 'category': category});
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
    _playerStateSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    // _audioPlayer.dispose(); // Do not dispose widget.audioPlayer here
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
        await widget.audioPlayer.pause();
        widget.onPlayingStateChanged(index, false);
        return;
      } else if (_playingIndex == index && !_isPlaying) {
        await widget.audioPlayer.resume();
        widget.onPlayingStateChanged(index, true);
        return;
      }

      await _stopPlayback();

      final path = track['path'] as String;
      if (path.isEmpty) return;

      String filePath;
      if (path.startsWith('/')) {
        // Absolute path for local files
        filePath = path;
      } else {
        // iPod path
        final fullPath = path.replaceAll(':', '/');
        const mountPoint = '/media/john/iPod';
        filePath = '$mountPoint/$fullPath';
      }

      if (!await File(filePath).exists()) {
        print('File not found: $filePath');
        return;
      }

      final source = DeviceFileSource(filePath);
      await widget.audioPlayer.play(source);
      widget.onPlayingStateChanged(index, true);
      print('MediaList playing path: $filePath'); // Debug print
      widget.onTrackChange(track['title'], track['artist'], filePath);
      setState(() {
        _playingIndex = index;
        _isPlaying = true;
      });
      widget.onTrackChange(track['title'], track['artist'], filePath);
    } catch (e) {
      print('Error playing track: $e');
    }
  }

  void _navigateToAlbums(String artist) {
    setState(() {
      _selectedArtist = artist;
      _viewLevel = ViewLevel.albums;
    });
  }

  void _navigateToSongs(String album) {
    setState(() {
      _selectedAlbum = album;
      _viewLevel = ViewLevel.songs;
    });
  }

  void _navigateBack() {
    setState(() {
      if (_viewLevel == ViewLevel.songs) {
        _viewLevel = ViewLevel.albums;
        _selectedAlbum = null;
      } else if (_viewLevel == ViewLevel.albums) {
        _viewLevel = ViewLevel.artists;
        _selectedArtist = null;
      }
    });
  }

  Widget _buildArtistsView(List<Map<String, dynamic>> tracks) {
    final artists = tracks
        .map((t) => t['artist'] as String? ?? 'Unknown')
        .toSet()
        .toList()
      ..sort();

    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final trackCount =
            tracks.where((t) => t['artist'] == artist).length;
        return ListTile(
          leading: const Icon(Icons.person, color: Colors.white),
          title: Text(artist, style: const TextStyle(color: Colors.white)),
          subtitle: Text('$trackCount songs',
              style: TextStyle(color: Colors.grey[400])),
          onTap: () => _navigateToAlbums(artist),
          trailing: const Icon(Icons.chevron_right, color: Colors.white),
        );
      },
    );
  }

  // ...

  Widget _buildAlbumsView(List<Map<String, dynamic>> tracks) {
    final albums = tracks
        .where((t) => t['artist'] == _selectedArtist)
        .map((t) => t['album'] as String? ?? 'Unknown')
        .toSet()
        .toList()
      ..sort();

    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final albumTracks = tracks
            .where((t) => t['artist'] == _selectedArtist && t['album'] == album)
            .toList();
        final trackCount = albumTracks.length;
        final firstTrackPath = albumTracks.first['path'] as String;
        String resolvedPath = firstTrackPath;
        if (!firstTrackPath.startsWith('/')) {
           final fullPath = firstTrackPath.replaceAll(':', '/');
           const mountPoint = '/media/john/iPod';
           resolvedPath = '$mountPoint/$fullPath';
        }

        return Draggable<List<Map<String, dynamic>>>(
          data: albumTracks,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.grey[800],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.album, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    '$album ($trackCount songs)',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          child: ListTile(
            leading: SizedBox(
              width: 50,
              height: 50,
              child: FutureBuilder<Tag?>(
                future: AudioTags.read(resolvedPath),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data?.pictures.isNotEmpty == true) {
                    return Image.memory(
                      Uint8List.fromList(snapshot.data!.pictures.first.bytes),
                      fit: BoxFit.cover,
                    );
                  }
                  return const Icon(Icons.album, color: Colors.white);
                },
              ),
            ),
            title: Text(album, style: const TextStyle(color: Colors.white)),
            subtitle: Text('$trackCount songs',
                style: TextStyle(color: Colors.grey[400])),
            onTap: () => _navigateToSongs(album),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                  onPressed: () {
                    // Play first track of album
                    final firstTrackIndex = _processedTracks.indexOf(albumTracks.first);
                    if (firstTrackIndex != -1) {
                      playTrack(albumTracks.first, firstTrackIndex);
                    }
                  },
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongsView(List<Map<String, dynamic>> tracks) {
    final songs = tracks
        .where((t) =>
            t['artist'] == _selectedArtist && t['album'] == _selectedAlbum)
        .toList();
    
    // Sort by track number, then title
    songs.sort((a, b) {
      int trackA = a['track_number'] as int? ?? 0;
      int trackB = b['track_number'] as int? ?? 0;
      if (trackA != trackB) return trackA.compareTo(trackB);
      return (a['title'] as String? ?? '').compareTo(b['title'] as String? ?? '');
    });

    return Column(
      children: [
        // Header Row
        Container(
          color: Colors.grey[850],
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: const Row(
            children: [
              SizedBox(width: 50), // Play button space
              Expanded(
                  flex: 3,
                  child: Text('Title',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('Artist',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('Album',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('Time',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('Genre',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('Track #',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('Rating',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('Plays',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(
                  width: 50,
                  child: Text('Edit',
                      style: TextStyle(
                          fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        // Tracks List
        Expanded(
          child: ListView.builder(
            controller: _verticalController,
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final track = songs[index];
              // Find the original index in _processedTracks to play correct song
              final originalIndex = _processedTracks.indexOf(track);
              final isPlaying = _playingIndex == originalIndex;

              return Draggable<List<Map<String, dynamic>>>(
                data: [track],
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.grey[800],
                    child: Text(
                      track['title'] ?? 'Unknown',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                child: Container(
                  color: isPlaying ? Colors.blue.withOpacity(0.3) : null,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: IconButton(
                          icon: Icon(isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle_outline),
                          onPressed: () => playTrack(track, originalIndex),
                        ),
                      ),
                      Expanded(
                          flex: 3, child: Text(track['title'] ?? 'Unknown')),
                      Expanded(flex: 2, child: Text(track['artist'] ?? '')),
                      Expanded(flex: 2, child: Text(track['album'] ?? '')),
                      Expanded(child: Text(_formatTime(track['duration'] ?? 0))),
                      Expanded(child: Text(track['genre'] ?? '')),
                      Expanded(
                          child: Text(track['track_number']?.toString() ?? '')),
                      Expanded(child: Text(track['rating']?.toString() ?? '')),
                      Expanded(
                          child: Text(track['play_count']?.toString() ?? '')),
                      SizedBox(
                        width: 50,
                        child: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Edit Metadata',
                          onPressed: () {
                            if (track['path'] != null) {
                              _showEditMetadataDialog(context, track);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showEditMetadataDialog(
      BuildContext context, Map<String, dynamic> track) async {
    final titleController = TextEditingController(text: track['title']);
    final artistController = TextEditingController(text: track['artist']);
    final albumController = TextEditingController(text: track['album']);
    final yearController = TextEditingController(text: track['year']);
    final genreController = TextEditingController(text: track['genre']);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Edit Metadata',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('Title', titleController),
                _buildTextField('Artist', artistController),
                _buildTextField('Album', albumController),
                _buildTextField('Year', yearController),
                _buildTextField('Genre', genreController),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  // Read current tag to preserve pictures
                  final currentTag = await AudioTags.read(track['path']);
                  
                  final tag = Tag(
                    title: titleController.text,
                    trackArtist: artistController.text,
                    album: albumController.text,
                    year: int.tryParse(yearController.text),
                    genre: genreController.text,
                    pictures: currentTag?.pictures ?? [],
                  );
                  await AudioTags.write(track['path'], tag);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Metadata updated successfully')),
                    );
                    // Refresh the list (re-scan the directory)
                    // For now, we just update the local list item to reflect changes immediately
                    setState(() {
                      track['title'] = titleController.text;
                      track['artist'] = artistController.text;
                      track['album'] = albumController.text;
                      track['year'] = yearController.text;
                      track['genre'] = genreController.text;
                    });
                  }
                } catch (e) {
                  print('Error writing tags: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating metadata: $e')),
                    );
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIpod = widget.selectedItem == 'iPod';
    final isLocalLibrary = !isIpod; // Assume anything else is local library for now

    // Filter tracks based on selection
    List<Map<String, dynamic>> displayedTracks = [];
    if (isLocalLibrary && _processedTracks.isNotEmpty) {
      switch (widget.selectedItem) {
        case 'Recently Added':
           displayedTracks = List.from(_processedTracks);
           displayedTracks.sort((a, b) => (b['date_added'] as int? ?? 0).compareTo(a['date_added'] as int? ?? 0));
           break;
        case 'Music':
          displayedTracks = _processedTracks.where((t) {
             final genre = t['genre']?.toString().toLowerCase() ?? '';
             final fileType = t['path']?.toString().split('.').last.toLowerCase() ?? '';
             return !genre.contains('podcast') && !['m4v', 'mov', 'mp4'].contains(fileType);
          }).toList();
          break;
        case 'Videos':
          displayedTracks = _processedTracks.where((t) {
             final fileType = t['path']?.toString().split('.').last.toLowerCase() ?? '';
             return ['m4v', 'mov', 'mp4'].contains(fileType);
          }).toList();
          break;
        case 'Podcasts':
          displayedTracks = _processedTracks.where((t) {
             final genre = t['genre']?.toString().toLowerCase() ?? '';
             return genre.contains('podcast');
          }).toList();
          break;
        case 'Genres':
          // Genres view is special, handled below
          displayedTracks = _processedTracks;
          break;
        case 'Radio':
          // Placeholder
          break;
        default:
          displayedTracks = _processedTracks;
      }
    }

    Widget content = Scaffold(
      appBar: AppBar(
        title: Text(isLocalLibrary
            ? widget.selectedItem == 'Music' && _viewLevel != ViewLevel.artists
                ? _viewLevel == ViewLevel.albums
                    ? _selectedArtist ?? 'Albums'
                    : _selectedAlbum ?? 'Songs'
                : widget.selectedItem
            : (isIpod && _viewLevel != ViewLevel.artists)
                ? _viewLevel == ViewLevel.artists
                    ? 'Artists'
                    : _viewLevel == ViewLevel.albums
                        ? _selectedArtist ?? 'Albums'
                        : _selectedAlbum ?? 'Songs'
                : widget.selectedItem),
        leading: ((isLocalLibrary && widget.selectedItem == 'Music' && _viewLevel != ViewLevel.artists) || 
                  (isIpod && _viewLevel != ViewLevel.artists))
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateBack,
              )
            : null,
        bottom: isIpod
            ? const TabBar(
                tabs: [
                  Tab(text: 'Summary'),
                  Tab(text: 'Music'),
                  Tab(text: 'Video'),
                  Tab(text: 'TV Shows'),
                  Tab(text: 'Podcasts'),
                  Tab(text: 'Photos'),
                  Tab(text: 'Info'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _processedTracks.isEmpty && !isIpod
              ? const Center(child: Text("No tracks available"))
              : isLocalLibrary
                  ? _buildLocalContent(displayedTracks)
                  : isIpod
                      ? Builder(
                          builder: (context) {
                            final musicTracks = _processedTracks.where((t) => t['category'] == 'music').toList();
                            final videoTracks = _processedTracks.where((t) => t['category'] == 'video').toList();
                            final podcastTracks = _processedTracks.where((t) => t['category'] == 'podcast').toList();
                            
                            return TabBarView(
                              children: [
                                // Summary Tab
                                _buildSummaryView(),
                                // Music Tab
                                _viewLevel == ViewLevel.artists
                                    ? _buildArtistsView(musicTracks)
                                    : _viewLevel == ViewLevel.albums
                                        ? _buildAlbumsView(musicTracks)
                                        : _buildSongsView(musicTracks),
                                // Video Tab
                                _buildFlatTrackList(videoTracks),
                                // TV Shows Tab
                                _buildFlatTrackList(videoTracks), // Reuse video category for now
                                // Podcasts Tab
                                _buildFlatTrackList(podcastTracks),
                                // Photos Tab
                                const Center(child: Text('Photos not implemented yet')),
                                // Info Tab
                                const Center(child: Text('Info not implemented yet')),
                              ],
                            );
                          }
                        )
                      : Column(
                          children: [
                            // ... existing column content for other items ...
                          ],
                        ),
    );

    if (isIpod) {
      return DefaultTabController(length: 7, child: content);
    }
    return content;
  }

  Widget _buildLocalContent(List<Map<String, dynamic>> tracks) {
    if (widget.selectedItem == 'Genres') {
      return _buildGenresView(tracks);
    } else if (widget.selectedItem == 'Music') {
       if (_viewLevel == ViewLevel.artists) {
         return _buildArtistsView(tracks);
       } else if (_viewLevel == ViewLevel.albums) {
         return _buildAlbumsView(tracks);
       } else {
         return _buildSongsView(tracks);
       }
    } else if (widget.selectedItem == 'Radio') {
       return const Center(child: Text("Radio not implemented yet"));
    }
    
    // Default flat list for Recently Added, Videos, Podcasts
    return _buildFlatTrackList(tracks);
  }

  Widget _buildGenresView(List<Map<String, dynamic>> tracks) {
    final genres = tracks
        .map((t) => t['genre'] as String? ?? 'Unknown')
        .toSet()
        .toList()
      ..sort();

    return ListView.builder(
      itemCount: genres.length,
      itemBuilder: (context, index) {
        final genre = genres[index];
        final trackCount = tracks.where((t) => t['genre'] == genre).length;
        return ListTile(
          leading: const Icon(Icons.category, color: Colors.white),
          title: Text(genre, style: const TextStyle(color: Colors.white)),
          subtitle: Text('$trackCount songs',
              style: TextStyle(color: Colors.grey[400])),
          onTap: () {
             // For now, just print or maybe navigate to a filtered list?
             // The user didn't specify drill-down for genres, so listing is fine.
             // We could implement drill-down later.
          },
        );
      },
    );
  }

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

  Widget _buildSummaryView() {
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
    final modelNumber = widget.modelInfo
        ?.split('\n')
        .firstWhere((line) => line.contains('ModelNumStr:'), orElse: () => '')
        .split(': ')
        .last;

    final imagePath = modelToImage[modelNumber];
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
    int audioFlex = totalGB > 0 ? ((audioGB / totalGB) * 100).round() : 0;
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
                  flex: audioFlex > 0 ? audioFlex : 1,
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
                  flex: freeFlex > 0 ? freeFlex : 1,
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

  double _parseSize(String sizeStr) {
    try {
      final numStr = sizeStr.split(' ')[0];
      return double.parse(numStr);
    } catch (e) {
      // print('Error parsing size: $sizeStr');
      return 0.0;
    }
  }

  Widget _buildFlatTrackList(List<Map<String, dynamic>> tracks) {
    return Column(
      children: [
        // Header Row
        Container(
          color: Colors.grey[850],
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: const Row(
            children: [
              SizedBox(width: 50), // Play button space
              Expanded(
                  flex: 3,
                  child: Text('Title',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('Artist',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('Album',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('Time',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('Genre',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('Track #',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('Rating',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('Plays',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(
                  width: 50,
                  child: Text('Edit',
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        // Tracks List
        Expanded(
          child: ListView.builder(
            controller: _verticalController,
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              // Find the original index in _processedTracks to play correct song
              final originalIndex = _processedTracks.indexOf(track);
              final isPlaying = _playingIndex == originalIndex;

              return Container(
                color: isPlaying ? Colors.blue.withOpacity(0.3) : null,
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: IconButton(
                        icon: Icon(isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle_outline),
                        onPressed: () => playTrack(track, originalIndex),
                      ),
                    ),
                    Expanded(
                        flex: 3, child: Text(track['title'] ?? 'Unknown')),
                    Expanded(flex: 2, child: Text(track['artist'] ?? '')),
                    Expanded(flex: 2, child: Text(track['album'] ?? '')),
                    Expanded(child: Text(_formatTime(track['duration'] ?? 0))),
                    Expanded(child: Text(track['genre'] ?? '')),
                    Expanded(
                        child: Text(track['track_number']?.toString() ?? '')),
                    Expanded(child: Text(track['rating']?.toString() ?? '')),
                    Expanded(
                        child: Text(track['play_count']?.toString() ?? '')),
                    SizedBox(
                      width: 50,
                      child: IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Edit Metadata',
                        onPressed: () {
                          if (track['path'] != null) {
                            _showEditMetadataDialog(context, track);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
