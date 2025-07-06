import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import '../styles/colors.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import '../state/app_state.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import '../screens/post_screen.dart';
import '../screens/albums_screen.dart';
import '../screens/user_list_screen.dart';
import '../screens/debug_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart';

class NavDrawer extends StatefulWidget {
  final String? userEmail;
  final String? userName;
  final String? userPhotoUrl;

  const NavDrawer({
    Key? key,
    this.userEmail,
    this.userName,
    this.userPhotoUrl,
  }) : super(key: key);

  @override
  State<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<NavDrawer> {
  Uint8List? _selectedImageBytes;
  bool _isUploading = false;
  String? _photoUrl;
  bool _isHovering = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserPhoto();
  }

  Future<void> _uploadImage(Uint8List imageBytes) async {
    try {
      setState(() {
        _isUploading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Create a reference to the user's profile image (consistent with FirestoreService)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${user.uid}.jpg');

      // Upload the image
      await storageRef.putData(imageBytes);

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update the user's profile in Firebase Auth
      await user.updatePhotoURL(downloadUrl);
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      // Also update the user document in Firestore
      await FirestoreService.users.doc(user.uid).update({
        'photoUrl': downloadUrl,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _selectedImageBytes = imageBytes;
        _photoUrl = updatedUser?.photoURL;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _uploadImage(bytes);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _selectedImageBytes = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e')),
        );
      }
    }
  }

  Future<void> _loadUserPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // First try to get photo from Firestore (custom uploads)
      final photoUrl = await FirestoreService.getUserPhotoUrl(user.uid);
      if (mounted) {
        setState(() {
          // Prioritize Firestore photoUrl over Firebase Auth photoURL
          _photoUrl = photoUrl ?? user.photoURL ?? widget.userPhotoUrl;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = FirebaseAuth.instance.currentUser;
    
    // Get username from AppState, fallback to prop, then to displayName
    final String displayUsername = user?.uid != null 
        ? (appState.getUsernameById(user!.uid) ?? widget.userName ?? user.displayName ?? 'User')
        : (widget.userName ?? user?.displayName ?? 'User');
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: AppColors.mainGradient,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close button on the left
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.titleText,
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                // User info on the right
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _isHovering = true),
                        onExit: (_) => setState(() => _isHovering = false),
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: _selectedImageBytes != null
                                    ? MemoryImage(_selectedImageBytes!) as ImageProvider
                                    : (_photoUrl ?? widget.userPhotoUrl) != null
                                        ? NetworkImage((_photoUrl ?? widget.userPhotoUrl)!) as ImageProvider
                                        : const AssetImage('assets/img/reptiGramLogo.png') as ImageProvider,
                                onBackgroundImageError: (exception, stackTrace) {
                                  // Handle image loading errors by showing app logo
                                  setState(() {
                                    _photoUrl = null;
                                  });
                                },
                              ),
                              if (_isUploading)
                                const Positioned.fill(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              if (_isHovering && !_isUploading)
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.edit, color: Colors.white, size: 20),
                                        SizedBox(height: 2),
                                        Text(
                                          'Change',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
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
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        displayUsername,
                        style: const TextStyle(
                          color: AppColors.titleText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        widget.userEmail ?? '',
                        style: const TextStyle(
                          color: AppColors.titleText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PostScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Photos'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlbumsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: Stack(
              children: [
                const Icon(Icons.message),
                if (user != null)
                  StreamBuilder<int>(
                    stream: _getUnreadMessageCount(user.uid),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      if (unreadCount == 0) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            title: const Text('Messenger'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserListScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Debug'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const DebugScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () async {
                const url = 'https://www.paypal.com/donate?campaign_id=4ALPDNVGWDRNW'
;
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else {
                  throw 'Could not launch $url';
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Donate to ReptiGram',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Stream<int> _getUnreadMessageCount(String currentUserId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .snapshots()
        .asyncMap((snapshot) async {
      int totalUnread = 0;
      
      for (final chatDoc in snapshot.docs) {
        final chatId = chatDoc.id;
        final userIds = chatId.split('_');
        
        // Check if current user is part of this chat
        if (userIds.contains(currentUserId)) {
          try {
            // Get the last message to check if it's unread
            final messageSnapshot = await chatDoc.reference
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get();
                
            if (messageSnapshot.docs.isNotEmpty) {
              final lastMessage = messageSnapshot.docs.first.data();
              final senderId = lastMessage['senderId'] as String?;
              
              // If message is from someone else, consider it unread
              if (senderId != null && senderId != currentUserId) {
                totalUnread++;
              }
            }
          } catch (e) {
            print('Error checking unread messages for chat $chatId: $e');
          }
        }
      }
      
      return totalUnread;
    });
  }
} 