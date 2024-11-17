import 'dart:async';
import 'package:flutter/foundation.dart';
import 'libgpod_bridge.dart';

class IpodService extends ChangeNotifier {
  final IpodDatabase _database = IpodDatabase();
  List<Map<String, dynamic>> _tracks = [];
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  List<Map<String, dynamic>> get tracks => List.unmodifiable(_tracks);

  Future<bool> connectToIpod(String mountPoint) async {
    try {
      _isConnected = await _database.open(mountPoint);
      if (_isConnected) {
        print("**************************************");
        print(_database.getModelInfo());
        _tracks = _database.getTracks();
        notifyListeners();
      }
      return _isConnected;
    } catch (e) {
      print('Error connecting to iPod: $e');
      _isConnected = false;
      return false;
    }
  }

  void disconnect() {
    _database.close();
    _isConnected = false;
    _tracks = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }
}
