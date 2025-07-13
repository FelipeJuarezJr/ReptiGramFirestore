import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart';
import '../styles/colors.dart';
import 'dart:async';

class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final ChatService _chatService = ChatService();
  List<QueryDocumentSnapshot> _users = [];
  List<ChatUserData> _sortedUsers = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

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
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _loadUsers();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No other users found.'))
              : _sortedUsers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _sortedUsers.length,
                      itemBuilder: (context, index) {
                        final userData = _sortedUsers[index];
                        
                        return ListTile(
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
                          title: Text(
                            userData.name,
                            style: TextStyle(
                              fontWeight: userData.hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            userData.lastMessage.isNotEmpty ? userData.lastMessage : 'No messages yet',
                            style: TextStyle(
                              color: userData.hasUnreadMessages ? Colors.black : Colors.grey,
                              fontWeight: userData.hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            _openChat(userData.uid, userData.name);
                          },
                        );
                      },
                    ),
    );
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