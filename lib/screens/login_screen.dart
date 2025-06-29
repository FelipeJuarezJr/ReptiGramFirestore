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
import 'package:firebase_database/firebase_database.dart';

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
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);

      User? user;

      if (kIsWeb) {
        // Web sign-in flow
        final googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        user = userCredential.user;
      } else {
        // Mobile sign-in flow
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          setState(() => _isLoading = false);
          return; // user aborted sign in
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        user = userCredential.user;
      }

      if (user != null) {
        // Update user data in Realtime Database
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
      debugPrint('Google sign-in error: $e');
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
    final ref = FirebaseDatabase.instance.ref("users/${user.uid}");
    await ref.update({
      "displayName": user.displayName,
      "email": user.email,
      "photoURL": user.photoURL,
      "lastLogin": ServerValue.timestamp,
    });
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
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
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
          child: SingleChildScrollView(
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
                    child: Form(
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
                              : Container(
                                  width: MediaQuery.of(context).size.width * 0.5,
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
                          // Google Sign In Button - using your new _handleGoogleSignIn
                          Center(
                            child: _isLoading
                                ? const SizedBox() // don't show button while loading
                                : ElevatedButton.icon(
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
    _passwordController.dispose();
    super.dispose();
  }
}
