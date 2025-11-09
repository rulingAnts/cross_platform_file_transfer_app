import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';

class BatteryMonitor {
  static final Battery _battery = Battery();
  
  static Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      debugPrint('Failed to get battery level: $e');
      return 100; // Default to full battery if check fails
    }
  }
  
  static Future<BatteryState> getBatteryState() async {
    try {
      return await _battery.batteryState;
    } catch (e) {
      debugPrint('Failed to get battery state: $e');
      return BatteryState.unknown;
    }
  }
  
  static Future<bool> isCharging() async {
    final state = await getBatteryState();
    return state == BatteryState.charging || state == BatteryState.full;
  }
  
  static Future<bool> shouldWarnLowBattery() async {
    final level = await getBatteryLevel();
    final charging = await isCharging();
    
    // Warn if battery < 20% and not charging
    return level < 20 && !charging;
  }
  
  static String getBatteryLevelText(int level) {
    if (level >= 80) return 'Good ($level%)';
    if (level >= 50) return 'Fair ($level%)';
    if (level >= 20) return 'Low ($level%)';
    return 'Very Low ($level%)';
  }
  
  static Stream<BatteryState> getBatteryStateStream() {
    return _battery.onBatteryStateChanged;
  }
}
