import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart';
import '../styles/colors.dart';
import '../utils/responsive_utils.dart';
import 'dart:async';

class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _users = [];
  List<ChatUserData> _sortedUsers = [];
  List<ChatUserData> _filteredUsers = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    // Refresh the list every 5 seconds to get real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isLoading) {
        _refreshUserData();
      }
    });
    
    // Add search listener
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce search to avoid too many filter operations
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _filterUsers();
    });
  }

  void _filterUsers() {
    final searchQuery = _searchController.text.toLowerCase().trim();
    
    if (searchQuery.isEmpty) {
      setState(() {
        _filteredUsers = List.from(_sortedUsers);
      });
    } else {
      setState(() {
        _filteredUsers = _sortedUsers.where((user) {
          final name = user.name.toLowerCase();
          final email = user.email.toLowerCase();
          final username = user.email.split('@')[0].toLowerCase(); // Extract username from email
          return name.contains(searchQuery) || 
                 email.contains(searchQuery) || 
                 username.contains(searchQuery);
        }).toList();
      });
    }
  }

  Future<void> _loadUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    
    try {
      // Get all users
      final usersSnapshot = await FirestoreService.users.get();
      
      // Filter out current user
      final users = usersSnapshot.docs.where((doc) {
        final userData = doc.data() as Map<String, dynamic>;
        final userEmail = userData['email'] ?? '';
        return doc.id != currentUser.uid && userEmail != currentUser.email;
      }).toList();

      setState(() {
        _users = users;
        _isLoading = false;
      });

      // Load initial user data
      await _refreshUserData();
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshUserData() async {
    if (_users.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser!;
    final List<ChatUserData> usersWithChatData = [];

    // Process users in parallel for better performance
    final futures = _users.map((userDoc) => _getUserChatData(userDoc, currentUser.uid));
    final results = await Future.wait(futures);
    
    usersWithChatData.addAll(results.where((data) => data != null).cast<ChatUserData>());

    // Sort users: unread first, then by last message timestamp (newest first)
    usersWithChatData.sort((a, b) {
      // First sort by unread status (unread first)
      if (a.hasUnreadMessages != b.hasUnreadMessages) {
        return a.hasUnreadMessages ? -1 : 1;
      }
      // Then sort by last message timestamp (newest first)
      return b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp);
    });

    if (mounted) {
      setState(() {
        _sortedUsers = usersWithChatData;
        // Update filtered users while preserving search filter
        _filterUsers();
      });
    }
  }

  Future<void> _openChat(String peerUid, String peerName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerUid: peerUid,
          peerName: peerName,
        ),
      ),
    );
    // Refresh the list when returning from chat
    if (mounted) {
      await _refreshUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start a Chat'),
        backgroundColor: AppColors.titleText,
        foregroundColor: Colors.white,
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
              },
              tooltip: 'Clear search',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _loadUsers();
            },
            tooltip: 'Refresh list',
          ),
        ],
      ),
      body: ResponsiveUtils.isWideScreen(context) 
          ? _buildDesktopLayout(context)
          : _buildMobileLayout(context),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1400),
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Chat info and stats
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
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Messenger',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.titleText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start conversations with other users',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.titleText.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildMessengerStats(),
                        const SizedBox(height: 20),
                        _buildMessengerActions(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Right side - Users list
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Users header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.titleText,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people, color: Colors.white),
                                const SizedBox(width: 12),
                                Text(
                                  'Available Users',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_filteredUsers.length} users',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Search bar
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search users by name or email...',
                                  prefixIcon: const Icon(Icons.search, color: AppColors.titleText),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, color: AppColors.titleText),
                                          onPressed: () {
                                            _searchController.clear();
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Users list
                      Expanded(
                        child: _buildUsersList(),
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

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        // Search bar for mobile
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by name or email...',
                prefixIcon: const Icon(Icons.search, color: AppColors.titleText),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.titleText),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        // Users list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('No other users found.'))
                  : _filteredUsers.isEmpty
                      ? const Center(child: Text('No users found matching your search.'))
                      : _buildUsersList(),
        ),
      ],
    );
  }

  Widget _buildMessengerStats() {
    final totalUsers = _filteredUsers.length;
    final unreadCount = _filteredUsers.where((user) => user.hasUnreadMessages).length;
    final activeChats = _filteredUsers.where((user) => user.lastMessage.isNotEmpty).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.titleText,
          ),
        ),
        const SizedBox(height: 12),
        _buildStatItem('Total Users', totalUsers.toString(), Icons.people),
        const SizedBox(height: 8),
        _buildStatItem('Unread Chats', unreadCount.toString(), Icons.mark_email_unread),
        const SizedBox(height: 8),
        _buildStatItem('Active Chats', activeChats.toString(), Icons.chat),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.titleText, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.titleText,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.titleText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessengerActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.titleText,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _loadUsers();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh List'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.titleText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _users.isEmpty
            ? const Center(child: Text('No other users found.'))
            : _filteredUsers.isEmpty
                ? const Center(child: Text('No users found matching your search.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final userData = _filteredUsers[index];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: userData.hasUnreadMessages 
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: userData.hasUnreadMessages
                              ? Border.all(color: Colors.blue.withOpacity(0.3))
                              : null,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Stack(
                            children: [
                              _buildAvatar(userData.avatarUrl, userData.name),
                              if (userData.hasUnreadMessages)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    child: Text(
                                      userData.unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: _buildHighlightedText(
                            userData.name,
                            _searchController.text,
                            userData.hasUnreadMessages,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userData.lastMessage.isNotEmpty ? userData.lastMessage : 'No messages yet',
                                style: TextStyle(
                                  color: userData.hasUnreadMessages ? Colors.black : Colors.grey,
                                  fontWeight: userData.hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                              if (userData.lastMessageTimestamp > 0)
                                Text(
                                  _formatTimestamp(userData.lastMessageTimestamp),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          trailing: userData.hasUnreadMessages
                              ? Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.chat,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                )
                              : null,
                          onTap: () {
                            _openChat(userData.uid, userData.name);
                          },
                        ),
                      );
                    },
                  );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<ChatUserData?> _getUserChatData(QueryDocumentSnapshot userDoc, String currentUserId) async {
    final userData = userDoc.data() as Map<String, dynamic>;
    final name = userData['displayName'] ?? userData['username'] ?? userData['name'] ?? 'No Name';
    final email = userData['email'] ?? '';
    final avatarUrl = userData['photoUrl'] ?? userData['photoURL'];
    final uid = userDoc.id;
    final chatId = _chatService.getChatId(currentUserId, uid);

    try {
      // Get unread count and last message in parallel
      final unreadQuery = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: uid)
          .get();

      final lastMessageQuery = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      final results = await Future.wait([unreadQuery, lastMessageQuery]);
      final unreadSnapshot = results[0] as QuerySnapshot;
      final lastMessageSnapshot = results[1] as QuerySnapshot;

      int unreadCount = 0;
      if (unreadSnapshot.docs.isNotEmpty) {
        // Count unread messages
        for (final doc in unreadSnapshot.docs) {
          final messageData = doc.data() as Map<String, dynamic>;
          final readBy = messageData['readBy'] as List<dynamic>?;
          
          if (readBy == null || !readBy.contains(currentUserId)) {
            unreadCount++;
          }
        }
      }

      String lastMessage = '';
      int lastMessageTimestamp = 0;

      if (lastMessageSnapshot.docs.isNotEmpty) {
        final lastMessageData = lastMessageSnapshot.docs.first.data() as Map<String, dynamic>;
        final messageText = lastMessageData['text'] as String? ?? '';
        final messageType = lastMessageData['messageType'] as String? ?? 'text';
        lastMessageTimestamp = lastMessageData['timestamp'] as int? ?? 0;

        // Format last message preview
        switch (messageType) {
          case 'image':
            lastMessage = '📷 Image';
            break;
          case 'file':
            final fileName = lastMessageData['fileName'] as String? ?? 'File';
            lastMessage = '📎 $fileName';
            break;
          default:
            lastMessage = messageText.length > 30 
                ? '${messageText.substring(0, 30)}...' 
                : messageText;
            break;
        }
      }

      return ChatUserData(
        userDoc: userDoc,
        name: name,
        email: email,
        avatarUrl: avatarUrl,
        uid: uid,
        lastMessage: lastMessage,
        hasUnreadMessages: unreadCount > 0,
        lastMessageTimestamp: lastMessageTimestamp,
        unreadCount: unreadCount,
      );
    } catch (e) {
      print('Error getting chat data for user $name: $e');
      return null;
    }
  }

  Widget _buildHighlightedText(String text, String searchQuery, bool isBold) {
    if (searchQuery.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerSearchQuery = searchQuery.toLowerCase();
    final index = lowerText.indexOf(lowerSearchQuery);
    
    if (index == -1) {
      return Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
          color: Colors.black,
        ),
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + searchQuery.length),
            style: TextStyle(
              backgroundColor: Colors.yellow.withOpacity(0.3),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(index + searchQuery.length)),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String name) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return const CircleAvatar(
        backgroundImage: AssetImage('assets/img/reptiGramLogo.png'),
      );
    }

    return CircleAvatar(
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (exception, stackTrace) {
        print('Avatar image failed to load: $avatarUrl, error: $exception');
      },
    );
  }
}

class ChatUserData {
  final QueryDocumentSnapshot userDoc;
  final String name;
  final String email;
  final String? avatarUrl;
  final String uid;
  final String lastMessage;
  final bool hasUnreadMessages;
  final int lastMessageTimestamp;
  final int unreadCount;

  ChatUserData({
    required this.userDoc,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.uid,
    required this.lastMessage,
    required this.hasUnreadMessages,
    required this.lastMessageTimestamp,
    required this.unreadCount,
  });
} 