import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }
  
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
  
  static Future<bool> requestLocationPermission() async {
    // Required for WiFi Direct and hotspot features
    final status = await Permission.location.request();
    return status.isGranted;
  }
  
  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    // Storage permission (for Android < 13)
    if (!await Permission.storage.isGranted) {
      final granted = await requestStoragePermission();
      if (!granted && context.mounted) {
        _showPermissionDialog(
          context,
          'Storage Permission',
          'Storage permission is required to access files for transfer.',
        );
        return false;
      }
    }
    
    // Photos permission (for Android >= 13)
    if (!await Permission.photos.isGranted) {
      final status = await Permission.photos.request();
      if (!status.isGranted && context.mounted) {
        _showPermissionDialog(
          context,
          'Photos Permission',
          'Photos permission is required to access images for transfer.',
        );
      }
    }
    
    return true;
  }
  
  static void _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }
  
  static Future<bool> hasAllRequiredPermissions() async {
    final storage = await Permission.storage.isGranted;
    final photos = await Permission.photos.isGranted;
    
    // At least one of storage or photos should be granted
    return storage || photos;
  }
}
