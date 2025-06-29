import 'package:firebase_auth/firebase_auth.dart';

class ErrorUtils {
  // Convert Firebase errors to user-friendly messages
  static String getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password';
        case 'email-already-in-use':
          return 'This email is already registered';
        case 'invalid-email':
          return 'Invalid email format';
        case 'weak-password':
          return 'Password is too weak';
        case 'operation-not-allowed':
          return 'Operation not allowed';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later';
        default:
          return error.message ?? 'An unknown error occurred';
      }
    }
    return 'An unexpected error occurred';
  }

  // Get network error message
  static String getNetworkErrorMessage() {
    return 'Network error. Please check your connection and try again.';
  }

  // Get timeout error message
  static String getTimeoutErrorMessage() {
    return 'Request timed out. Please try again.';
  }
} 