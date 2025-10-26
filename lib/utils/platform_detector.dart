import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class PlatformDetector {
  // Cache for platform detection
  static bool? _cachedIsWeb;
  static bool? _cachedIsPWA;
  static String? _cachedPlatformInfo;
  
  /// Check if running on web
  static bool get isWeb {
    _cachedIsWeb ??= kIsWeb;
    return _cachedIsWeb!;
  }
  
  /// Check if running on mobile (Android/iOS, not web)
  static bool get isMobile => !isWeb && (Platform.isAndroid || Platform.isIOS);
  
  /// Check if running on Android specifically
  static bool get isAndroid => !isWeb && Platform.isAndroid;
  
  /// Check if running on iOS specifically
  static bool get isIOS => !isWeb && Platform.isIOS;
  
  /// Check if running on desktop (Windows/Mac/Linux)
  static bool get isDesktop => !isWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  
  /// Detect if running as PWA (Progressive Web App in standalone mode)
  static bool get isPWA {
    if (!isWeb) return false;
    
    if (_cachedIsPWA != null) return _cachedIsPWA!;
    
    try {
      // PWA detection logic
      // This is set via a global variable from JavaScript
      return _cachedIsPWA ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Set PWA mode dynamically from JavaScript
  static void setPWAMode(bool isPWA) {
    _cachedIsPWA = isPWA;
  }
  
  /// Get detailed platform information
  static String getPlatformInfo() {
    if (_cachedPlatformInfo != null) return _cachedPlatformInfo!;
    
    final info = <String>[];
    
    if (isWeb) {
      info.add('Web');
      if (isPWA) info.add('PWA');
    } else if (isAndroid) {
      info.add('Android');
    } else if (isIOS) {
      info.add('iOS');
    } else if (Platform.isWindows) {
      info.add('Windows');
    } else if (Platform.isMacOS) {
      info.add('macOS');
    } else if (Platform.isLinux) {
      info.add('Linux');
    }
    
    _cachedPlatformInfo = info.join(' • ');
    return _cachedPlatformInfo!;
  }
  
  /// Log platform information (useful for debugging)
  static void logPlatformInfo() {
    print('🔍 Platform Detection:');
    print('   • Platform: ${getPlatformInfo()}');
    print('   • isWeb: $isWeb');
    print('   • isPWA: $isPWA');
    print('   • isMobile: $isMobile');
    print('   • isAndroid: $isAndroid');
    print('   • supportsVideoCompression: $supportsVideoCompression');
    print('   • supportsVideoThumbnails: $supportsVideoThumbnails');
  }
  
  /// Get platform name as string
  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
  
  /// Check if video compression is supported
  static bool get supportsVideoCompression {
    return isMobile; // Only mobile platforms support video compression
  }
  
  /// Check if video thumbnails are supported
  static bool get supportsVideoThumbnails {
    return isMobile; // Only mobile platforms can extract thumbnails
  }
  
  /// Check if native video player is available
  static bool get supportsNativeVideoPlayer {
    return isMobile; // Only mobile platforms have native video player
  }
  
  /// Get recommended video quality based on platform
  static String get recommendedVideoQuality {
    if (isWeb) return 'High (no compression)';
    if (isMobile) return 'Medium (compressed)';
    return 'Default';
  }
}

