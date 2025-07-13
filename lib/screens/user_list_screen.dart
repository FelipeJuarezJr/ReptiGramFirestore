import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart';
import '../styles/colors.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final ChatService _chatService = ChatService();
  List<ChatUserData> _sortedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsersWithChatData();
  }

  Future<void> _loadUsersWithChatData() async {
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

      if (users.isEmpty) {
        setState(() {
          _sortedUsers = [];
          _isLoading = false;
        });
        return;
      }

      // Collect chat data for each user
      final List<ChatUserData> usersWithChatData = [];
      
      for (final userDoc in users) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final name = userData['displayName'] ?? userData['username'] ?? userData['name'] ?? 'No Name';
        final email = userData['email'] ?? '';
        final avatarUrl = userData['photoUrl'] ?? userData['photoURL'];
        final uid = userDoc.id;
        final chatId = _chatService.getChatId(currentUser.uid, uid);

        // Get last message for this chat
        try {
          final messagesSnapshot = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          String lastMessage = '';
          bool hasUnreadMessages = false;
          int lastMessageTimestamp = 0;

          if (messagesSnapshot.docs.isNotEmpty) {
            final lastMessageData = messagesSnapshot.docs.first.data();
            final senderId = lastMessageData['senderId'] as String?;
            final messageText = lastMessageData['text'] as String? ?? '';
            final messageType = lastMessageData['messageType'] as String? ?? 'text';
            lastMessageTimestamp = lastMessageData['timestamp'] as int? ?? 0;

            // Check if message is from other user (unread)
            if (senderId != currentUser.uid) {
              hasUnreadMessages = true;
            }

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

          usersWithChatData.add(ChatUserData(
            userDoc: userDoc,
            name: name,
            email: email,
            avatarUrl: avatarUrl,
            uid: uid,
            lastMessage: lastMessage,
            hasUnreadMessages: hasUnreadMessages,
            lastMessageTimestamp: lastMessageTimestamp,
          ));
        } catch (e) {
          // If there's an error getting chat data, still add the user
          usersWithChatData.add(ChatUserData(
            userDoc: userDoc,
            name: name,
            email: email,
            avatarUrl: avatarUrl,
            uid: uid,
            lastMessage: '',
            hasUnreadMessages: false,
            lastMessageTimestamp: 0,
          ));
        }
      }

      // Sort users: unread first, then by last message timestamp (newest first)
      usersWithChatData.sort((a, b) {
        // First sort by unread status (unread first)
        if (a.hasUnreadMessages != b.hasUnreadMessages) {
          return a.hasUnreadMessages ? -1 : 1;
        }
        // Then sort by last message timestamp (newest first)
        return b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp);
      });

      setState(() {
        _sortedUsers = usersWithChatData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users with chat data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start a Chat'),
        backgroundColor: AppColors.titleText,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadUsersWithChatData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sortedUsers.isEmpty
              ? const Center(child: Text('No other users found.'))
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
                                child: const Text(
                                  '1',
                                  style: TextStyle(
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              peerUid: userData.uid,
                              peerName: userData.name,
                            ),
                          ),
                        );
                      },
                    );
                  },
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

  ChatUserData({
    required this.userDoc,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.uid,
    required this.lastMessage,
    required this.hasUnreadMessages,
    required this.lastMessageTimestamp,
  });
} 