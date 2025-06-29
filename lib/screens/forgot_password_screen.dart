import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../styles/colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _emailSent = false;
  bool _showManualReset = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      print('Attempting to send password reset email to: $email');

      // Debug: Let's try to send the reset email directly without checking methods first
      print('Sending password reset email directly...');
      
      await _auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: ActionCodeSettings(
          url: 'https://reptigram-lite.web.app/login',
          handleCodeInApp: false,
          iOSBundleId: null,
          androidPackageName: null,
          androidInstallApp: false,
          androidMinimumVersion: null,
          dynamicLinkDomain: null,
        ),
      );

      print('Password reset email sent successfully');
      
      setState(() {
        _isLoading = false;
        _emailSent = true;
        _successMessage = 'Password reset email sent! Please check your inbox and spam folder. If you don\'t receive it within a few minutes, please try again.\n\nIf you still don\'t receive the email, you can:\n1. Try again in a few minutes\n2. Check your spam/junk folder\n3. Contact support if the issue persists';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_successMessage!),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception: ${e.code} - ${e.message}');
      String message = 'An error occurred';
      
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email address. This could mean:\n\n1. The account was created with Google Sign-In only\n2. The email address is incorrect\n3. The account was deleted\n\nPlease try logging in with Google Sign-In or create a new account.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          message = 'Too many requests. Please wait a few minutes before trying again.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        case 'operation-not-allowed':
          message = 'Password reset is not enabled. Please contact support.';
          break;
        default:
          message = 'Error: ${e.message}';
      }
      
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      print('General Exception: $e');
      setState(() {
        _errorMessage = 'Unexpected error occurred. Please try again.';
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _manualPasswordReset() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters long.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final newPassword = _newPasswordController.text;

      // First, try to sign in with the current password to verify the account
      // This is a workaround since we can't directly change password without current credentials
      
      setState(() {
        _errorMessage = 'Manual password reset requires current password verification. Please use the email reset link or contact support.';
        _isLoading = false;
      });
    } catch (e) {
      print('Manual reset error: $e');
      setState(() {
        _errorMessage = 'Manual password reset failed. Please try the email reset or contact support.';
        _isLoading = false;
      });
    }
  }

  void _toggleManualReset() {
    setState(() {
      _showManualReset = !_showManualReset;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Back button
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.titleText,
                          size: 30,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Image.asset(
                      'assets/img/reptiGramLogo.png',
                      height: 150,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.logoTitleText,
                      shadows: [
                        Shadow(
                          color: AppColors.titleShadow,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Enter your email address and we\'ll send you a link to reset your password.\n\nNote: If you created your account using Google Sign-In, please use the "Sign in with Google" button on the login page instead.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.titleText,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (_errorMessage != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_successMessage != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _successMessage!,
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'If you don\'t receive the email:',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '• Check your spam/junk folder\n• Wait 5-10 minutes for delivery\n• Try again in a few minutes\n• Contact support if the issue persists',
                                    style: TextStyle(color: Colors.green, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.inputGradient,
                              borderRadius: AppColors.pillShape,
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                hintText: 'Email',
                                hintStyle: const TextStyle(
                                  color: Colors.brown,
                                ),
                              ).applyDefaults(AppColors.inputDecorationTheme),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : Container(
                                  width: MediaQuery.of(context).size.width * 0.6,
                                  child: ElevatedButton(
                                    onPressed: _resetPassword,
                                    style: AppColors.pillButtonStyle,
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        gradient: AppColors.loginGradient,
                                        borderRadius: AppColors.pillShape,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Send Reset Link',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Back to Login',
                              style: TextStyle(
                                color: AppColors.titleText,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
} 