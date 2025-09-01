import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'user_search_screen.dart';
import '../services/chat_service.dart';
import '../styles/colors.dart';
import '../utils/responsive_utils.dart';
import 'dart:async';

class DMInboxScreen extends StatefulWidget {
  const DMInboxScreen({Key? key}) : super(key: key);

  @override
  State<DMInboxScreen> createState() => _DMInboxScreenState();
}

class _DMInboxScreenState extends State<DMInboxScreen> {
  final ChatService _chatService = ChatService();
  bool _isLoading = true;
  List<ConversationData> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    
    try {
      setState(() {
        _isLoading = true;
      });

      // Query conversations where the current user is a participant
      // Temporarily removed orderBy to avoid index requirement while it's building
      final conversationsQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      final List<ConversationData> conversations = [];

      for (final doc in conversationsQuery.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        
        // Get the other participant (not the current user)
        final otherParticipantId = participants.firstWhere(
          (uid) => uid != currentUser.uid,
          orElse: () => '',
        );

        if (otherParticipantId.isNotEmpty) {
          // Only include conversations that have actual messages (lastTimestamp > 0)
          final lastTimestamp = data['lastTimestamp'] ?? 0;
          if (lastTimestamp > 0) {
            // Get the other participant's user data
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(otherParticipantId)
                .get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
              final name = userData['displayName'] ?? 
                          userData['username'] ?? 
                          userData['name'] ?? 
                          'No Name';
              final avatarUrl = userData['photoUrl'] ?? userData['photoURL'];

              conversations.add(ConversationData(
                conversationId: doc.id,
                otherParticipantId: otherParticipantId,
                otherParticipantName: name,
                otherParticipantAvatar: avatarUrl,
                lastMessage: data['lastMessage'] ?? '',
                lastTimestamp: lastTimestamp,
                unreadCount: data['unreadCount'] ?? 0,
              ));
            }
          }
        }
      }

      // Sort conversations by lastTimestamp in descending order (most recent first)
      conversations.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading conversations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openChat(String conversationId, String peerName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          peerName: peerName,
        ),
      ),
    );
    // Refresh the list when returning from chat
    if (mounted) {
      await _loadConversations();
    }
  }

  void _openSearchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UserSearchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.titleText,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              await _loadConversations();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmptyState()
              : _buildConversationsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSearchScreen,
        backgroundColor: AppColors.titleText,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'New Message',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to start one',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: conversation.unreadCount > 0 
                ? Colors.blue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: conversation.unreadCount > 0
                ? Border.all(color: Colors.blue.withOpacity(0.3))
                : null,
          ),
          child: ListTile(
            leading: _buildAvatar(conversation.otherParticipantAvatar, conversation.otherParticipantName),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    conversation.otherParticipantName,
                    style: TextStyle(
                      fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      color: conversation.unreadCount > 0 ? Colors.black : Colors.black87,
                    ),
                  ),
                ),
                if (conversation.lastTimestamp > 0)
                  Text(
                    _formatTimestamp(conversation.lastTimestamp),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.lastMessage.isNotEmpty ? conversation.lastMessage : 'No messages yet',
                  style: TextStyle(
                    color: conversation.unreadCount > 0 ? Colors.black : Colors.grey,
                    fontWeight: conversation.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: conversation.unreadCount > 0
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            onTap: () {
              _openChat(conversation.conversationId, conversation.otherParticipantName);
            },
          ),
        );
      },
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
}

class ConversationData {
  final String conversationId;
  final String otherParticipantId;
  final String otherParticipantName;
  final String? otherParticipantAvatar;
  final String lastMessage;
  final int lastTimestamp;
  final int unreadCount;

  ConversationData({
    required this.conversationId,
    required this.otherParticipantId,
    required this.otherParticipantName,
    this.otherParticipantAvatar,
    required this.lastMessage,
    required this.lastTimestamp,
    required this.unreadCount,
  });
}
