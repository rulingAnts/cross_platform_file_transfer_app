/**
 * Rapid Transfer - Discovery Service (UDP Broadcast)
 * Copyright (C) 2025 Seth Johnston - Licensed under AGPL-3.0
 */

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import 'device_manager.dart';

const int discoveryPort = 8766;
const Duration broadcastInterval = Duration(seconds: 5);
const Duration deviceTimeout = Duration(seconds: 30);

class DiscoveryService {
  final DeviceManager deviceManager;
  final int port;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  bool _isRunning = false;
  final Map<String, DateTime> _discoveredDevices = {};

  DiscoveryService({
    required this.deviceManager,
    this.port = discoveryPort,
  });

  Future<void> start() async {
    if (_isRunning) return;

    try {
      // Create UDP socket
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _socket!.broadcastEnabled = true;

      debugPrint('UDP Discovery listening on port $port');

      // Listen for incoming messages
      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleMessage(datagram);
          }
        }
      });

      // Start broadcasting our presence
      _startBroadcasting();

      // Start cleanup timer
      _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _cleanupStaleDevices();
      });

      _isRunning = true;
      debugPrint('UDP Discovery service started');
    } catch (e) {
      debugPrint('Failed to start discovery service: $e');
      rethrow;
    }
  }

  void _startBroadcasting() {
    void broadcast() {
      final message = _createBroadcastMessage();
      final broadcastAddresses = _getBroadcastAddresses();

      for (final address in broadcastAddresses) {
        try {
          _socket?.send(
            message,
            InternetAddress(address),
            port,
          );
        } catch (e) {
          debugPrint('Failed to send broadcast to $address: $e');
        }
      }
    }

    // Broadcast immediately and then periodically
    broadcast();
    _broadcastTimer = Timer.periodic(broadcastInterval, (_) => broadcast());
  }

  List<int> _createBroadcastMessage() {
    final deviceInfo = {
      'id': deviceManager.getLocalDeviceId() ?? 'unknown',
      'name': deviceManager.localDeviceName,
      'platform': Platform.operatingSystem,
      'version': '0.1.0',
      'port': 8765,
    };
    return utf8.encode(json.encode(deviceInfo));
  }

  List<String> _getBroadcastAddresses() {
    final addresses = <String>[];

    try {
      // Get network interfaces synchronously is not available in Dart
      // We'll use the simpler approach with common broadcast addresses
      
      // For Android/iOS, using the subnet broadcast addresses
      // We can attempt to calculate based on common network configurations
      
      // Add common private network broadcast addresses
      addresses.add('192.168.1.255');   // Common home network
      addresses.add('192.168.0.255');   // Common home network
      addresses.add('10.0.2.255');      // Android emulator network
      addresses.add('172.16.0.255');    // Common private network
      
    } catch (e) {
      debugPrint('Failed to get broadcast addresses: $e');
    }

    // Always include global broadcast as fallback
    addresses.add('255.255.255.255');

    return addresses;
  }

  void _handleMessage(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final data = json.decode(message) as Map<String, dynamic>;

      // Validate message format
      if (!data.containsKey('id') ||
          !data.containsKey('name') ||
          !data.containsKey('port')) {
        return;
      }

      final deviceId = data['id'] as String;

      // Don't add ourselves
      if (deviceId == deviceManager.getLocalDeviceId()) {
        return;
      }

      // Update last seen time
      _discoveredDevices[deviceId] = DateTime.now();

      // Create device object
      final device = Device(
        id: deviceId,
        name: data['name'] as String,
        address: datagram.address.address,
        port: data['port'] as int,
        platform: data['platform'] as String? ?? 'unknown',
        version: data['version'] as String? ?? '0.0.0',
      );

      // Add or update device
      deviceManager.addDevice(device);
    } catch (e) {
      // Ignore malformed messages
      debugPrint('Failed to parse broadcast message: ${e.toString()}');
    }
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    final staleDevices = <String>[];

    _discoveredDevices.forEach((deviceId, lastSeen) {
      if (now.difference(lastSeen) > deviceTimeout) {
        staleDevices.add(deviceId);
      }
    });

    for (final deviceId in staleDevices) {
      _discoveredDevices.remove(deviceId);
      deviceManager.removeDevice(deviceId);
      debugPrint('Device timed out: $deviceId');
    }
  }

  Future<void> updateServiceName(String name) async {
    // Name will be updated on next broadcast automatically
    // No action needed - broadcast timer will pick up new name
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      _broadcastTimer?.cancel();
      _broadcastTimer = null;

      _cleanupTimer?.cancel();
      _cleanupTimer = null;

      _socket?.close();
      _socket = null;

      _discoveredDevices.clear();

      _isRunning = false;
      debugPrint('UDP Discovery service stopped');
    } catch (e) {
      debugPrint('Error stopping discovery service: $e');
    }
  }
}
