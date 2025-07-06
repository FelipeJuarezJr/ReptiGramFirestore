import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../styles/colors.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final chatService = ChatService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Info'),
        backgroundColor: AppColors.titleText,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current User',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('UID: ${currentUser.uid}'),
                    Text('Email: ${currentUser.email}'),
                    Text('Display Name: ${currentUser.displayName}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'All Users',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        
                        final users = snapshot.data!.docs;
                        return Column(
                          children: users.map((user) {
                            final userData = user.data() as Map<String, dynamic>;
                            final isCurrentUser = user.id == currentUser.uid;
                            return ListTile(
                              title: Text(
                                '${userData['username'] ?? 'No name'} ${isCurrentUser ? '(YOU)' : ''}',
                                style: TextStyle(
                                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text('UID: ${user.id}'),
                              trailing: isCurrentUser 
                                ? const Icon(Icons.person, color: Colors.blue)
                                : const Icon(Icons.person_outline),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Chat',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        
                        final users = snapshot.data!.docs
                            .where((user) => user.id != currentUser.uid)
                            .toList();
                        
                        if (users.isEmpty) {
                          return const Text('No other users found');
                        }
                        
                        final otherUser = users.first;
                        final otherUserData = otherUser.data() as Map<String, dynamic>;
                        final chatId = chatService.getChatId(currentUser.uid, otherUser.id);
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chat with: ${otherUserData['username'] ?? 'Unknown'}'),
                            Text('Chat ID: $chatId'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await chatService.sendMessage(
                                    currentUser.uid,
                                    otherUser.id,
                                    'Test message from ${currentUser.displayName} at ${DateTime.now()}',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Test message sent!')),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                              child: const Text('Send Test Message'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 