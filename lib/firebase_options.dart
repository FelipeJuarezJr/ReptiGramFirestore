import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web config for Firestore project
      return const FirebaseOptions(
        apiKey: "AIzaSyBevZO-43EmlnYOhTWg_xT6UcwrmVAkSsc",
        authDomain: "reptigramfirestore.firebaseapp.com",
        projectId: "reptigramfirestore",
        storageBucket: "reptigramfirestore.firebasestorage.app",
        messagingSenderId: "373955522567",
        appId: "1:373955522567:android:b4650d05f0f8b4295bbaa2",
        measurementId: "G-XHBMWC2VD6",
        databaseURL: "https://reptigramfirestore-default-rtdb.firebaseio.com"
      );
    }
    // You can add Android/iOS config here if needed.
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for this platform.',
    );
  }
} 