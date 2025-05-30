// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBf2rv_asH86gY2fEGY4yUw4NJYRr5nfnw',
    appId: '1:1023144692222:web:2f91f75b0086b9403018af',
    messagingSenderId: '1023144692222',
    projectId: 'reptigram-lite',
    authDomain: 'reptigram-lite.firebaseapp.com',
    databaseURL: 'https://reptigram-lite-default-rtdb.firebaseio.com',
    storageBucket: 'reptigram-lite.firebasestorage.app',
    measurementId: 'G-CY6CX0VLB0',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCClQxuTqg0T6bdJxLILlO0jqIpugdIP5M',
    appId: '1:1023144692222:android:a57f919ff17d0f9d3018af',
    messagingSenderId: '1023144692222',
    projectId: 'reptigram-lite',
    databaseURL: 'https://reptigram-lite-default-rtdb.firebaseio.com',
    storageBucket: 'reptigram-lite.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCR2PPFi08UObIgUa0yB_aE0tlYYEROS60',
    appId: '1:1023144692222:ios:c62d368a4f5f4b813018af',
    messagingSenderId: '1023144692222',
    projectId: 'reptigram-lite',
    databaseURL: 'https://reptigram-lite-default-rtdb.firebaseio.com',
    storageBucket: 'reptigram-lite.firebasestorage.app',
    iosClientId: '1023144692222-2b1s20qkcegl2ikifrd0mkrtu7jl1eag.apps.googleusercontent.com',
    iosBundleId: 'com.example.reptigramfirestore',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCR2PPFi08UObIgUa0yB_aE0tlYYEROS60',
    appId: '1:1023144692222:ios:c62d368a4f5f4b813018af',
    messagingSenderId: '1023144692222',
    projectId: 'reptigram-lite',
    databaseURL: 'https://reptigram-lite-default-rtdb.firebaseio.com',
    storageBucket: 'reptigram-lite.firebasestorage.app',
    iosClientId: '1023144692222-2b1s20qkcegl2ikifrd0mkrtu7jl1eag.apps.googleusercontent.com',
    iosBundleId: 'com.example.reptigramfirestore',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBf2rv_asH86gY2fEGY4yUw4NJYRr5nfnw',
    appId: '1:1023144692222:web:ec37f6cb1bdda0893018af',
    messagingSenderId: '1023144692222',
    projectId: 'reptigram-lite',
    authDomain: 'reptigram-lite.firebaseapp.com',
    databaseURL: 'https://reptigram-lite-default-rtdb.firebaseio.com',
    storageBucket: 'reptigram-lite.firebasestorage.app',
    measurementId: 'G-8PNH47N5LG',
  );
}
