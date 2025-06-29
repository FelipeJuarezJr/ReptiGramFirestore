class AppColors {
  static const Color titleText = Color(0xFF333333);
  static const Color buttonText = Colors.white;
  static const Color dialogBackground = Color(0xFF2C2C2C);
  
  // Add these new colors
  static const Color inputText = Colors.white;
  static const Color hintText = Colors.grey;
  static const Color inputBackground = Color(0xFF2C2C2C);
  
  static const LinearGradient loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E1E1E),
      Color(0xFF3C3C3C),
    ],
  );

  static const LinearGradient inputGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2C2C2C),
      Color(0xFF3C3C3C),
    ],
  );
} 