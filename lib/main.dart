import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';
import 'state/app_state.dart';
import 'state/auth_state.dart';
import 'state/dark_mode_provider.dart';
import 'audit_firebase_config.dart';
import 'services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // You can handle background messages here if needed
  // print('Handling a background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if Firebase is already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    // Firebase is already initialized, use the existing app
    Firebase.app();
  }

  // 🔍 AUDIT: Verify Firebase configuration on startup
  try {
    FirebaseConfigAuditor.auditFirebaseConfig();
    print('✅ Firebase configuration verified - connected to correct project');
  } catch (e) {
    print('❌ CRITICAL: Firebase configuration error: $e');
    print('🛑 App will continue but may write to wrong project!');
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initFirebaseMessaging();
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request permission
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      print('🔔 Notification permission status: ${permission.authorizationStatus}');
      
      if (permission.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Notification permission granted');
      } else {
        print('❌ Notification permission denied: ${permission.authorizationStatus}');
        return;
      }

      // Get and save FCM token
      final token = await messaging.getToken();
      if (token != null) {
        print('🔑 FCM Token generated: ${token.substring(0, 20)}...');
        
        // Save token to Firestore when user is logged in
        FirebaseAuth.instance.authStateChanges().listen((User? user) async {
          if (user != null) {
            try {
              await FirestoreService.saveFcmToken(user.uid, token);
              print('✅ FCM Token saved to Firestore for user: ${user.uid}');
            } catch (e) {
              print('❌ Error saving FCM token: $e');
            }
          }
        });
      } else {
        print('❌ Failed to get FCM token');
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        print('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await FirestoreService.saveFcmToken(user.uid, newToken);
            print('✅ Refreshed FCM token saved to Firestore');
          } catch (e) {
            print('❌ Error saving refreshed FCM token: $e');
          }
        }
      });

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 Received foreground message: ${message.messageId}');
        final notification = message.notification;
        if (notification != null && _navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text(notification.title != null
                  ? '${notification.title}: ${notification.body ?? ''}'
                  : notification.body ?? 'New message'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  // Navigate to chat if needed
                  final data = message.data;
                  if (data['senderId'] != null) {
                    // Navigate to chat with sender
                    _navigateToChat(data['senderId']!);
                  }
                },
              ),
            ),
          );
        }
      });

      // Handle notification taps when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📱 App opened from notification: ${message.messageId}');
        final data = message.data;
        if (data['senderId'] != null) {
          _navigateToChat(data['senderId']!);
        }
      });

      // Handle notification tap when app is terminated
      RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        print('🚀 App launched from notification: ${initialMessage.messageId}');
        final data = initialMessage.data;
        if (data['senderId'] != null) {
          // Delay navigation to ensure app is fully loaded
          Future.delayed(const Duration(seconds: 1), () {
            _navigateToChat(data['senderId']!);
          });
        }
      }
      
      print('✅ Firebase Messaging initialized successfully');
    } catch (e) {
      print('❌ Error initializing Firebase Messaging: $e');
    }
  }

  void _navigateToChat(String senderId) {
    if (_navigatorKey.currentContext != null) {
      Navigator.of(_navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            peerUid: senderId,
            peerName: 'User', // You can fetch the actual username if needed
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => DarkModeProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ReptiGram',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        navigatorKey: _navigatorKey,
        home: const LoginScreen(),
      ),
    );
  }
} 