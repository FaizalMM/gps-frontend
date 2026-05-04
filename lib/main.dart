import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart'; // ← TAMBAH INI
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'utils/app_theme.dart';

// Global navigator key agar bisa navigasi dari luar widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null); // ← TAMBAH INI
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MobitraApp());
}

class MobitraApp extends StatelessWidget {
  const MobitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Mobitra',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        // SplashScreen hanya ditampilkan sekali saat cold start.
        navigatorKey: navigatorKey,
        home: const SplashScreen(),
      ),
    );
  }
}
