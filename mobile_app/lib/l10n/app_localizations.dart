import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Rapid Transfer'**
  String get appTitle;

  /// Header for list of available devices
  ///
  /// In en, this message translates to:
  /// **'Available Devices'**
  String get availableDevices;

  /// Message when no devices are discovered
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get noDevicesFound;

  /// Hint message for device discovery
  ///
  /// In en, this message translates to:
  /// **'Devices on the same network will appear here'**
  String get devicesWillAppearHere;

  /// Button to send files
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Button to receive files
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// Button to select files
  ///
  /// In en, this message translates to:
  /// **'Select Files'**
  String get selectFiles;

  /// Button to select photos
  ///
  /// In en, this message translates to:
  /// **'Select Photos'**
  String get selectPhotos;

  /// Header for transfer queue
  ///
  /// In en, this message translates to:
  /// **'Transfer Queue'**
  String get transferQueue;

  /// Message when no transfers are active
  ///
  /// In en, this message translates to:
  /// **'No active transfers'**
  String get noActiveTransfers;

  /// Settings menu item
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Label for device name setting
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceName;

  /// Label for stream count setting
  ///
  /// In en, this message translates to:
  /// **'Stream Count'**
  String get streamCount;

  /// Auto option for stream count
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// Label for language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Label for notifications setting
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Label for keep awake setting
  ///
  /// In en, this message translates to:
  /// **'Keep Device Awake'**
  String get keepAwake;

  /// Label for hotspot setting
  ///
  /// In en, this message translates to:
  /// **'Auto-Configure Hotspot'**
  String get autoConfigureHotspot;

  /// Title for verification dialog
  ///
  /// In en, this message translates to:
  /// **'Verify Connection'**
  String get verifyConnection;

  /// Message in verification dialog
  ///
  /// In en, this message translates to:
  /// **'Make sure this code appears on both devices:'**
  String get verificationMessage;

  /// Button to accept verification
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// Button to reject verification
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Button to pause transfer
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Button to resume transfer
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// Button to cancel transfer
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Notification title for completed transfer
  ///
  /// In en, this message translates to:
  /// **'Transfer Complete'**
  String get transferComplete;

  /// Notification title for failed transfer
  ///
  /// In en, this message translates to:
  /// **'Transfer Failed'**
  String get transferFailed;

  /// Prompt to select device
  ///
  /// In en, this message translates to:
  /// **'Select a device'**
  String get selectDevice;

  /// Label for trusted device
  ///
  /// In en, this message translates to:
  /// **'Trusted'**
  String get trusted;

  /// Label for unverified device
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get notVerified;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
