import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class MessageCacheService {
  static const String _cacheKeyPrefix = 'messages_cache_';
  static const int _maxCachedMessages = 100; // Limit cache size
  
  /// Cache messages for a conversation
  static Future<void> cacheMessages(String conversationId, List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert messages to JSON
      final messagesJson = messages.map((msg) => msg.toMap()).toList();
      final messagesString = jsonEncode(messagesJson);
      
      // Store in cache with timestamp
      final cacheKey = '$_cacheKeyPrefix$conversationId';
      await prefs.setString(cacheKey, messagesString);
      await prefs.setInt('${cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print('✅ Cached ${messages.length} messages for conversation $conversationId');
    } catch (e) {
      print('❌ Error caching messages: $e');
    }
  }
  
  /// Get cached messages for a conversation
  static Future<List<ChatMessage>?> getCachedMessages(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$conversationId';
      
      final messagesString = prefs.getString(cacheKey);
      if (messagesString == null) return null;
      
      // Check if cache is older than 1 hour
      final timestamp = prefs.getInt('${cacheKey}_timestamp') ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge > 3600000) { // 1 hour in milliseconds
        print('🗑️ Cache expired for conversation $conversationId');
        await clearCache(conversationId);
        return null;
      }
      
      // Parse messages from JSON
      final messagesJson = jsonDecode(messagesString) as List;
      final messages = messagesJson.map((json) => ChatMessage.fromMap(json)).toList();
      
      print('📱 Retrieved ${messages.length} cached messages for conversation $conversationId');
      return messages;
    } catch (e) {
      print('❌ Error retrieving cached messages: $e');
      return null;
    }
  }
  
  /// Add a new message to cache
  static Future<void> addMessageToCache(String conversationId, ChatMessage message) async {
    try {
      final cachedMessages = await getCachedMessages(conversationId) ?? [];
      
      // Add new message at the beginning (most recent first)
      cachedMessages.insert(0, message);
      
      // Limit cache size
      if (cachedMessages.length > _maxCachedMessages) {
        cachedMessages.removeRange(_maxCachedMessages, cachedMessages.length);
      }
      
      await cacheMessages(conversationId, cachedMessages);
    } catch (e) {
      print('❌ Error adding message to cache: $e');
    }
  }
  
  /// Clear cache for a specific conversation
  static Future<void> clearCache(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$conversationId';
      
      await prefs.remove(cacheKey);
      await prefs.remove('${cacheKey}_timestamp');
      
      print('🗑️ Cleared cache for conversation $conversationId');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }
  
  /// Clear all message caches
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          await prefs.remove(key);
        }
      }
      
      print('🗑️ Cleared all message caches');
    } catch (e) {
      print('❌ Error clearing all caches: $e');
    }
  }
  
  /// Get cache size for monitoring
  static Future<int> getCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int count = 0;
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix) && !key.endsWith('_timestamp')) {
          count++;
        }
      }
      
      return count;
    } catch (e) {
      print('❌ Error getting cache size: $e');
      return 0;
    }
  }
}
