import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_manager.dart';
import '../services/transfer_service.dart';
import '../widgets/device_list.dart';
import '../widgets/transfer_queue.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _selectedDevices = {};

  @override
  Widget build(BuildContext context) {
    final deviceManager = Provider.of<DeviceManager>(context);
    final transferService = Provider.of<TransferService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapid Transfer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Device name banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.phone_android,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Text(
                  deviceManager.localDeviceName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Available Devices section
                  Text(
                    'Available Devices',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 2,
                    child: DeviceList(
                      devices: deviceManager.devices,
                      selectedDevices: _selectedDevices,
                      onDeviceSelected: (deviceId, selected) {
                        setState(() {
                          if (selected) {
                            _selectedDevices.add(deviceId);
                          } else {
                            _selectedDevices.remove(deviceId);
                          }
                        });
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Transfer Queue section
                  Text(
                    'Transfer Queue',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 3,
                    child: TransferQueue(
                      transfers: transferService.transfers,
                      onPause: (transferId) =>
                          transferService.pauseTransfer(transferId),
                      onResume: (transferId) =>
                          transferService.resumeTransfer(transferId),
                      onCancel: (transferId) =>
                          transferService.cancelTransfer(transferId),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedDevices.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _selectAndSendFiles(context),
              icon: const Icon(Icons.send),
              label: const Text('Send Files'),
            ),
    );
  }

  Future<void> _selectAndSendFiles(BuildContext context) async {
    // TODO: Implement file picker
    // For now, just show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Selected ${_selectedDevices.length} device(s). File picker to be implemented.',
        ),
      ),
    );
  }
}
