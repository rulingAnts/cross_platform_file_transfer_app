import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart';
import '../models/device.dart';
import 'device_manager.dart';

class DiscoveryService {
  final DeviceManager deviceManager;
  final String serviceType = '_rapidtransfer._tcp';

  Discovery? _discovery;
  Registration? _registration;
  bool _isRunning = false;

  DiscoveryService(this.deviceManager);

  Future<void> start() async {
    if (_isRunning) return;

    try {
      // Register our service
      await _registerService();

      // Start discovering other services
      await _startDiscovery();

      _isRunning = true;
      debugPrint('Discovery service started');
    } catch (e) {
      debugPrint('Failed to start discovery service: $e');
      rethrow;
    }
  }

  Future<void> _registerService() async {
    try {
      final service = Service(
        name: deviceManager.localDeviceName,
        type: serviceType,
        port: 8765,
        txt: {
          'id': Uint8List.fromList(
            utf8.encode(deviceManager.getLocalDeviceId() ?? 'unknown'),
          ),
          'version': Uint8List.fromList(utf8.encode('0.1.0')),
          'platform': Uint8List.fromList(utf8.encode(Platform.operatingSystem)),
        },
      );

      _registration = await register(service);
      debugPrint('Service registered: ${deviceManager.localDeviceName}');
    } catch (e) {
      debugPrint('Service registration failed: $e');
    }
  }

  Future<void> _startDiscovery() async {
    try {
      _discovery = await startDiscovery(
        serviceType,
        ipLookupType: IpLookupType.any,
      );

      _discovery!.addServiceListener((service, status) {
        switch (status) {
          case ServiceStatus.found:
            _handleServiceFound(service);
            break;
          case ServiceStatus.lost:
            _handleServiceLost(service);
            break;
        }
      });

      debugPrint('Discovery started for type: $serviceType');
    } catch (e) {
      debugPrint('Discovery failed: $e');
    }
  }

  void _handleServiceFound(Service service) {
    // Resolve service to get full details
    resolve(service)
        .then((resolved) {
          final deviceIdBytes = resolved.txt?['id'];
          final platformBytes = resolved.txt?['platform'];
          final versionBytes = resolved.txt?['version'];

          final deviceId = deviceIdBytes != null
              ? utf8.decode(deviceIdBytes)
              : (resolved.name ?? 'unknown');

          // Don't add ourselves
          if (deviceId == deviceManager.getLocalDeviceId()) {
            return;
          }

          final device = Device(
            id: deviceId,
            name: resolved.name ?? 'Unknown Device',
            address: resolved.host ?? '',
            port: resolved.port ?? 8765,
            platform: platformBytes != null
                ? utf8.decode(platformBytes)
                : 'unknown',
            version: versionBytes != null ? utf8.decode(versionBytes) : '0.0.0',
          );

          debugPrint('Device discovered: ${device.name} at ${device.address}');
          deviceManager.addDevice(device);
        })
        .catchError((e) {
          debugPrint('Failed to resolve service: $e');
        });
  }

  void _handleServiceLost(Service service) {
    final deviceIdBytes = service.txt?['id'];
    final deviceId = deviceIdBytes != null
        ? utf8.decode(deviceIdBytes)
        : (service.name ?? 'unknown');
    debugPrint('Device lost: $deviceId');
    deviceManager.removeDevice(deviceId);
  }

  Future<void> updateServiceName(String name) async {
    if (_registration != null) {
      // Cancel the registration
      _registration = null;
      await _registerService();
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      if (_discovery != null) {
        await stopDiscovery(_discovery!);
        _discovery = null;
      }

      if (_registration != null) {
        // Cancel the registration
        _registration = null;
      }

      _isRunning = false;
      debugPrint('Discovery service stopped');
    } catch (e) {
      debugPrint('Error stopping discovery service: $e');
    }
  }
}
