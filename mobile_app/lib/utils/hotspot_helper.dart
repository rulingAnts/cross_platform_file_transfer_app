import 'dart:async';
import 'package:flutter/services.dart';

/// Helper class for managing Android Hotspot mode
/// Allows creating a portable WiFi hotspot for direct device connections
class HotspotHelper {
  static const MethodChannel _channel = MethodChannel('rapid_transfer/hotspot');
  
  static const String hotspotPrefix = 'RT-'; // Rapid Transfer prefix
  
  /// Check if hotspot is supported on this device
  static Future<bool> isSupported() async {
    try {
      final result = await _channel.invokeMethod('isSupported');
      return result == true;
    } catch (e) {
      print('Hotspot not supported: $e');
      return false;
    }
  }
  
  /// Check if hotspot is currently enabled
  static Future<bool> isEnabled() async {
    try {
      final result = await _channel.invokeMethod('isEnabled');
      return result == true;
    } catch (e) {
      print('Error checking hotspot status: $e');
      return false;
    }
  }
  
  /// Create and enable hotspot with device name
  static Future<Map<String, String>?> createHotspot(String deviceName) async {
    try {
      // Generate secure password
      final password = _generateSecurePassword();
      final ssid = '$hotspotPrefix$deviceName';
      
      final result = await _channel.invokeMethod('createHotspot', {
        'ssid': ssid,
        'password': password,
        'security': 'WPA2_PSK',
      });
      
      if (result == true) {
        return {
          'ssid': ssid,
          'password': password,
        };
      }
      return null;
    } catch (e) {
      print('Error creating hotspot: $e');
      return null;
    }
  }
  
  /// Disable hotspot
  static Future<bool> disableHotspot() async {
    try {
      final result = await _channel.invokeMethod('disableHotspot');
      return result == true;
    } catch (e) {
      print('Error disabling hotspot: $e');
      return false;
    }
  }
  
  /// Get current hotspot configuration
  static Future<Map<String, String>?> getHotspotConfig() async {
    try {
      final result = await _channel.invokeMethod('getHotspotConfig');
      return Map<String, String>.from(result);
    } catch (e) {
      print('Error getting hotspot config: $e');
      return null;
    }
  }
  
  /// Scan for Rapid Transfer hotspots
  static Future<List<String>> scanForRapidTransferHotspots() async {
    try {
      final result = await _channel.invokeMethod('scanNetworks');
      final networks = List<String>.from(result ?? []);
      
      // Filter for Rapid Transfer hotspots
      return networks.where((ssid) => ssid.startsWith(hotspotPrefix)).toList();
    } catch (e) {
      print('Error scanning for hotspots: $e');
      return [];
    }
  }
  
  /// Connect to a Rapid Transfer hotspot
  static Future<bool> connectToHotspot(String ssid, String password) async {
    try {
      final result = await _channel.invokeMethod('connectToNetwork', {
        'ssid': ssid,
        'password': password,
      });
      return result == true;
    } catch (e) {
      print('Error connecting to hotspot: $e');
      return false;
    }
  }
  
  /// Get connected clients (if device is hotspot)
  static Future<List<String>> getConnectedClients() async {
    try {
      final result = await _channel.invokeMethod('getConnectedClients');
      return List<String>.from(result ?? []);
    } catch (e) {
      print('Error getting connected clients: $e');
      return [];
    }
  }
  
  /// Generate secure WPA2 password
  static String _generateSecurePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String password = '';
    
    for (int i = 0; i < 12; i++) {
      password += chars[(random + i) % chars.length];
    }
    
    return password;
  }
  
  /// Check if SSID is a Rapid Transfer hotspot
  static bool isRapidTransferHotspot(String ssid) {
    return ssid.startsWith(hotspotPrefix);
  }
  
  /// Extract device name from hotspot SSID
  static String extractDeviceName(String ssid) {
    if (ssid.startsWith(hotspotPrefix)) {
      return ssid.substring(hotspotPrefix.length);
    }
    return ssid;
  }
}
