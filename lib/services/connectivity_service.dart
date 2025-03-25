import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isConnected = true;
  
  ConnectivityService() {
    _initConnectivity();
    _setupConnectivityListener();
  }

  bool get isConnected => _isConnected;

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _isConnected = false;
    }
    notifyListeners();
  }

  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _updateConnectionStatus(result);
      notifyListeners();
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    bool wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    if (wasConnected != _isConnected) {
      notifyListeners();
      
      if (_isConnected && !wasConnected) {
        syncLocalData();
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Cache data locally when offline
  Future<void> saveLocalData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(data);
      await prefs.setString(key, jsonData);
    } catch (e) {
      print('Error saving local data: $e');
    }
  }

  // Retrieve locally cached data
  Future<dynamic> getLocalData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(key);
      
      if (jsonData == null) return null;
      
      return jsonDecode(jsonData);
    } catch (e) {
      print('Error getting local data: $e');
      return null;
    }
  }

  // Check for offline data that needs syncing
  Future<List<String>> getPendingSyncKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncPending = prefs.getStringList('sync_pending') ?? [];
      return syncPending;
    } catch (e) {
      print('Error getting pending sync keys: $e');
      return [];
    }
  }

  // Add a key to the pending sync list
  Future<void> addToPendingSync(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncPending = prefs.getStringList('sync_pending') ?? [];
      
      if (!syncPending.contains(key)) {
        syncPending.add(key);
        await prefs.setStringList('sync_pending', syncPending);
      }
    } catch (e) {
      print('Error adding to pending sync: $e');
    }
  }

  // Remove a key from the pending sync list
  Future<void> removeFromPendingSync(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncPending = prefs.getStringList('sync_pending') ?? [];
      
      if (syncPending.contains(key)) {
        syncPending.remove(key);
        await prefs.setStringList('sync_pending', syncPending);
      }
    } catch (e) {
      print('Error removing from pending sync: $e');
    }
  }

  // Sync all pending data when back online
  Future<void> syncLocalData() async {
    if (!_isConnected) return;
    
    final pendingKeys = await getPendingSyncKeys();
    
    // This would be implemented by other services that register sync handlers
    // For now, we'll just clear the pending sync list
    for (final key in pendingKeys) {
      await removeFromPendingSync(key);
    }
    
    notifyListeners();
  }

  // Clear cached data (usually after successful sync)
  Future<void> clearLocalData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      print('Error clearing local data: $e');
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      return _isConnected;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _isConnected = false;
      return false;
    }
  }
} 