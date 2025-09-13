import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import 'chat_service.dart';
import 'message_cache_service.dart';

class MessagePreloadService {
  static final ChatService _chatService = ChatService();
  static Timer? _preloadTimer;
  static final Set<String> _preloadedConversations = {};
  
  /// Start background preloading for active conversations
  static void startPreloading() {
    // Preload every 5 minutes
    _preloadTimer?.cancel();
    _preloadTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _preloadActiveConversations();
    });
    
    print('🔄 Started message preloading service');
  }
  
  /// Stop background preloading
  static void stopPreloading() {
    _preloadTimer?.cancel();
    _preloadTimer = null;
    print('⏹️ Stopped message preloading service');
  }
  
  /// Preload messages for active conversations
  static Future<void> _preloadActiveConversations() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Get recent conversations
      final conversations = await _chatService.getConversationsPaginated(
        currentUserId: currentUser.uid,
        limit: 10, // Preload top 10 conversations
      );
      
      for (final conv in conversations) {
        final conversationId = conv['conversationId'] as String;
        
        // Skip if already preloaded recently
        if (_preloadedConversations.contains(conversationId)) continue;
        
        // Preload messages for this conversation
        await _preloadConversationMessages(conversationId);
        _preloadedConversations.add(conversationId);
      }
      
      print('✅ Preloaded messages for ${conversations.length} conversations');
    } catch (e) {
      print('❌ Error preloading conversations: $e');
    }
  }
  
  /// Preload messages for a specific conversation
  static Future<void> _preloadConversationMessages(String conversationId) async {
    try {
      // Get recent messages (last 20)
      final result = await _chatService.getMessagesByConversationIdPaginated(
        conversationId,
        limit: 20,
      );
      
      final messages = List<ChatMessage>.from(result['messages']);
      if (messages.isNotEmpty) {
        await MessageCacheService.cacheMessages(conversationId, messages);
        print('📱 Preloaded ${messages.length} messages for conversation $conversationId');
      }
    } catch (e) {
      print('❌ Error preloading messages for conversation $conversationId: $e');
    }
  }
  
  /// Preload messages for a specific conversation (manual trigger)
  static Future<void> preloadConversation(String conversationId) async {
    await _preloadConversationMessages(conversationId);
    _preloadedConversations.add(conversationId);
  }
  
  /// Clear preloaded conversation cache
  static void clearPreloadedCache() {
    _preloadedConversations.clear();
    print('🗑️ Cleared preloaded conversation cache');
  }
  
  /// Get preload statistics
  static Map<String, dynamic> getPreloadStats() {
    return {
      'isRunning': _preloadTimer?.isActive ?? false,
      'preloadedConversations': _preloadedConversations.length,
      'preloadedIds': _preloadedConversations.toList(),
    };
  }
}
