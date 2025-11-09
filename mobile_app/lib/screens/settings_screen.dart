import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/device_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _deviceNameController;
  late String _streamCount;
  late String _language;
  late bool _notifications;
  late bool _keepAwake;
  late bool _autoConfigureHotspot;

  @override
  void initState() {
    super.initState();
    final deviceManager = Provider.of<DeviceManager>(context, listen: false);
    _deviceNameController = TextEditingController(
      text: deviceManager.localDeviceName,
    );
    _streamCount = deviceManager.streamCount;
    _language = deviceManager.language;
    _notifications = deviceManager.notifications;
    _keepAwake = deviceManager.keepAwake;
    _autoConfigureHotspot = deviceManager.autoConfigureHotspot;
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device Name
          TextField(
            controller: _deviceNameController,
            decoration: const InputDecoration(
              labelText: 'Device Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // Stream Count
          DropdownButtonFormField<String>(
            initialValue: _streamCount,
            decoration: const InputDecoration(
              labelText: 'Stream Count',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto')),
              DropdownMenuItem(value: '1', child: Text('1')),
              DropdownMenuItem(value: '2', child: Text('2')),
              DropdownMenuItem(value: '4', child: Text('4')),
              DropdownMenuItem(value: '6', child: Text('6')),
              DropdownMenuItem(value: '8', child: Text('8')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _streamCount = value);
              }
            },
          ),
          const SizedBox(height: 20),

          // Language
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: const InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'id', child: Text('Bahasa Indonesia')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _language = value);
              }
            },
          ),
          const SizedBox(height: 20),

          // Notifications
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Show transfer completion notifications'),
            value: _notifications,
            onChanged: (value) {
              setState(() => _notifications = value);
            },
          ),

          // Keep Awake
          SwitchListTile(
            title: const Text('Keep Device Awake'),
            subtitle: const Text(
              'Prevent device from sleeping during transfers',
            ),
            value: _keepAwake,
            onChanged: (value) {
              setState(() => _keepAwake = value);
            },
          ),

          // Auto-configure Hotspot
          SwitchListTile(
            title: const Text('Auto-Configure Hotspot'),
            subtitle: const Text('Automatically set up hotspot for transfers'),
            value: _autoConfigureHotspot,
            onChanged: (value) {
              setState(() => _autoConfigureHotspot = value);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final deviceManager = Provider.of<DeviceManager>(context, listen: false);

    await deviceManager.setDeviceName(_deviceNameController.text);
    await deviceManager.updateSettings(
      streamCount: _streamCount,
      language: _language,
      notifications: _notifications,
      keepAwake: _keepAwake,
      autoConfigureHotspot: _autoConfigureHotspot,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }
}
