import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/device_manager.dart';
import 'services/transfer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final deviceManager = DeviceManager();
  await deviceManager.init();
  
  final transferService = TransferService(deviceManager);
  await transferService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: deviceManager),
        ChangeNotifierProvider.value(value: transferService),
      ],
      child: const RapidTransferApp(),
    ),
  );
}

class RapidTransferApp extends StatelessWidget {
  const RapidTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rapid Transfer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D5BFF)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('id', ''), // Indonesian
      ],
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
