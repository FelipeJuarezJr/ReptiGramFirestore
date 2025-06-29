import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import '../services/auth_service.dart';

class GoogleSignInButton extends StatefulWidget {
  final void Function()? onSignedIn;

  const GoogleSignInButton({Key? key, this.onSignedIn}) : super(key: key);

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.g_mobiledata),
      label: const Text('Sign in with Google'),
      onPressed: () async {
        final user = await _authService.signInWithGoogle();
        if (user != null && widget.onSignedIn != null) {
          widget.onSignedIn!();
        }
      },
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.fill;

    // Draw Google Logo paths
    // Red part
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(size.width * 0.5, size.height * 0.198)
      ..lineTo(size.width * 0.692, size.height * 0.273)
      ..lineTo(size.width * 0.834, size.height * 0.131)
      ..arcTo(
        Rect.fromLTWH(0, 0, size.width, size.height),
        -0.4,
        -1.5,
        false,
      )
      ..close();
    canvas.drawPath(redPath, paint);

    // Blue part
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(size.width * 0.979, size.height * 0.511)
      ..lineTo(size.width * 0.75, size.height * 0.511)
      ..lineTo(size.width * 0.75, size.height * 0.699)
      ..lineTo(size.width * 0.911, size.height * 0.849)
      ..arcTo(
        Rect.fromLTWH(0, 0, size.width, size.height),
        0.4,
        -1.5,
        false,
      )
      ..close();
    canvas.drawPath(bluePath, paint);

    // Yellow part
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(size.width * 0.219, size.height * 0.595)
      ..lineTo(size.width * 0.219, size.height * 0.405)
      ..lineTo(size.width * 0.053, size.height * 0.276)
      ..arcTo(
        Rect.fromLTWH(0, 0, size.width, size.height),
        -2.7,
        -1.5,
        false,
      )
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Green part
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.831, size.height * 0.879)
      ..lineTo(size.width * 0.67, size.height * 0.734)
      ..lineTo(size.width * 0.5, size.height * 0.734)
      ..close();
    canvas.drawPath(greenPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 