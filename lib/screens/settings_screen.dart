import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state/dark_mode_provider.dart';
import '../state/app_state.dart';
import '../services/firestore_service.dart';
import '../utils/validation_utils.dart';
import '../utils/responsive_utils.dart';
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
      backgroundColor: darkModeProvider.isDarkMode ? Colors.black : Colors.transparent,
      body: Container(
        decoration: darkModeProvider.isDarkMode 
            ? null 
            : const BoxDecoration(
                gradient: AppColors.mainGradient,
              ),
        child: SafeArea(
          child: ResponsiveUtils.isWideScreen(context) 
              ? _buildDesktopLayout(context, user, isGoogleUser, darkModeProvider)
              : _buildMobileLayout(context, user, isGoogleUser, darkModeProvider),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, User? user, bool isGoogleUser, DarkModeProvider darkModeProvider) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1400),
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Settings info and user details
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.only(top: 24.0, right: 16.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: darkModeProvider.isDarkMode 
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2D2D2D), // Dark grey
                              Color(0xFF1A1A1A), // Darker grey
                              Color(0xFF0F0F0F), // Almost black
                            ],
                            stops: [0.0, 0.5, 1.0],
                          )
                        : const LinearGradient(
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
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back, color: darkModeProvider.isDarkMode ? Colors.white : AppColors.titleText),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: darkModeProvider.isDarkMode ? Colors.white : AppColors.titleText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (user != null) _buildDesktopUserInfo(user),
                        const SizedBox(height: 20),
                        _buildSettingsStats(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Right side - Settings options
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(top: 24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: darkModeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Settings header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.titleText,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.settings, color: Colors.white),
                            const SizedBox(width: 12),
                            const Text(
                              'Settings Options',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Settings list
                      Expanded(
                        child: _buildSettingsList(user, isGoogleUser, darkModeProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, User? user, bool isGoogleUser, DarkModeProvider darkModeProvider) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: darkModeProvider.isDarkMode ? Colors.white : AppColors.titleText),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkModeProvider.isDarkMode ? Colors.white : AppColors.titleText,
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
              gradient: darkModeProvider.isDarkMode 
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.grey[800]!,
                        Colors.grey[900]!,
                        Colors.black,
                      ],
                    )
                  : AppColors.inputGradient,
              borderRadius: AppColors.pillShape,
            ),
            child: _buildSettingsList(user, isGoogleUser, darkModeProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopUserInfo(User user) {
    final appState = Provider.of<AppState>(context);
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: darkModeProvider.isDarkMode ? Colors.white : AppColors.titleText,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null ? const Icon(Icons.person, size: 40) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? 'User',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkModeProvider.isDarkMode ? Colors.white : AppColors.titleText,
                    ),
                  ),
                  Text(
                    user.email ?? 'No email',
                    style: TextStyle(
                      fontSize: 14,
                      color: darkModeProvider.isDarkMode ? Colors.grey[300] : AppColors.titleText,
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
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Provider: ${user.providerData.first.providerId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsStats() {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings Overview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: darkModeProvider.isDarkMode ? Colors.white : AppColors.titleText,
          ),
        ),
        const SizedBox(height: 12),
        _buildStatItem('Account Settings', 'Manage your profile', Icons.person),
        const SizedBox(height: 8),
        _buildStatItem('App Settings', 'Customize your experience', Icons.settings),
        const SizedBox(height: 8),
        _buildStatItem('Security', 'Password and privacy', Icons.security),
      ],
    );
  }

  Widget _buildStatItem(String title, String subtitle, IconData icon) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: darkModeProvider.isDarkMode 
            ? Colors.grey[800]!.withOpacity(0.5)
            : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: darkModeProvider.isDarkMode ? Colors.white : AppColors.titleText, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkModeProvider.isDarkMode ? Colors.white : AppColors.titleText,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: darkModeProvider.isDarkMode ? Colors.grey[300] : AppColors.titleText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(User? user, bool isGoogleUser, DarkModeProvider darkModeProvider) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // User Info Section
        if (user != null && !ResponsiveUtils.isWideScreen(context)) ...[
          _buildSectionHeader('Account Information'),
          _buildUserInfoTile(user),
          const SizedBox(height: 16),
        ],

        // Account Management Section
        if (user != null) ...[
          _buildSectionHeader('Account Management'),
          ResponsiveUtils.isWideScreen(context)
              ? _buildDesktopSettingTile(
                  'Change Username',
                  Icons.person,
                  'Update your display name',
                  onTap: () => _showChangeUsernameDialog(),
                )
              : _buildSettingTile(
                  'Change Username',
                  Icons.person,
                  onTap: () => _showChangeUsernameDialog(),
                ),
          if (!isGoogleUser) ...[
            ResponsiveUtils.isWideScreen(context)
                ? _buildDesktopSettingTile(
                    'Change Password',
                    Icons.lock,
                    'Update your password',
                    onTap: () => _showChangePasswordDialog(),
                  )
                : _buildPasswordTile('Change Password', Icons.lock, () => _showChangePasswordDialog()),
            ResponsiveUtils.isWideScreen(context)
                ? _buildDesktopSettingTile(
                    'Reset Password',
                    Icons.lock_reset,
                    'Send reset email',
                    onTap: () => _showResetPasswordDialog(),
                  )
                : _buildPasswordTile('Reset Password', Icons.lock_reset, () => _showResetPasswordDialog()),
          ],
          const SizedBox(height: 16),
        ],

        // App Settings Section
        _buildSectionHeader('App Settings'),
        ResponsiveUtils.isWideScreen(context)
            ? _buildDesktopSettingTile(
                'Dark Mode',
                Icons.dark_mode,
                'Toggle dark theme',
                trailing: Switch(
                  value: darkModeProvider.isDarkMode,
                  onChanged: darkModeProvider.toggleDarkMode,
                  activeColor: Colors.brown,
                ),
              )
            : _buildSettingTile(
                'Dark Mode',
                Icons.dark_mode,
                trailing: Switch(
                  value: darkModeProvider.isDarkMode,
                  onChanged: darkModeProvider.toggleDarkMode,
                  activeColor: Colors.brown,
                ),
              ),
        ResponsiveUtils.isWideScreen(context)
            ? _buildDesktopSettingTile(
                'Language',
                Icons.language,
                'Select your language',
                onTap: () {
                  // TODO: Implement language selection
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Language selection coming soon!')),
                  );
                },
              )
            : _buildSettingTile(
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
          ResponsiveUtils.isWideScreen(context)
              ? _buildDesktopSettingTile(
                  'Sign Out',
                  Icons.logout,
                  'Sign out of your account',
                  onTap: _signOut,
                  textColor: Colors.red,
                )
              : _buildSettingTile(
                  'Sign Out',
                  Icons.logout,
                  onTap: _signOut,
                  textColor: Colors.red,
                ),
        ],
      ],
    );
  }

  Widget _buildDesktopSettingTile(String title, IconData icon, String subtitle, {Widget? trailing, VoidCallback? onTap, Color? textColor}) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: darkModeProvider.isDarkMode 
            ? Colors.grey[800]!.withOpacity(0.3)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: textColor ?? (darkModeProvider.isDarkMode ? Colors.white : Colors.brown), size: 24),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor ?? (darkModeProvider.isDarkMode ? Colors.white : Colors.brown),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: darkModeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: trailing ?? (onTap != null ? Icon(Icons.arrow_forward_ios, color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown, size: 16) : null),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown,
        ),
      ),
    );
  }

  Widget _buildUserInfoTile(User user) {
    final appState = Provider.of<AppState>(context);
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: darkModeProvider.isDarkMode 
            ? Colors.grey[800]!.withOpacity(0.3)
            : Colors.brown.withOpacity(0.1),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown,
                      ),
                    ),
                    Text(
                      user.email ?? 'No email',
                      style: TextStyle(
                        fontSize: 14,
                        color: darkModeProvider.isDarkMode ? Colors.grey[300] : Colors.brown,
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
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    
    return ListTile(
      leading: Icon(icon, color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown),
      title: Text(
        title,
        style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSettingTile(String title, IconData icon, {Widget? trailing, VoidCallback? onTap, Color? textColor}) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    
    return ListTile(
      leading: Icon(icon, color: textColor ?? (darkModeProvider.isDarkMode ? Colors.white : Colors.brown)),
      title: Text(
        title,
        style: TextStyle(color: textColor ?? (darkModeProvider.isDarkMode ? Colors.white : Colors.brown)),
      ),
      trailing: trailing ?? (onTap != null ? Icon(Icons.arrow_forward_ios, color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown, size: 16) : null),
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
      builder: (context) {
        final darkModeProvider = Provider.of<DarkModeProvider>(context);
        return AlertDialog(
          backgroundColor: darkModeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppColors.pillShape),
          title: Text('Change Username', style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current username: ${currentUsername.isNotEmpty ? currentUsername : 'Loading...'}',
                style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.grey[400] : Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newUsernameController,
                decoration: InputDecoration(
                  labelText: 'New Username',
                  labelStyle: TextStyle(color: darkModeProvider.isDarkMode ? Colors.grey[400] : null),
                  border: OutlineInputBorder(),
                  hintText: 'Enter new username',
                  hintStyle: TextStyle(color: darkModeProvider.isDarkMode ? Colors.grey[500] : null),
                ),
                style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : null),
                onChanged: (value) {
                  // Real-time validation
                  final error = ValidationUtils.getUsernameError(value);
                  if (error != null) {
                    // You could show error text here
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Username must be 3-20 characters, alphanumeric and underscore only',
                style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.grey[400] : Colors.grey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown)),
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
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final darkModeProvider = Provider.of<DarkModeProvider>(context);
        return AlertDialog(
          backgroundColor: darkModeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppColors.pillShape),
          title: Text('Change Password', style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : null),
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: TextStyle(color: darkModeProvider.isDarkMode ? Colors.grey[400] : null),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : null),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(color: darkModeProvider.isDarkMode ? Colors.grey[400] : null),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : null),
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                labelStyle: TextStyle(color: darkModeProvider.isDarkMode ? Colors.grey[400] : null),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown)),
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
        );
      },
    );
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final darkModeProvider = Provider.of<DarkModeProvider>(context);
        return AlertDialog(
          backgroundColor: darkModeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppColors.pillShape),
          title: Text('Reset Password', style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown)),
        content: Text(
          'A password reset email will be sent to your email address. '
          'Check your inbox and follow the link to reset your password.',
          style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.grey[300] : null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: darkModeProvider.isDarkMode ? Colors.white : Colors.brown)),
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
        );
      },
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