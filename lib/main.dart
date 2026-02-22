import 'package:doorbot_fyp/services/door_control_service.dart';
import 'package:doorbot_fyp/services/history_service.dart';
import 'package:doorbot_fyp/services/notification_service.dart';
import 'package:doorbot_fyp/viewmodels/auth_view_model.dart';
import 'package:doorbot_fyp/viewmodels/home_view_model.dart';
import 'package:doorbot_fyp/views/login_view.dart';
import 'package:doorbot_fyp/views/home_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Display notification
  await notificationService.showRemoteMessageNotification(message);
}

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
    Future.microtask(() async {
      try {
        await Firebase.initializeApp();
        debugPrint("✅ Firebase initialized in background");

        await NotificationService().initialize();

        // FCM and doorbell setup are non-critical — app should load even if they fail
        try {
          await _setupFirebaseMessaging();
        } catch (e) {
          debugPrint("⚠️ FCM setup failed (app will still work): $e");
        }

        try {
          await _setupDoorbellListener();
        } catch (e) {
          debugPrint("⚠️ Doorbell listener setup failed: $e");
        }

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

  Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // Request user permission for notifications
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('✅ User granted provisional notification permission');
    } else {
      debugPrint('❌ User declined notification permission');
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
        NotificationService().showRemoteMessageNotification(message);
      }
    });

    // Handle notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      // Navigate to relevant page when notification is tapped
    });

    // Get FCM token for sending notifications
    final token = await messaging.getToken();
    debugPrint('🔑 FCM Token: $token');
  }

  DateTime? _lastHandledEventTime;
  StreamSubscription? _doorbellSubscription;

  Future<void> _setupDoorbellListener() async {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _saveFCMToken(user.uid);
        _listenToDoorbellEvents();
      } else {
        _doorbellSubscription?.cancel();
      }
    });
  }

  void _listenToDoorbellEvents() {
    _doorbellSubscription?.cancel();
    _doorbellSubscription = DoorControlService().getDoorbellEventStream().listen((
      eventTime,
    ) {
      if (eventTime == null) return;

      // If this is the first time we see data, initialize the timestamp
      if (_lastHandledEventTime == null) {
        _lastHandledEventTime = eventTime;

        // Still save to history if this event is recent (within last 30 seconds)
        final age = DateTime.now().difference(eventTime);
        if (age.inSeconds < 30) {
          debugPrint("🔔 Fresh doorbell event on init — saving to history");
          HistoryService().saveEvent('doorbell');
        }
        return;
      }

      // Track the latest event
      final difference = eventTime.difference(_lastHandledEventTime!);

      if (difference.inMilliseconds > 0) {
        _lastHandledEventTime = eventTime;
        debugPrint("🔔 Doorbell Ring Detected! Time: $eventTime");
        // Save to history
        HistoryService().saveEvent('doorbell');
        // NOTE: No local notification here!
        // Render server listens to RTDB and sends FCM push which handles foreground + background + terminated.
      }
    });
  }

  Future<void> _saveFCMToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint("🔑 Saving FCM Token for user $uid");
        await FirebaseDatabase.instance.ref('users/$uid/fcm_token').set(token);

        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          FirebaseDatabase.instance.ref('users/$uid/fcm_token').set(newToken);
        });
      }
    } catch (e) {
      debugPrint("❌ Error saving FCM token: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: widget.theme,
      darkTheme: widget.darkTheme,
      home: _firebaseReady ? const AuthWrapper() : const SplashScreen(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  bool _isLoading = true;
  HomeViewModel? _homeViewModel;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _isLoading = false;
    if (_user != null) {
      _homeViewModel = HomeViewModel();
    }
    _startAuthListener();
  }

  void _startAuthListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) {
        debugPrint("🔐 AuthWrapper: Auth State Changed. User: ${user?.uid}");
        if (mounted) {
          // Only create/dispose HomeViewModel when login state actually changes
          if (user != null && _user == null) {
            _homeViewModel = HomeViewModel();
          } else if (user == null && _user != null) {
            _homeViewModel?.dispose();
            _homeViewModel = null;
          }
          setState(() {
            _user = user;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint("❌ AuthWrapper: Auth Stream Error: $error");
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _homeViewModel?.dispose();
    _homeViewModel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user != null && _homeViewModel != null) {
      debugPrint("🔐 AuthWrapper: Showing HomeView for ${_user!.email}");
      return ChangeNotifierProvider<HomeViewModel>.value(
        value: _homeViewModel!,
        child: const HomeView(),
      );
    }

    debugPrint("🔐 AuthWrapper: Showing LoginView");
    return const LoginView();
  }
}

/// Custom Splash Screen with centered logo
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: const SizedBox(
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
