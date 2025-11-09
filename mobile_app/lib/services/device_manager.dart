/**
 * Rapid Transfer - Device Manager
 * Copyright (C) 2025 Seth Johnston - Licensed under AGPL-3.0
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';

class DeviceManager extends ChangeNotifier {
  final Map<String, Device> _devices = {};
  String? _localDeviceId;
  String _localDeviceName = '';
  Map<String, String> _deviceAliases = {};
  Set<String> _trustedDevices = {};

  // Settings
  String _streamCount = 'auto';
  String _language = 'en';
  bool _notifications = true;
  bool _keepAwake = true;
  bool _autoConfigureHotspot = true;

  List<Device> get devices => _devices.values.toList();
  String get localDeviceName => _localDeviceName;
  String? getLocalDeviceId() => _localDeviceId;
  String get streamCount => _streamCount;
  String get language => _language;
  bool get notifications => _notifications;
  bool get keepAwake => _keepAwake;
  bool get autoConfigureHotspot => _autoConfigureHotspot;

  Future<void> init() async {
    await _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _localDeviceId = prefs.getString('deviceId');
    if (_localDeviceId == null) {
      _localDeviceId = _generateDeviceId();
      await prefs.setString('deviceId', _localDeviceId!);
    }

    _localDeviceName = prefs.getString('deviceName') ?? 'Android Device';
    _streamCount = prefs.getString('streamCount') ?? 'auto';
    _language = prefs.getString('language') ?? 'en';
    _notifications = prefs.getBool('notifications') ?? true;
    _keepAwake = prefs.getBool('keepAwake') ?? true;
    _autoConfigureHotspot = prefs.getBool('autoConfigureHotspot') ?? true;

    // Load trusted devices
    final trustedList = prefs.getStringList('trustedDevices') ?? [];
    _trustedDevices = trustedList.toSet();

    // Load aliases
    final aliasKeys = prefs.getKeys().where((k) => k.startsWith('alias_'));
    for (final key in aliasKeys) {
      final deviceId = key.substring(6);
      final alias = prefs.getString(key);
      if (alias != null) {
        _deviceAliases[deviceId] = alias;
      }
    }
  }

  String _generateDeviceId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void addDevice(Device device) {
    _devices[device.id] = device.copyWith(
      alias: _deviceAliases[device.id],
      trusted: _trustedDevices.contains(device.id),
    );
    notifyListeners();
  }

  void removeDevice(String deviceId) {
    _devices.remove(deviceId);
    notifyListeners();
  }

  Device? getDevice(String deviceId) {
    return _devices[deviceId];
  }

  Future<void> setDeviceName(String name) async {
    _localDeviceName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceName', name);
    notifyListeners();
  }

  Future<void> trustDevice(String deviceId) async {
    _trustedDevices.add(deviceId);
    final device = _devices[deviceId];
    if (device != null) {
      _devices[deviceId] = device.copyWith(trusted: true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('trustedDevices', _trustedDevices.toList());
    notifyListeners();
  }

  Future<void> forgetDevice(String deviceId) async {
    _trustedDevices.remove(deviceId);
    _deviceAliases.remove(deviceId);
    final device = _devices[deviceId];
    if (device != null) {
      _devices[deviceId] = device.copyWith(trusted: false, alias: null);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('trustedDevices', _trustedDevices.toList());
    await prefs.remove('alias_$deviceId');
    notifyListeners();
  }

  Future<void> setDeviceAlias(String deviceId, String? alias) async {
    final prefs = await SharedPreferences.getInstance();
    if (alias != null && alias.isNotEmpty) {
      _deviceAliases[deviceId] = alias;
      await prefs.setString('alias_$deviceId', alias);
    } else {
      _deviceAliases.remove(deviceId);
      await prefs.remove('alias_$deviceId');
    }
    final device = _devices[deviceId];
    if (device != null) {
      _devices[deviceId] = device.copyWith(alias: alias);
    }
    notifyListeners();
  }

  Future<void> updateSettings({
    String? streamCount,
    String? language,
    bool? notifications,
    bool? keepAwake,
    bool? autoConfigureHotspot,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (streamCount != null) {
      _streamCount = streamCount;
      await prefs.setString('streamCount', streamCount);
    }
    if (language != null) {
      _language = language;
      await prefs.setString('language', language);
    }
    if (notifications != null) {
      _notifications = notifications;
      await prefs.setBool('notifications', notifications);
    }
    if (keepAwake != null) {
      _keepAwake = keepAwake;
      await prefs.setBool('keepAwake', keepAwake);
    }
    if (autoConfigureHotspot != null) {
      _autoConfigureHotspot = autoConfigureHotspot;
      await prefs.setBool('autoConfigureHotspot', autoConfigureHotspot);
    }

    notifyListeners();
  }

  void dispose() {
    super.dispose();
  }
}
