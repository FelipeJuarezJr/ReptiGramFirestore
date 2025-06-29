import 'package:flutter/material.dart';
import '../styles/colors.dart';

class Footer extends StatelessWidget {
  final String text;
  final String buttonText;
  final VoidCallback onPressed;

  const Footer({
    super.key,
    required this.text,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.titleText,
        ),
      ),
    );
  }
} 