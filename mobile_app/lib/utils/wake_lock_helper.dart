import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WakeLockHelper {
  static bool _isEnabled = false;
  
  static Future<void> enable() async {
    if (_isEnabled) return;
    
    try {
      await WakelockPlus.enable();
      _isEnabled = true;
      debugPrint('Wake lock enabled');
    } catch (e) {
      debugPrint('Failed to enable wake lock: $e');
    }
  }
  
  static Future<void> disable() async {
    if (!_isEnabled) return;
    
    try {
      await WakelockPlus.disable();
      _isEnabled = false;
      debugPrint('Wake lock disabled');
    } catch (e) {
      debugPrint('Failed to disable wake lock: $e');
    }
  }
  
  static Future<bool> isEnabled() async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      return false;
    }
  }
  
  static Future<void> toggle(bool enable) async {
    if (enable) {
      await WakeLockHelper.enable();
    } else {
      await WakeLockHelper.disable();
    }
  }
}
