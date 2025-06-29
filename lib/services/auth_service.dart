import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Use Firebase Auth Google provider for both web and mobile
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      
      // Add scopes if needed
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      
      // Sign in directly with Firebase Auth
      return await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }
} 