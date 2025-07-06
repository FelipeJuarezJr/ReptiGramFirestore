import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _saveOrUpdateUser(credential.user!);
      return credential;
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password, String username) async {
    try {
      // First check if a user with this email already exists in Firestore
      final existingUsers = await _db.collection('users')
          .where('email', isEqualTo: email)
          .get();
      
      if (existingUsers.docs.isNotEmpty) {
        // User with this email already exists, try to sign them in instead
        print('User with email $email already exists, attempting sign in...');
        return await signInWithEmailAndPassword(email, password);
      }

      // Create new user
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      // Update display name
      await credential.user!.updateDisplayName(username);
      
      // Save user data
      await _saveOrUpdateUser(credential.user!);
      
      return credential;
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Use Firebase Auth Google provider for both web and mobile
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      
      // Add scopes if needed
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      
      // Force account selection by setting custom parameters
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
        'access_type': 'offline',
        'include_granted_scopes': 'true',
      });
      
      // Sign in directly with Firebase Auth
      final userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      
      // Save FCM token and user data after successful sign in
      if (userCredential.user != null) {
        await _saveFcmToken(userCredential.user!.uid);
        await _saveOrUpdateUser(userCredential.user!);
      }
      
      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Save or update user data in Firestore
  Future<void> _saveOrUpdateUser(User user) async {
    try {
      // Check if user already exists
      final userDoc = await _db.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        // Create new user
        await _db.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName,
          'username': user.displayName?.toLowerCase().replaceAll(' ', '') ?? 'user',
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
        print('New user created: ${user.uid}');
      } else {
        // Update existing user
        await _db.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        });
        print('Existing user updated: ${user.uid}');
      }
    } catch (e) {
      print('Error saving/updating user: $e');
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user data
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }

  // Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      final users = await _db.collection('users')
          .where('email', isEqualTo: email)
          .get();
      return users.docs.isNotEmpty;
    } catch (e) {
      print('Error checking email registration: $e');
      return false;
    }
  }

  // Get user by email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final users = await _db.collection('users')
          .where('email', isEqualTo: email)
          .get();
      
      if (users.docs.isNotEmpty) {
        final userData = users.docs.first.data();
        userData['uid'] = users.docs.first.id;
        return userData;
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  Future<void> _saveFcmToken(String userId) async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        String? token = await _messaging.getToken();
        
        if (token != null) {
          // Check if user document exists first
          final userDoc = await _db.collection('users').doc(userId).get();
          
          if (userDoc.exists) {
            // Update existing user document
            await _db.collection('users').doc(userId).update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
            print('FCM token saved successfully');
          } else {
            // Create user document if it doesn't exist
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await _db.collection('users').doc(userId).set({
                'email': user.email,
                'displayName': user.displayName,
                'username': user.displayName?.toLowerCase().replaceAll(' ', '') ?? 'user',
                'photoURL': user.photoURL,
                'fcmToken': token,
                'lastTokenUpdate': FieldValue.serverTimestamp(),
                'createdAt': FieldValue.serverTimestamp(),
                'lastLogin': FieldValue.serverTimestamp(),
              });
              print('User document created with FCM token');
            }
          }
        }
      } else {
        print('Notification permission denied');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  Future<void> updateFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _saveFcmToken(user.uid);
    }
  }
} 