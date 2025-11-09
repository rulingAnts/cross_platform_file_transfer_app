# Rapid Transfer Mobile App

Android mobile application for rapid file transfer over local networks.

## Features

- **Zero-config device discovery** using NSD (Network Service Discovery)
- **Multi-stream parallel transfers** for maximum speed
- **TLS encryption** for secure transfers
- **Device pairing** with verification codes
- **Share intent** support - send files from any app
- **File picker** and gallery picker integration
- **Resume capability** for interrupted transfers
- **Hotspot mode** for direct device-to-device transfers
- **WiFi Direct** support for Android-to-Android transfers
- **Bilingual** support (English and Indonesian)

## Development

### Prerequisites

- Flutter 3.9.2 or higher
- Android SDK
- JDK 17 (avoid JDK 21 due to Gradle compatibility issues)

### Setup

```bash
cd mobile_app
flutter pub get
```

### Running

```bash
flutter run
```

### Building

Build APK:
```bash
flutter build apk --release
```

Build App Bundle:
```bash
flutter build appbundle --release
```

Or use the provided scripts:
```bash
../scripts/build_apk.sh
../scripts/build_aab.sh
```

## Architecture

- **Models**: Data classes for Device and FileTransfer
- **Services**:
  - `device_manager.dart`: Device discovery and management
  - `transfer_service.dart`: File transfer orchestration
- **Screens**:
  - `home_screen.dart`: Main UI with device list and transfer queue
  - `settings_screen.dart`: App settings
- **Widgets**:
  - `device_list.dart`: Displays available devices
  - `transfer_queue.dart`: Shows active transfers with progress

## Localization

The app supports English and Indonesian (Bahasa Indonesia). Translation files are in `lib/l10n/`:
- `app_en.arb`: English translations
- `app_id.arb`: Indonesian translations

The Indonesian translations are designed to be accessible to users in Papua with limited formal education, using simple and commonly understood words.

## Permissions

The app requires the following permissions:
- **Storage**: To access files for transfer
- **Notifications**: To show transfer completion alerts
- **Location** (Android 10+): Required for WiFi Direct and hotspot features
- **WiFi State**: To manage network connections

Permissions are requested on-demand when features are used.

## Configuration

User settings are stored using SharedPreferences and include:
- Device ID and name
- Trusted devices
- Device aliases
- Stream count
- Language preference
- Notification settings
- Keep awake setting
- Hotspot auto-configuration

## Security

- All transfers use TLS encryption
- Device verification with random codes
- Certificate pinning after first pairing
- No passwords stored

## License

MIT
