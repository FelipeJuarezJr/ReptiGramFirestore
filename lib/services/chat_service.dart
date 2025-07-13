import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import '../models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  const ChatService();

  String getChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join("_");
  }

  Stream<List<ChatMessage>> getMessages(String uid1, String uid2) {
    final chatId = getChatId(uid1, uid2);
    print('Getting messages for chatId: $chatId (uid1: $uid1, uid2: $uid2)');
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
          print('Received ${snap.docs.length} messages from Firestore for chatId: $chatId');
          final messages = snap.docs.map((doc) {
            final data = doc.data();
            print('Message data: $data');
            return ChatMessage.fromMap(data);
          }).toList();
          return messages;
        });
  }

  // Mark messages as read when user opens the chat
  Future<void> markMessagesAsRead(String currentUserId, String peerUserId) async {
    try {
      final chatId = getChatId(currentUserId, peerUserId);
      
      // Get all messages from the peer user that don't have current user in readBy
      final unreadMessages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: peerUserId)
          .get();

      // Mark each message as read by the current user
      final batch = _db.batch();
      int updatedCount = 0;
      
      for (final doc in unreadMessages.docs) {
        final data = doc.data();
        final readBy = data['readBy'] as List<dynamic>?;
        
        // If readBy doesn't exist or current user is not in the list, mark as read
        if (readBy == null || !readBy.contains(currentUserId)) {
          final updatedReadBy = readBy != null 
              ? List<String>.from(readBy) 
              : <String>[];
          
          if (!updatedReadBy.contains(currentUserId)) {
            updatedReadBy.add(currentUserId);
            batch.update(doc.reference, {'readBy': updatedReadBy});
            updatedCount++;
          }
        }
      }
      
      if (updatedCount > 0) {
        await batch.commit();
        print('Marked $updatedCount messages as read for chat $chatId');
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get unread message count for a specific chat
  Future<int> getUnreadMessageCount(String currentUserId, String peerUserId) async {
    try {
      final chatId = getChatId(currentUserId, peerUserId);
      
      final unreadMessages = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: peerUserId)
          .where('readBy', whereNotIn: [currentUserId])
          .get();
      
      return unreadMessages.docs.length;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }

  Future<void> sendMessage(String uid1, String uid2, String text) async {
    try {
      final chatId = getChatId(uid1, uid2);
      final messageId = _uuid.v4();
      final message = ChatMessage(
        id: messageId,
        text: text,
        senderId: uid1,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        readBy: [uid1], // Sender has read their own message
      );
      
      print('Sending message: chatId=$chatId, messageId=$messageId, text=$text');
      print('Message data: ${message.toMap()}');
      
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      print('Message sent successfully to Firestore');
      // Cloud Functions will automatically send the notification
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> sendImageMessage(String uid1, String uid2, Uint8List imageBytes, String fileName) async {
    final chatId = getChatId(uid1, uid2);
    final messageId = _uuid.v4();
    
    // Upload image to Firebase Storage
    final storageRef = _storage
        .ref()
        .child('chat_images')
        .child(chatId)
        .child('$messageId.jpg');
    
    await storageRef.putData(imageBytes);
    final downloadUrl = await storageRef.getDownloadURL();
    
    // Create message
    final message = ChatMessage(
      id: messageId,
      text: 'Image',
      senderId: uid1,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      fileUrl: downloadUrl,
      messageType: MessageType.image,
      fileName: fileName,
      fileSize: imageBytes.length,
      readBy: [uid1], // Sender has read their own message
    );
    
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(message.toMap());

    // Cloud Functions will automatically send the notification
  }

  Future<void> sendFileMessage(String uid1, String uid2, Uint8List fileBytes, String fileName) async {
    final chatId = getChatId(uid1, uid2);
    final messageId = _uuid.v4();
    
          // Upload file to Firebase Storage
      final storageRef = _storage
          .ref()
          .child('chat_files')
          .child(chatId)
          .child('${messageId}_$fileName');
    
    await storageRef.putData(fileBytes);
    final downloadUrl = await storageRef.getDownloadURL();
    
    // Create message
    final message = ChatMessage(
      id: messageId,
      text: 'File: $fileName',
      senderId: uid1,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      fileUrl: downloadUrl,
      messageType: MessageType.file,
      fileName: fileName,
      fileSize: fileBytes.length,
      readBy: [uid1], // Sender has read their own message
    );
    
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(message.toMap());

    // Cloud Functions will automatically send the notification
  }


} 