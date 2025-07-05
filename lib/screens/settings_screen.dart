import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state/dark_mode_provider.dart';
import '../state/app_state.dart';
import '../services/firestore_service.dart';
import '../utils/validation_utils.dart';
import '../styles/colors.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    final user = _auth.currentUser;
    final isGoogleUser = user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.titleText),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.titleText,
                      ),
                    ),
                  ],
                ),
              ),

              // Settings List
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: AppColors.inputGradient,
                    borderRadius: AppColors.pillShape,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // User Info Section
                      if (user != null) ...[
                        _buildSectionHeader('Account Information'),
                        _buildUserInfoTile(user),
                        const SizedBox(height: 16),
                      ],

                      // Account Management Section
                      if (user != null) ...[
                        _buildSectionHeader('Account Management'),
                        _buildSettingTile(
                          'Change Username',
                          Icons.person,
                          onTap: () => _showChangeUsernameDialog(),
                        ),
                        if (!isGoogleUser) ...[
                          _buildPasswordTile('Change Password', Icons.lock, () => _showChangePasswordDialog()),
                          _buildPasswordTile('Reset Password', Icons.lock_reset, () => _showResetPasswordDialog()),
                        ],
                        const SizedBox(height: 16),
                      ],

                      // App Settings Section
                      _buildSectionHeader('App Settings'),
                      _buildSettingTile(
                        'Dark Mode',
                        Icons.dark_mode,
                        trailing: Switch(
                          value: darkModeProvider.isDarkMode,
                          onChanged: darkModeProvider.toggleDarkMode,
                          activeColor: Colors.brown,
                        ),
                      ),
                      _buildSettingTile(
                        'Language',
                        Icons.language,
                        onTap: () {
                          // TODO: Implement language selection
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Language selection coming soon!')),
                          );
                        },
                      ),

                      // Account Actions Section
                      if (user != null) ...[
                        const SizedBox(height: 16),
                        _buildSectionHeader('Account Actions'),
                        _buildSettingTile(
                          'Sign Out',
                          Icons.logout,
                          onTap: _signOut,
                          textColor: Colors.red,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.brown,
        ),
      ),
    );
  }

  Widget _buildUserInfoTile(User user) {
    final appState = Provider.of<AppState>(context);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.brown.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null ? const Icon(Icons.person, size: 30) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName ?? 'User',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                    Text(
                      user.email ?? 'No email',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.brown,
                      ),
                    ),
                    FutureBuilder<String?>(
                      future: appState.fetchUsername(user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null && snapshot.data != 'Unknown User') {
                          return Text(
                            'Username: ${snapshot.data}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    Text(
                      'Provider: ${user.providerData.first.providerId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.brown),
      title: Text(
        title,
        style: const TextStyle(color: Colors.brown),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.brown, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSettingTile(String title, IconData icon, {Widget? trailing, VoidCallback? onTap, Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.brown),
      title: Text(
        title,
        style: TextStyle(color: textColor ?? Colors.brown),
      ),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.arrow_forward_ios, color: Colors.brown, size: 16) : null),
      onTap: onTap,
    );
  }

  void _showChangeUsernameDialog() async {
    final newUsernameController = TextEditingController();
    final currentUser = _auth.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in')),
      );
      return;
    }

    // Get current username from app state
    final appState = Provider.of<AppState>(context, listen: false);
    String currentUsername = '';
    
    // Try to get current username
    final username = await appState.fetchUsername(currentUser.uid);
    if (username != null && username != 'Unknown User') {
      currentUsername = username;
      newUsernameController.text = username;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppColors.pillShape),
        title: const Text('Change Username', style: TextStyle(color: Colors.brown)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current username: ${currentUsername.isNotEmpty ? currentUsername : 'Loading...'}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newUsernameController,
              decoration: const InputDecoration(
                labelText: 'New Username',
                border: OutlineInputBorder(),
                hintText: 'Enter new username',
              ),
              onChanged: (value) {
                // Real-time validation
                final error = ValidationUtils.getUsernameError(value);
                if (error != null) {
                  // You could show error text here
                }
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Username must be 3-20 characters, alphanumeric and underscore only',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.brown)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUsername = newUsernameController.text.trim();
              
              // Validate username
              final error = ValidationUtils.getUsernameError(newUsername);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
                return;
              }

              Navigator.pop(context);
              await _changeUsername(newUsername);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
            child: const Text('Change Username', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppColors.pillShape),
        title: const Text('Change Password', style: TextStyle(color: Colors.brown)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.brown)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _changePassword(
                currentPasswordController.text,
                newPasswordController.text,
                confirmPasswordController.text,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
            child: const Text('Change Password', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppColors.pillShape),
        title: const Text('Reset Password', style: TextStyle(color: Colors.brown)),
        content: const Text(
          'A password reset email will be sent to your email address. '
          'Check your inbox and follow the link to reset your password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.brown)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetPassword();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
            child: const Text('Send Reset Email', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _changeUsername(String newUsername) async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Check if username is available
      final isAvailable = await FirestoreService.isUsernameAvailable(newUsername);
      if (!isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken')),
        );
        return;
      }

      // Get current username to remove from usernames collection
      final appState = Provider.of<AppState>(context, listen: false);
      final currentUsername = await appState.getUsernameById(user.uid);

      // Update Firebase Auth displayName
      await user.updateDisplayName(newUsername);

      // Update Firestore user document and usernames collection in batch
      await FirestoreService.updateUsername(user.uid, currentUsername ?? '', newUsername);

      // Update app state
      appState.updateUsername(user.uid, newUsername);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username changed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the UI
        setState(() {});
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to change username';
      if (e.code == 'requires-recent-login') {
        message = 'Please log in again to change your username';
      } else {
        message = 'Error: ${e.message}';
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword(String currentPassword, String newPassword, String confirmPassword) async {
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Re-authenticate user before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to change password';
      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak';
      } else {
        message = 'Error: ${e.message}';
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user?.email == null) throw Exception('No email available');

      await _auth.sendPasswordResetEmail(email: user!.email!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send reset email';
      if (e.code == 'user-not-found') {
        message = 'No user found with that email';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else {
        message = 'Error: ${e.message}';
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }
} 