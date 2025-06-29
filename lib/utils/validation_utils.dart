class ValidationUtils {
  // Email validation
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Password validation
  static bool isValidPassword(String password) {
    return password.length >= 8 &&  // At least 8 characters
           RegExp(r'[A-Z]').hasMatch(password) &&  // At least one uppercase
           RegExp(r'[a-z]').hasMatch(password) &&  // At least one lowercase
           RegExp(r'[0-9]').hasMatch(password);    // At least one number
  }

  // Username validation
  static bool isValidUsername(String username) {
    return username.length >= 3 &&  // At least 3 characters
           username.length <= 20 &&  // Max 20 characters
           RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username);  // Only alphanumeric and underscore
  }

  // Get validation error messages
  static String? getEmailError(String email) {
    if (email.isEmpty) return 'Email is required';
    if (!isValidEmail(email)) return 'Invalid email format';
    return null;
  }

  static String? getPasswordError(String password) {
    if (password.isEmpty) return 'Password is required';
    if (!isValidPassword(password)) {
      return 'Password must have 8+ characters, uppercase, lowercase, and number';
    }
    return null;
  }

  static String? getUsernameError(String username) {
    if (username.isEmpty) return 'Username is required';
    if (!isValidUsername(username)) {
      return 'Username must be 3-20 characters, alphanumeric and underscore only';
    }
    return null;
  }
} 