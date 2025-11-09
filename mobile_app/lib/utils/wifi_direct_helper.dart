import 'dart:async';
import 'package:flutter/services.dart';

/// Helper class for WiFi Direct functionality on Android
/// Provides direct device-to-device connections for faster transfers
class WiFiDirectHelper {
  static const MethodChannel _channel = MethodChannel('rapid_transfer/wifi_direct');
  
  static bool _isSupported = false;
  static bool _isEnabled = false;
  static StreamSubscription? _peerListener;
  
  /// Check if WiFi Direct is supported on this device
  static Future<bool> isSupported() async {
    try {
      _isSupported = await _channel.invokeMethod('isSupported') ?? false;
      return _isSupported;
    } catch (e) {
      print('WiFi Direct not supported: $e');
      return false;
    }
  }
  
  /// Check if WiFi Direct is currently enabled
  static Future<bool> isEnabled() async {
    try {
      _isEnabled = await _channel.invokeMethod('isEnabled') ?? false;
      return _isEnabled;
    } catch (e) {
      print('Error checking WiFi Direct status: $e');
      return false;
    }
  }
  
  /// Enable WiFi Direct discovery
  static Future<bool> enableDiscovery() async {
    try {
      final result = await _channel.invokeMethod('enableDiscovery');
      return result == true;
    } catch (e) {
      print('Error enabling WiFi Direct discovery: $e');
      return false;
    }
  }
  
  /// Disable WiFi Direct discovery
  static Future<void> disableDiscovery() async {
    try {
      await _channel.invokeMethod('disableDiscovery');
      _peerListener?.cancel();
      _peerListener = null;
    } catch (e) {
      print('Error disabling WiFi Direct discovery: $e');
    }
  }
  
  /// Connect to a WiFi Direct peer
  static Future<bool> connectToPeer(String deviceAddress) async {
    try {
      final result = await _channel.invokeMethod('connectToPeer', {
        'deviceAddress': deviceAddress,
      });
      return result == true;
    } catch (e) {
      print('Error connecting to WiFi Direct peer: $e');
      return false;
    }
  }
  
  /// Disconnect from current WiFi Direct peer
  static Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (e) {
      print('Error disconnecting from WiFi Direct: $e');
    }
  }
  
  /// Get connection info (IP address, group owner status)
  static Future<Map<String, dynamic>?> getConnectionInfo() async {
    try {
      final result = await _channel.invokeMethod('getConnectionInfo');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Error getting WiFi Direct connection info: $e');
      return null;
    }
  }
  
  /// Create WiFi Direct group (act as group owner)
  static Future<bool> createGroup() async {
    try {
      final result = await _channel.invokeMethod('createGroup');
      return result == true;
    } catch (e) {
      print('Error creating WiFi Direct group: $e');
      return false;
    }
  }
  
  /// Remove WiFi Direct group
  static Future<void> removeGroup() async {
    try {
      await _channel.invokeMethod('removeGroup');
    } catch (e) {
      print('Error removing WiFi Direct group: $e');
    }
  }
  
  /// Listen for discovered peers
  static Stream<List<Map<String, dynamic>>> listenForPeers() {
    final controller = StreamController<List<Map<String, dynamic>>>();
    
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPeersAvailable') {
        final peers = List<Map<String, dynamic>>.from(
          call.arguments.map((p) => Map<String, dynamic>.from(p))
        );
        controller.add(peers);
      } else if (call.method == 'onConnectionChanged') {
        // Handle connection state changes
        print('WiFi Direct connection changed: ${call.arguments}');
      }
    });
    
    return controller.stream;
  }
  
  /// Determine if two Android devices should use WiFi Direct
  static bool shouldUseWiFiDirect(String localPlatform, String remotePlatform) {
    return localPlatform == 'android' && remotePlatform == 'android' && _isSupported;
  }
  
  /// Get optimal connection method between devices
  static Future<String> getOptimalConnectionMethod(String remotePlatform) async {
    if (remotePlatform == 'android' && await isSupported() && await isEnabled()) {
      return 'wifi_direct';
    }
    return 'wifi';
  }
}
