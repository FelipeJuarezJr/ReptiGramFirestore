import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/auth_response_model.dart';
import '../utils/error_utils.dart';
import '../services/firestore_service.dart';

class AuthState extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  AuthState() {
    // Initialize auth state
    _initAuthState();
  }

  void _initAuthState() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // Load user data from Firestore
        await _loadUserData(user.uid);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final user = await FirestoreService.getUser(uid);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Sign in with email
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update last login
        await FirestoreService.updateLastLogin(credential.user!.uid);

        await _loadUserData(credential.user!.uid);
        return AuthResponse.success(_currentUser!);
      }

      throw Exception('Failed to sign in');
    } catch (e) {
      final errorMessage = ErrorUtils.getAuthErrorMessage(e);
      _setError(errorMessage);
      return AuthResponse.error(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Register with email
  Future<AuthResponse> registerWithEmail(String email, String password, String username) async {
    try {
      _setLoading(true);
      _clearError();

      // Check if username is available
      final isAvailable = await FirestoreService.isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username already taken');
      }

      // Create auth account
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user data
        final userData = UserModel(
          uid: credential.user!.uid,
          email: email,
          username: username,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        );

        // Save user data and reserve username using batch operation
        await FirestoreService.batchCreateUserAndReserveUsername(userData);

        _currentUser = userData;
        notifyListeners();
        return AuthResponse.success(userData);
      }

      throw Exception('Failed to create account');
    } catch (e) {
      final errorMessage = ErrorUtils.getAuthErrorMessage(e);
      _setError(errorMessage);
      return AuthResponse.error(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _setError(ErrorUtils.getAuthErrorMessage(e));
    }
  }

  // Update user data
  Future<void> updateUserData(Map<String, dynamic> updates) async {
    try {
      if (_currentUser == null) return;

      await FirestoreService.updateUser(_currentUser!.uid, updates);
      await _loadUserData(_currentUser!.uid);
    } catch (e) {
      _setError(ErrorUtils.getAuthErrorMessage(e));
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
} 