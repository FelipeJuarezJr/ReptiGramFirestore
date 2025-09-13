import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarCacheService {
  static const String _cacheKeyPrefix = 'avatar_cache_';
  static const int _maxCacheSize = 50; // Limit cache size
  static const int _cacheExpirationHours = 24; // Cache expires after 24 hours
  
  /// Cache an avatar URL for a user
  static Future<void> cacheAvatarUrl(String userId, String? avatarUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cacheKey = '$_cacheKeyPrefix$userId';
      final cacheData = {
        'url': avatarUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(cacheKey, jsonEncode(cacheData));
      
      print('✅ Cached avatar URL for user $userId');
    } catch (e) {
      print('❌ Error caching avatar URL: $e');
    }
  }
  
  /// Get cached avatar URL for a user
  static Future<String?> getCachedAvatarUrl(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$userId';
      
      final cacheString = prefs.getString(cacheKey);
      if (cacheString == null) return null;
      
      final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      
      // Check if cache is expired
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      final expirationMs = _cacheExpirationHours * 60 * 60 * 1000;
      
      if (cacheAge > expirationMs) {
        print('🗑️ Avatar cache expired for user $userId');
        await _clearUserCache(userId);
        return null;
      }
      
      final avatarUrl = cacheData['url'] as String?;
      print('📱 Retrieved cached avatar URL for user $userId');
      return avatarUrl;
    } catch (e) {
      print('❌ Error retrieving cached avatar URL: $e');
      return null;
    }
  }
  
  /// Clear cache for a specific user
  static Future<void> _clearUserCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$userId';
      await prefs.remove(cacheKey);
    } catch (e) {
      print('❌ Error clearing user avatar cache: $e');
    }
  }
  
  /// Clear all avatar caches
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          await prefs.remove(key);
        }
      }
      
      print('🗑️ Cleared all avatar caches');
    } catch (e) {
      print('❌ Error clearing all avatar caches: $e');
    }
  }
  
  /// Clean up expired caches
  static Future<void> cleanupExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final expirationMs = _cacheExpirationHours * 60 * 60 * 1000;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          final cacheString = prefs.getString(key);
          if (cacheString != null) {
            try {
              final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
              final timestamp = cacheData['timestamp'] as int;
              
              if (now - timestamp > expirationMs) {
                await prefs.remove(key);
                print('🗑️ Cleaned up expired avatar cache: $key');
              }
            } catch (e) {
              // Remove corrupted cache entry
              await prefs.remove(key);
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error cleaning up avatar cache: $e');
    }
  }
  
  /// Get cache statistics
  static Future<Map<String, int>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int totalCaches = 0;
      int expiredCaches = 0;
      final expirationMs = _cacheExpirationHours * 60 * 60 * 1000;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          totalCaches++;
          
          final cacheString = prefs.getString(key);
          if (cacheString != null) {
            try {
              final cacheData = jsonDecode(cacheString) as Map<String, dynamic>;
              final timestamp = cacheData['timestamp'] as int;
              
              if (now - timestamp > expirationMs) {
                expiredCaches++;
              }
            } catch (e) {
              // Count corrupted entries as expired
              expiredCaches++;
            }
          }
        }
      }
      
      return {
        'total': totalCaches,
        'expired': expiredCaches,
        'active': totalCaches - expiredCaches,
      };
    } catch (e) {
      print('❌ Error getting cache stats: $e');
      return {'total': 0, 'expired': 0, 'active': 0};
    }
  }
}
