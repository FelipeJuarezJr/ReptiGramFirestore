import 'dart:async';
import 'message_cache_service.dart';
import 'avatar_cache_service.dart';

class MessageCleanupService {
  static Timer? _cleanupTimer;
  static const int _cleanupIntervalHours = 24; // Run cleanup every 24 hours
  static const int _maxMessageAgeDays = 30; // Keep messages for 30 days
  static const int _maxCacheSizeMB = 50; // Max cache size in MB
  
  /// Start automatic cleanup service
  static void startCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      Duration(hours: _cleanupIntervalHours),
      (timer) => performCleanup(),
    );
    
    print('🧹 Started message cleanup service');
  }
  
  /// Stop automatic cleanup service
  static void stopCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    print('⏹️ Stopped message cleanup service');
  }
  
  /// Perform comprehensive cleanup
  static Future<void> performCleanup() async {
    try {
      print('🧹 Starting message cleanup...');
      
      // Clean up expired avatar caches
      await AvatarCacheService.cleanupExpiredCache();
      
      // Clean up old message caches
      await _cleanupOldMessageCaches();
      
      // Clean up oversized caches
      await _cleanupOversizedCaches();
      
      print('✅ Message cleanup completed');
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }
  
  /// Clean up old message caches
  static Future<void> _cleanupOldMessageCaches() async {
    try {
      // This would require access to SharedPreferences to check timestamps
      // For now, we'll implement a simple cleanup based on cache size
      final cacheSize = await MessageCacheService.getCacheSize();
      
      if (cacheSize > 20) { // If more than 20 cached conversations
        print('🧹 Cleaning up old message caches (${cacheSize} conversations cached)');
        // In a real implementation, you'd check timestamps and remove old ones
        // For now, we'll just log the current cache size
      }
    } catch (e) {
      print('❌ Error cleaning up old message caches: $e');
    }
  }
  
  /// Clean up oversized caches
  static Future<void> _cleanupOversizedCaches() async {
    try {
      // Get cache statistics
      final avatarStats = await AvatarCacheService.getCacheStats();
      final messageCacheSize = await MessageCacheService.getCacheSize();
      
      print('📊 Cache stats - Messages: $messageCacheSize, Avatars: ${avatarStats['active']} active, ${avatarStats['expired']} expired');
      
      // If caches are too large, clean them up
      if (messageCacheSize > 50 || avatarStats['active']! > 100) {
        print('🧹 Caches are oversized, performing cleanup...');
        
        // Clear expired avatar caches
        if (avatarStats['expired']! > 0) {
          await AvatarCacheService.clearAllCache();
        }
      }
    } catch (e) {
      print('❌ Error cleaning up oversized caches: $e');
    }
  }
  
  /// Manual cleanup for specific conversation
  static Future<void> cleanupConversation(String conversationId) async {
    try {
      await MessageCacheService.clearCache(conversationId);
      print('🗑️ Cleaned up cache for conversation $conversationId');
    } catch (e) {
      print('❌ Error cleaning up conversation $conversationId: $e');
    }
  }
  
  /// Emergency cleanup - clear all caches
  static Future<void> emergencyCleanup() async {
    try {
      print('🚨 Performing emergency cleanup...');
      
      await MessageCacheService.clearAllCache();
      await AvatarCacheService.clearAllCache();
      
      print('✅ Emergency cleanup completed');
    } catch (e) {
      print('❌ Error during emergency cleanup: $e');
    }
  }
  
  /// Get cleanup statistics
  static Future<Map<String, dynamic>> getCleanupStats() async {
    try {
      final avatarStats = await AvatarCacheService.getCacheStats();
      final messageCacheSize = await MessageCacheService.getCacheSize();
      
      return {
        'isRunning': _cleanupTimer?.isActive ?? false,
        'messageCacheSize': messageCacheSize,
        'avatarCacheStats': avatarStats,
        'cleanupIntervalHours': _cleanupIntervalHours,
        'maxMessageAgeDays': _maxMessageAgeDays,
        'maxCacheSizeMB': _maxCacheSizeMB,
      };
    } catch (e) {
      print('❌ Error getting cleanup stats: $e');
      return {
        'isRunning': false,
        'error': e.toString(),
      };
    }
  }
}
