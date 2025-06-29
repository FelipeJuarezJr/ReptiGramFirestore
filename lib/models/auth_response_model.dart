import 'user_model.dart';

class AuthResponse {
  final bool success;
  final String? errorMessage;
  final UserModel? user;

  AuthResponse({
    required this.success,
    this.errorMessage,
    this.user,
  });

  // Check if authentication was successful
  bool get isSuccess => success && user != null;

  // Create success response
  factory AuthResponse.success(UserModel user) {
    return AuthResponse(
      success: true,
      user: user,
    );
  }

  // Create error response
  factory AuthResponse.error(String message) {
    return AuthResponse(
      success: false,
      errorMessage: message,
    );
  }
} 