import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
    ],
  );

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Create a new GoogleAuthProvider credential
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        
        // Add scopes if needed
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        // Sign in directly with Firebase Auth
        return await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // Mobile implementation
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }
} 