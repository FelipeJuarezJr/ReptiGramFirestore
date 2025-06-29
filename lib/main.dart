import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';
import 'state/auth_state.dart';
import 'dart:html' as html;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBf2rv_asH86gY2fEGY4yUw4NJYRr5nfnw",
      authDomain: "reptigram-lite.firebaseapp.com",
      projectId: "reptigram-lite",
      storageBucket: "reptigram-lite.firebasestorage.app",
      messagingSenderId: "1023144692222",
      appId: "1:1023144692222:web:a2f83e6788f1e0293018af",
      measurementId: "G-XHBMWC2VD6",
      databaseURL: "https://reptigram-lite-default-rtdb.firebaseio.com"
    ),
  );

  html.document.title = 'ReptiGram - A Social Network for Reptile Enthusiasts';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => AuthState()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ReptiGram',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
} 