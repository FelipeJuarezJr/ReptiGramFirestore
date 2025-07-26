import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../styles/colors.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../utils/responsive_utils.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // Check if username is already taken
        final isAvailable = await FirestoreService.isUsernameAvailable(_usernameController.text.trim());
        
        if (!isAvailable) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Username is already taken')),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Create user account
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        
        // Save user data using batch operation
        final String uid = userCredential.user!.uid;
        final userData = {
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FirestoreService.serverTimestamp,
        };
        
        // Use batch operation for better performance and consistency
        await FirestoreService.batchCreateUserAndReserveUsername(UserModel(
          uid: uid,
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        ));
            
        final Future<void> displayNameFuture = userCredential.user!
            .updateDisplayName(_usernameController.text.trim());

        // Wait for display name update to complete
        await displayNameFuture;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful!')),
          );
          Navigator.pop(context); // Return to login screen
        }
      } on FirebaseAuthException catch (e) {
        String message = 'An error occurred';
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'An account already exists for that email.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: ResponsiveUtils.isWideScreen(context) 
              ? _buildDesktopLayout(context)
              : _buildMobileLayout(context),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(
          children: [
            // Left side - Logo and branding
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/img/reptiGramLogo.png',
                      height: 180,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ReptiGram',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.titleText,
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
                    const SizedBox(height: 16),
                    const Text(
                      'Join the reptile community',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppColors.titleText,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Right side - Registration form
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(48.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFF8E1), // Light cream
                              Color(0xFFFFE0B2), // Light orange
                              Color(0xFFFFCC80), // Medium orange
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: _buildRegistrationForm(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Image.asset(
                'assets/img/reptiGramLogo.png',
                height: 220,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ReptiGram',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.titleText,
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildRegistrationForm(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.inputGradient,
              borderRadius: AppColors.pillShape,
            ),
            child: TextFormField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.brown),
              decoration: InputDecoration(
                hintText: 'Username',
                hintStyle: const TextStyle(
                  color: Colors.brown,
                  fontSize: 16,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Username is required';
                }
                if (value.length < 3) {
                  return 'Username must be at least 3 characters';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.inputGradient,
              borderRadius: AppColors.pillShape,
            ),
            child: TextFormField(
              controller: _emailController,
              style: const TextStyle(color: Colors.brown),
              decoration: InputDecoration(
                hintText: 'Email',
                hintStyle: const TextStyle(
                  color: Colors.brown,
                  fontSize: 16,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.inputGradient,
              borderRadius: AppColors.pillShape,
            ),
            child: TextFormField(
              controller: _passwordController,
              style: const TextStyle(color: Colors.brown),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(
                  color: Colors.brown,
                  fontSize: 16,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                if (!value.contains(RegExp(r'[A-Z]'))) {
                  return 'Password must contain at least one uppercase letter';
                }
                if (!value.contains(RegExp(r'[0-9]'))) {
                  return 'Password must contain at least one number';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.inputGradient,
              borderRadius: AppColors.pillShape,
            ),
            child: TextFormField(
              controller: _confirmPasswordController,
              style: const TextStyle(color: Colors.brown),
              decoration: InputDecoration(
                hintText: 'Confirm Password',
                hintStyle: const TextStyle(
                  color: Colors.brown,
                  fontSize: 16,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const CircularProgressIndicator()
              : SizedBox(
                  width: ResponsiveUtils.isWideScreen(context) 
                      ? double.infinity 
                      : MediaQuery.of(context).size.width * 0.5,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.loginGradient,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Register',
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Already have an account? Login',
              style: TextStyle(
                color: AppColors.titleText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
} 