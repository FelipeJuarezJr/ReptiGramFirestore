import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_screen.dart';
import '../services/chat_service.dart';
import '../styles/colors.dart';
import '../state/dark_mode_provider.dart';
import 'dart:async';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({Key? key}) : super(key: key);

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<UserSearchData> _searchResults = [];
  List<UserSearchData> _suggestedUsers = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSuggestedUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  Future<void> _loadSuggestedUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    
    try {
      // Get a few random users as suggestions (excluding current user)
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: currentUser.uid)
          .limit(10)
          .get();

      final List<UserSearchData> suggested = [];
      
      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        final name = userData['displayName'] ?? 
                    userData['username'] ?? 
                    userData['name'] ?? 
                    'No Name';
        
        // Get photo URL, but treat asset paths as no photo
        final photoUrl = userData['photoUrl'] ?? userData['photoURL'];
        final avatarUrl = (photoUrl != null && photoUrl.startsWith('http')) 
            ? photoUrl 
            : null; // Treat asset paths and null as no photo
        
        final email = userData['email'] ?? '';

        suggested.add(UserSearchData(
          uid: doc.id,
          name: name,
          email: email,
          avatarUrl: avatarUrl,
        ));
      }

      if (mounted) {
        setState(() {
          _suggestedUsers = suggested;
        });
      }
    } catch (e) {
      print('Error loading suggested users: $e');
    }
  }

  Future<void> _performSearch() async {
    final searchQuery = _searchController.text.trim();
    
    if (searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      
      // Search users by name, username, or email
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final List<UserSearchData> results = [];
      
      for (final doc in usersSnapshot.docs) {
        if (doc.id == currentUser.uid) continue; // Skip current user
        
        final userData = doc.data();
        final name = userData['displayName'] ?? 
                    userData['username'] ?? 
                    userData['name'] ?? 
                    'No Name';
        final email = userData['email'] ?? '';
        final username = email.split('@')[0]; // Extract username from email
        
        // Check if search query matches name, email, or username
        final searchLower = searchQuery.toLowerCase();
        if (name.toLowerCase().contains(searchLower) ||
            email.toLowerCase().contains(searchLower) ||
            username.toLowerCase().contains(searchLower)) {
          
          // Get photo URL, but treat asset paths as no photo
          final photoUrl = userData['photoUrl'] ?? userData['photoURL'];
          final avatarUrl = (photoUrl != null && photoUrl.startsWith('http')) 
              ? photoUrl 
              : null; // Treat asset paths and null as no photo
          
          results.add(UserSearchData(
            uid: doc.id,
            name: name,
            email: email,
            avatarUrl: avatarUrl,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error searching users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startConversation(UserSearchData user) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    
    print('🔵 ========== START CONVERSATION DEBUG ==========');
    print('🔵 Current user UID: ${currentUser.uid}');
    print('🔵 Current user email: ${currentUser.email}');
    print('🔵 Target user UID: ${user.uid}');
    print('🔵 Target user name: ${user.name}');
    
    try {
      // Check if conversation already exists
      final conversationId = _chatService.getChatId(currentUser.uid, user.uid);
      print('🔵 Conversation ID: $conversationId');
      print('🔵 Conversation ID length: ${conversationId.length}');
      
      // Validate conversation ID
      if (conversationId.isEmpty) {
        throw Exception('Conversation ID cannot be empty');
      }
      if (conversationId.length > 1500) {
        throw Exception('Conversation ID too long: ${conversationId.length} characters');
      }
      
      // Check if conversation exists
      print('🔵 Checking if conversation exists...');
      final conversationDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      print('🔵 Conversation exists: ${conversationDoc.exists}');

      String finalConversationId = conversationId;
      
      if (!conversationDoc.exists) {
        print('🔵 Conversation does not exist, creating new one...');
        // Create new conversation
        final conversationData = {
          'participants': [currentUser.uid, user.uid],
          'lastMessage': '',
          'lastTimestamp': 0,
          'unreadCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        };
        print('🔵 Conversation data to create:');
        print('🔵   - participants: ${conversationData['participants']}');
        print('🔵   - lastMessage: ${conversationData['lastMessage']}');
        print('🔵   - lastTimestamp: ${conversationData['lastTimestamp']}');
        print('🔵   - unreadCount: ${conversationData['unreadCount']}');
        print('🔵   - createdAt: serverTimestamp');
        
        try {
          print('🔵 Attempting to create conversation in Firestore...');
          await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .set(conversationData);
          print('✅ Conversation created successfully!');
        } catch (createError) {
          print('❌ Error creating conversation document:');
          print('❌ Error type: ${createError.runtimeType}');
          print('❌ Error message: $createError');
          print('❌ Error toString: ${createError.toString()}');
          
          // Try to get more details about the error
          if (createError.toString().contains('permission-denied')) {
            print('❌ PERMISSION DENIED ERROR DETECTED');
            print('❌ Current user UID: ${currentUser.uid}');
            print('❌ Is user authenticated: ${currentUser.uid.isNotEmpty}');
            print('❌ Auth token: ${await currentUser.getIdToken()}');
            
            // Try to read the user's own document to verify permissions
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();
              print('❌ Can read own user document: ${userDoc.exists}');
            } catch (readError) {
              print('❌ Cannot read own user document: $readError');
            }
          }
          rethrow;
        }
      } else {
        print('🔵 Conversation already exists, loading...');
      }

      // Navigate to chat screen
      if (mounted) {
        print('🔵 Navigating to chat screen...');
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: finalConversationId,
              peerNameFromConversation: user.name,
            ),
          ),
        );
        print('✅ Successfully navigated to chat screen');
      }
      print('🔵 ========== END START CONVERSATION DEBUG ==========');
    } catch (e) {
      print('❌ ========== ERROR IN START CONVERSATION ==========');
      print('❌ Error: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      print('❌ ================================================');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting conversation: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Message'),
        backgroundColor: darkModeProvider.isDarkMode ? AppColors.darkCardBackground : AppColors.titleText,
        foregroundColor: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: darkModeProvider.isDarkMode 
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF424242), // Colors.grey[800]!
                    Color(0xFF212121), // Colors.grey[900]!
                    Color(0xFF000000), // Colors.black
                  ],
                ),
              )
            : null,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name or username...',
                  hintStyle: TextStyle(
                    color: darkModeProvider.isDarkMode ? AppColors.darkTextSecondary : Colors.grey[600],
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.grey[600],
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.grey[600],
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: darkModeProvider.isDarkMode ? AppColors.darkCardBorder : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: darkModeProvider.isDarkMode ? AppColors.darkCardBorder : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: darkModeProvider.isDarkMode ? AppColors.darkText : AppColors.titleText,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: darkModeProvider.isDarkMode 
                      ? AppColors.darkCardBackground.withOpacity(0.5)
                      : Colors.grey[100],
                ),
                autofocus: true,
              ),
            ),
            
            // Results
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasSearched
                      ? _buildSearchResults()
                      : _buildSuggestedUsers(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);
    
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 60,
              color: darkModeProvider.isDarkMode ? AppColors.darkTextSecondary : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with a different name',
              style: TextStyle(
                fontSize: 14,
                color: darkModeProvider.isDarkMode ? AppColors.darkTextSecondary : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildSuggestedUsers() {
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);
    
    if (_suggestedUsers.isEmpty) {
      return Center(
        child: Text(
          'No suggested users available',
          style: TextStyle(
            color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.grey[600],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Suggested People',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _suggestedUsers.length,
            itemBuilder: (context, index) {
              final user = _suggestedUsers[index];
              return _buildUserTile(user);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserTile(UserSearchData user) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: darkModeProvider.isDarkMode 
            ? AppColors.darkCardBackground.withOpacity(0.5)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: darkModeProvider.isDarkMode 
              ? AppColors.darkCardBorder
              : Colors.grey[200]!,
        ),
      ),
      child: ListTile(
        leading: _buildAvatar(user.avatarUrl, user.name),
        title: Text(
          user.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.black,
          ),
        ),
        subtitle: Text(
          user.email,
          style: TextStyle(
            color: darkModeProvider.isDarkMode ? AppColors.darkTextSecondary : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.message_outlined,
          color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.blue,
        ),
        onTap: () => _startConversation(user),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String name) {
    // Check if it's a network URL (real photo) or asset/default
    if (avatarUrl == null || avatarUrl.isEmpty || !avatarUrl.startsWith('http')) {
      // No photo or asset path - show letter avatar
      return _buildLetterAvatar(name);
    }

    // Show network image with proper error handling
    return CircleAvatar(
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (exception, stackTrace) {
        // Handle image loading errors by showing letter avatar
        print('User search avatar image failed to load: $avatarUrl, error: $exception');
      },
      child: null, // Remove any child to let background image show
    );
  }

  Widget _buildLetterAvatar(String name) {
    // Get the first letter of the name, fallback to '?' if empty
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    
    // Generate a consistent color based on the name
    final color = _getColorFromName(name);
    
    return CircleAvatar(
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Color _getColorFromName(String name) {
    // Generate a consistent color based on the name
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
      Colors.red,
      Colors.cyan,
    ];
    
    // Use the first character's ASCII value to pick a color
    final index = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return colors[index];
  }
}

class UserSearchData {
  final String uid;
  final String name;
  final String email;
  final String? avatarUrl;

  UserSearchData({
    required this.uid,
    required this.name,
    required this.email,
    this.avatarUrl,
  });
}
