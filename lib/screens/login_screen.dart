import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../widgets/google_sign_in_button.dart';  // You might replace this with your inline button if you want
import '../styles/colors.dart';
import '../screens/post_screen.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/firestore_service.dart';
import '../utils/responsive_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testFirebaseAuth();
  }

  Future<void> _testFirebaseAuth() async {
    // Debug method - removed print statements to reduce clutter
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);

      // Force account picker by clearing current user and using custom parameters
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      
      // Force account selection with multiple parameters
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
        'access_type': 'offline',
        'include_granted_scopes': 'true',
      });
      
      // Clear current user to force account picker
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
      
      // Use popup for both web and mobile
      final userCredential = await _auth.signInWithPopup(googleProvider);
      final user = userCredential.user;

      if (user != null) {
        // Update user data in Firestore
        await _updateUserData(user);

        // Update AppState or other state management if needed
        final appState = Provider.of<AppState>(context, listen: false);
        await appState.initializeUser();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const PostScreen(shouldLoadPosts: true),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in with Google: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserData(User user) async {
    try {
      // Check if user document exists
      final userDoc = await FirestoreService.users.doc(user.uid).get();
      
      if (userDoc.exists) {
        // Update existing user document
    await FirestoreService.updateUser(user.uid, {
      "displayName": user.displayName,
      "email": user.email,
      "photoURL": user.photoURL,
      "lastLogin": FirestoreService.serverTimestamp,
    });
        // User document updated
      } else {
        // Create new user document
        await FirestoreService.users.doc(user.uid).set({
          "uid": user.uid,
          "displayName": user.displayName,
          "email": user.email,
          "photoURL": user.photoURL,
          "username": user.email?.split('@')[0] ?? 'user', // Use email prefix as username
          "createdAt": FirestoreService.serverTimestamp,
          "lastLogin": FirestoreService.serverTimestamp,
        });
        // User document created
      }
    } catch (e) {
      // Don't throw error - let user continue even if Firestore update fails
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PostScreen(shouldLoadPosts: true),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email. Please register first.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many failed attempts. Please try again later.';
      } else {
        message = 'Login failed: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                      'Reptigram',
                      style: TextStyle(
                        fontSize: 48,
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
                    const SizedBox(height: 16),
                    const Text(
                      'Connect with reptile enthusiasts worldwide',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppColors.logoTitleText,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Right side - Login form
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
                          child: _buildLoginForm(context),
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
              'Reptigram',
              style: TextStyle(
                fontSize: 40,
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildLoginForm(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.inputGradient,
              borderRadius: AppColors.pillShape,
            ),
            child: TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(
                  color: Colors.brown,
                ),
              ).applyDefaults(AppColors.inputDecorationTheme),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
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
                  child: ElevatedButton(
                    onPressed: _handleLogin,
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
                          'Login',
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
          const SizedBox(height: 16),
          // Google Sign In Button
          Center(
            child: _isLoading
                ? const SizedBox() // don't show button while loading
                : SizedBox(
                    width: ResponsiveUtils.isWideScreen(context) 
                        ? double.infinity 
                        : null,
                    child: ElevatedButton.icon(
                      onPressed: _handleGoogleSignIn,
                      icon: Image.asset('assets/img/google_logo.png', height: 24),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 20),
                      ),
                    ),
                  ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegisterScreen(),
                ),
              );
            },
            child: const Text(
              'Don\'t have an account? Register',
              style: TextStyle(
                color: AppColors.titleText,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ForgotPasswordScreen(),
                ),
              );
            },
            child: const Text(
              'Forgot Password?',
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
    _passwordController.dispose();
    super.dispose();
  }
}
