import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../services/firestore_service.dart';
import '../services/chat_service.dart';
import '../styles/colors.dart';

class UserListScreen extends StatelessWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final chatService = ChatService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start a Chat'),
        backgroundColor: AppColors.titleText,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.users.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          // Filter out current user
          final users = snapshot.data!.docs.where((doc) {
            final userData = doc.data() as Map<String, dynamic>;
            final userEmail = userData['email'] ?? '';
            return doc.id != currentUser.uid && userEmail != currentUser.email;
          }).toList();

          if (users.isEmpty) {
            return const Center(child: Text('No other users found.'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final doc = users[index];
              final userData = doc.data() as Map<String, dynamic>;
              final name = userData['displayName'] ?? userData['username'] ?? userData['name'] ?? 'No Name';
              final email = userData['email'] ?? '';
              final avatarUrl = userData['photoUrl'] ?? userData['photoURL'];
              final uid = doc.id;
              final chatId = chatService.getChatId(currentUser.uid, uid);

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, messageSnapshot) {
                  String lastMessage = '';
                  bool hasUnreadMessages = false;

                  if (messageSnapshot.hasData && messageSnapshot.data!.docs.isNotEmpty) {
                    final lastMessageData = messageSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                    final senderId = lastMessageData['senderId'] as String?;
                    final messageText = lastMessageData['text'] as String? ?? '';
                    final messageType = lastMessageData['messageType'] as String? ?? 'text';

                    // Check if message is from other user and unread
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

                  return ListTile(
                    leading: Stack(
                      children: [
                        _buildAvatar(avatarUrl, name),
                        if (hasUnreadMessages)
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
                      name,
                      style: TextStyle(
                        fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                      style: TextStyle(
                        color: hasUnreadMessages ? Colors.black : Colors.grey,
                        fontWeight: hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            peerUid: uid,
                            peerName: name,
                          ),
                        ),
                      );
                    },
                  );
                },
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