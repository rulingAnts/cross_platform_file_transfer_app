// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Rapid Transfer';

  @override
  String get availableDevices => 'Available Devices';

  @override
  String get noDevicesFound => 'No devices found';

  @override
  String get devicesWillAppearHere =>
      'Devices on the same network will appear here';

  @override
  String get send => 'Send';

  @override
  String get receive => 'Receive';

  @override
  String get selectFiles => 'Select Files';

  @override
  String get selectPhotos => 'Select Photos';

  @override
  String get transferQueue => 'Transfer Queue';

  @override
  String get noActiveTransfers => 'No active transfers';

  @override
  String get settings => 'Settings';

  @override
  String get deviceName => 'Device Name';

  @override
  String get streamCount => 'Stream Count';

  @override
  String get auto => 'Auto';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get keepAwake => 'Keep Device Awake';

  @override
  String get autoConfigureHotspot => 'Auto-Configure Hotspot';

  @override
  String get verifyConnection => 'Verify Connection';

  @override
  String get verificationMessage =>
      'Make sure this code appears on both devices:';

  @override
  String get accept => 'Accept';

  @override
  String get reject => 'Reject';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get cancel => 'Cancel';

  @override
  String get transferComplete => 'Transfer Complete';

  @override
  String get transferFailed => 'Transfer Failed';

  @override
  String get selectDevice => 'Select a device';

  @override
  String get trusted => 'Trusted';

  @override
  String get notVerified => 'Not verified';
}
