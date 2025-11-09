import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceList extends StatelessWidget {
  final List<Device> devices;
  final Set<String> selectedDevices;
  final Function(String, bool) onDeviceSelected;

  const DeviceList({
    super.key,
    required this.devices,
    required this.selectedDevices,
    required this.onDeviceSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Devices on the same network\nwill appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        final isSelected = selectedDevices.contains(device.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 4 : 1,
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: Stack(
              children: [
                Icon(
                  _getPlatformIcon(device.platform),
                  size: 32,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                ),
                if (device.trusted)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              device.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
              ),
            ),
            subtitle: Text(
              '${device.platform} • ${device.trusted ? 'Trusted' : 'Not verified'}',
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                    : null,
              ),
            ),
            trailing: Checkbox(
              value: isSelected,
              onChanged: (value) {
                onDeviceSelected(device.id, value ?? false);
              },
            ),
            onTap: () {
              onDeviceSelected(device.id, !isSelected);
            },
          ),
        );
      },
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.smartphone;
      case 'ios':
        return Icons.phone_iphone;
      case 'darwin':
      case 'macos':
        return Icons.laptop_mac;
      case 'win32':
      case 'windows':
        return Icons.laptop_windows;
      case 'linux':
        return Icons.laptop;
      default:
        return Icons.devices;
    }
  }
}
