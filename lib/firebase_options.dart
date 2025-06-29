import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web config
      return const FirebaseOptions(
        apiKey: "AIzaSyBf2rv_asH86gY2fEGY4yUw4NJYRr5nfnw",
        authDomain: "reptigram-lite.firebaseapp.com",
        databaseURL: "https://reptigram-lite-default-rtdb.firebaseio.com",
        projectId: "reptigram-lite",
        storageBucket: "reptigram-lite.firebasestorage.app",
        messagingSenderId: "1023144692222",
        appId: "1:1023144692222:web:a2f83e6788f1e0293018af",
        measurementId: "G-XHBMWC2VD6",
      );
    }
    // You can add Android/iOS config here if needed.
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for this platform.',
    );
  }
} 