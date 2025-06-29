import 'package:flutter/material.dart';

class AppColors {
  // Original R Primary gradient colors
  // static const Color gradientStart = Color(0xFFffa428); // top left
  // static const Color gradientEnd = Color(0xFF9c3936);   // bottom right
  static const Color gradientStart = Color(0xFFFFDE59); // top left
  static const Color gradientEnd = Color(0xFFFF914D);   // bottom right


  // Text colors
  static const Color logoTitleText = Color(0xFFf6e29b);     // Gold text for title and links
  static const Color titleText = Color(0xFF9c3936);     // Gold text for title and links
  static const Color titleShadow = Color(0xFF4a3414);   // Brown shadow
  static const Color buttonText = Color(0xFFd3d5e4);    // Light gray-blue for button text

  // Input and button gradient colors
  static const Color inputGradientStart = Color(0xFFfbf477);  // Light yellow
  static const Color inputGradientEnd = Color(0xFFfe7e48);    // Orange

  // Login button gradient colors
  static const Color loginGradientStart = Color(0xFFfbf477);  // Yellow
  static const Color loginGradientEnd = Color(0xFF1d3642);    // Dark blue-gray

  // Border radius
  static final BorderRadius pillShape = BorderRadius.circular(25.0);

  // Gradients
  static const Gradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      gradientStart,
      gradientEnd,
      gradientEnd,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Input fields gradient
  static const Gradient inputGradient = LinearGradient(
    begin: Alignment(-2.0, -2.0),
    end: Alignment(1.0, 1.0),
    colors: [
      inputGradientStart,
      inputGradientStart,
      inputGradientEnd,
    ],
    stops: [0.0, 0.4, 1.0],
  );

  // Login button gradient
  static const Gradient loginGradient = LinearGradient(
    begin: Alignment(-2.0, -2.0),
    end: Alignment(2.0, 2.0),
    colors: [
      loginGradientStart,
      loginGradientEnd,
      loginGradientEnd,
    ],
    stops: [0.0, 0.3, 1.0],  // More coverage of the dark color
  );

  // Background gradient
  static const Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      inputGradientStart,
      inputGradientEnd,
      inputGradientEnd,
    ],
    stops: [0.0, 0.4, 1.0],
  );

  // Input decoration theme
  static final InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: Colors.transparent,
    border: OutlineInputBorder(
      borderRadius: pillShape,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: pillShape,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: pillShape,
      borderSide: BorderSide.none,
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: pillShape,
      borderSide: BorderSide.none,
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: pillShape,
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  );

  // Button style with gradient
  static final ButtonStyle pillButtonStyle = ElevatedButton.styleFrom(
    padding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: pillShape,
    ),
    elevation: 0,
  );

  // Shadow decoration for inputs and buttons
  static final List<BoxShadow> innerTopShadow = [
    BoxShadow(
      color: Colors.white.withOpacity(0.45),
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  // Input fields gradient with shadow
  static BoxDecoration inputDecoration = BoxDecoration(
    gradient: inputGradient,
    borderRadius: pillShape,
    boxShadow: innerTopShadow,
  );

  // Login button decoration with shadow
  static BoxDecoration loginButtonDecoration = BoxDecoration(
    gradient: loginGradient,
    borderRadius: pillShape,
    boxShadow: innerTopShadow,
  );

  static const Color dialogBackground = Color(0xFFFFFFFF);
}
