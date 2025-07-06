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

          // Group users by email and filter out current user
          final Map<String, Map<String, dynamic>> uniqueUsers = {};
          final currentUserEmail = currentUser.email ?? '';
          
          for (final doc in snapshot.data!.docs) {
            final userData = doc.data() as Map<String, dynamic>;
            final userEmail = userData['email'] ?? '';
            final userId = doc.id;
            
            // Skip current user
            if (userId == currentUser.uid || userEmail == currentUserEmail) {
              continue;
            }
            
            // If we haven't seen this email before, or if this user is more recent
            if (!uniqueUsers.containsKey(userEmail) || 
                (userData['lastLogin'] != null && 
                 (uniqueUsers[userEmail]!['lastLogin'] == null || 
                  userData['lastLogin'].toDate().isAfter(uniqueUsers[userEmail]!['lastLogin']?.toDate() ?? DateTime(1900))))) {
              uniqueUsers[userEmail] = {
                'uid': userId,
                'email': userEmail,
                'username': userData['username'] ?? userData['name'] ?? 'No Name',
                'displayName': userData['displayName'] ?? userData['username'] ?? 'No Name',
                'photoUrl': userData['photoUrl'] ?? userData['photoURL'],
                'lastLogin': userData['lastLogin'],
                'createdAt': userData['createdAt'],
              };
            }
          }

          final users = uniqueUsers.values.toList();
          
          // Sort users by display name
          users.sort((a, b) => (a['displayName'] as String).compareTo(b['displayName'] as String));

          if (users.isEmpty) {
            return const Center(child: Text('No other users found.'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final name = user['displayName'] as String;
              final email = user['email'] as String;
              final avatarUrl = user['photoUrl'] as String?;
              final uid = user['uid'] as String;
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
                  int unreadCount = 0;
                  bool hasUnreadMessages = false;
                  DateTime? lastMessageTime;

                  if (messageSnapshot.hasData && messageSnapshot.data!.docs.isNotEmpty) {
                    final lastMessageData = messageSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                    final senderId = lastMessageData['senderId'] as String?;
                    final messageText = lastMessageData['text'] as String? ?? '';
                    final messageType = lastMessageData['messageType'] as String? ?? 'text';
                    final timestamp = lastMessageData['timestamp'] as int?;
                    
                    if (timestamp != null) {
                      lastMessageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
                    }

                    // Check if message is from other user and unread
                    if (senderId != currentUser.uid) {
                      // For now, consider all messages from others as unread
                      // In a real app, you'd track read status
                      hasUnreadMessages = true;
                      unreadCount = 1; // Simplified - in real app, count actual unread messages
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
                              child: Text(
                                unreadCount.toString(),
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
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (lastMessageTime != null)
                          Text(
                            _formatTime(lastMessageTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnreadMessages ? Colors.red : Colors.grey,
                              fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                          style: TextStyle(
                            color: hasUnreadMessages ? Colors.black : Colors.grey,
                            fontWeight: hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
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
      // Show app logo as fallback for no avatar
      return CircleAvatar(
        backgroundImage: const AssetImage('assets/img/reptiGramLogo.png'),
      );
    }

    // Show network image with proper error handling
    return CircleAvatar(
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (exception, stackTrace) {
        // Handle image loading errors by showing app logo
        print('Avatar image failed to load: $avatarUrl, error: $exception');
      },
      child: null, // Remove the preemptive fallback for Google URLs
    );
  }

  Widget _buildFallbackAvatar() {
    return CircleAvatar(
      backgroundImage: const AssetImage('assets/img/reptiGramLogo.png'),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
} 