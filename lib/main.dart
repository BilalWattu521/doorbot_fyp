import 'package:doorbot_fyp/viewmodels/auth_view_model.dart';
import 'package:doorbot_fyp/views/login_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:adaptive_theme/adaptive_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final savedThemeMode = await AdaptiveTheme.getThemeMode();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthViewModel())],
      child: AdaptiveTheme(
        light: ThemeData.light().copyWith(
          primaryColor: Colors.blue,
          colorScheme: const ColorScheme.light(primary: Colors.blue),
        ),
        dark: ThemeData.dark().copyWith(
          primaryColor: Colors.blue,
          colorScheme: const ColorScheme.dark(primary: Colors.blue),
        ),
        initial: savedThemeMode ?? AdaptiveThemeMode.light,
        builder: (theme, darkTheme) =>
            MyApp(theme: theme, darkTheme: darkTheme),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final ThemeData theme;
  final ThemeData darkTheme;

  const MyApp({super.key, required this.theme, required this.darkTheme});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _firebaseReady = false;

  @override
  void initState() {
    super.initState();

    // Run Firebase init in a microtask
    Future.microtask(() async {
      try {
        await Firebase.initializeApp();
        debugPrint("✅ Firebase initialized in background");
        if (mounted) {
          setState(() {
            _firebaseReady = true;
          });
        }
      } catch (e) {
        debugPrint("❌ Firebase init failed: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: widget.theme,
      darkTheme: widget.darkTheme,
      home: _firebaseReady ? const LoginView() : const SplashScreen(),
    );
  }
}

/// Custom Splash Screen with centered logo
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 120,
          height: 120,
          child: Image(
            image: AssetImage('assets/logo.png'),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
