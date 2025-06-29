import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web config for Firestore project
      return const FirebaseOptions(
        apiKey: "AIzaSyDiT-1kdubTNYLe2waeCIYvGDx5nakKyh0",
        authDomain: "reptigramfirestore.firebaseapp.com",
        projectId: "reptigramfirestore",
        storageBucket: "reptigramfirestore.firebasestorage.app",
        messagingSenderId: "373955522567",
        appId: "1:373955522567:web:7163187c33d378455bbaa2",
        measurementId: "G-H7FDWLXW64",
      );
    }
    // You can add Android/iOS config here if needed.
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for this platform.',
    );
  }
} 