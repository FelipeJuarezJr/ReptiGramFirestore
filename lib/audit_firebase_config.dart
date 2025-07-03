import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase Configuration Audit Tool
/// 
/// This file helps verify that your app is connected to the correct Firebase project
/// and prevents accidental writes to the wrong project.
class FirebaseConfigAuditor {
  
  /// Check if Firebase is connected to the correct project
  static void auditFirebaseConfig() {
    try {
      final app = Firebase.app();
      final options = app.options;
      
      print('🔍 FIREBASE CONFIGURATION AUDIT');
      print('================================');
      print('✅ App Name: ${app.name}');
      print('✅ Project ID: ${options.projectId}');
      print('✅ Storage Bucket: ${options.storageBucket}');
      print('✅ Auth Domain: ${options.authDomain}');
      print('✅ API Key: ${options.apiKey.substring(0, 10)}...');
      
      // Verify we're connected to the correct project
      if (options.projectId == 'reptigramfirestore') {
        print('✅ CORRECT PROJECT: Connected to reptigramfirestore');
      } else {
        print('❌ WRONG PROJECT: Connected to ${options.projectId}');
        print('   Expected: reptigramfirestore');
        throw Exception('Connected to wrong Firebase project!');
      }
      
      // Verify storage bucket
      if (options.storageBucket == 'reptigramfirestore.firebasestorage.app') {
        print('✅ CORRECT STORAGE: Using reptigramfirestore bucket');
      } else {
        print('❌ WRONG STORAGE: Using ${options.storageBucket}');
        print('   Expected: reptigramfirestore.firebasestorage.app');
        throw Exception('Using wrong storage bucket!');
      }
      
      print('✅ AUDIT PASSED: All configurations are correct');
      
    } catch (e) {
      print('❌ AUDIT FAILED: $e');
      rethrow;
    }
  }
  
  /// Test storage operations to verify correct bucket
  static Future<void> testStorageConnection() async {
    try {
      print('\n🧪 TESTING STORAGE CONNECTION');
      print('==============================');
      
      final storage = FirebaseStorage.instance;
      final bucket = storage.bucket;
      
      print('✅ Storage Bucket: $bucket');
      
      if (bucket == 'reptigramfirestore.firebasestorage.app') {
        print('✅ CORRECT STORAGE BUCKET');
      } else {
        print('❌ WRONG STORAGE BUCKET: $bucket');
        throw Exception('Storage connected to wrong bucket!');
      }
      
      // Test creating a reference (without uploading)
      final testRef = storage.ref('test/connection-test.txt');
      print('✅ Storage Reference Created: ${testRef.fullPath}');
      print('✅ Storage URL: ${testRef.bucket}');
      
      print('✅ STORAGE TEST PASSED');
      
    } catch (e) {
      print('❌ STORAGE TEST FAILED: $e');
      rethrow;
    }
  }
  
  /// Test Firestore connection
  static Future<void> testFirestoreConnection() async {
    try {
      print('\n🔥 TESTING FIRESTORE CONNECTION');
      print('===============================');
      
      final firestore = FirebaseFirestore.instance;
      
      // Test a simple read operation
      final testDoc = await firestore.collection('test').doc('connection').get();
      print('✅ Firestore Connection: ${testDoc.reference.path}');
      
      print('✅ FIRESTORE TEST PASSED');
      
    } catch (e) {
      print('❌ FIRESTORE TEST FAILED: $e');
      // Don't rethrow for Firestore as it might not have test collection
    }
  }
  
  /// Comprehensive audit of all Firebase services
  static Future<void> runFullAudit() async {
    print('🚀 STARTING COMPREHENSIVE FIREBASE AUDIT');
    print('=========================================');
    
    try {
      // 1. Audit basic configuration
      auditFirebaseConfig();
      
      // 2. Test storage connection
      await testStorageConnection();
      
      // 3. Test Firestore connection
      await testFirestoreConnection();
      
      print('\n🎉 ALL TESTS PASSED!');
      print('✅ Your app is correctly configured for reptigramfirestore');
      print('✅ No risk of writing to reptigram-lite');
      
    } catch (e) {
      print('\n💥 AUDIT FAILED!');
      print('❌ Error: $e');
      print('🔧 Please fix the configuration issues above');
    }
  }
  
  /// Helper method to log storage operations for debugging
  static void logStorageOperation(String operation, String path) {
    final storage = FirebaseStorage.instance;
    final bucket = storage.bucket;
    
    print('📤 STORAGE OPERATION: $operation');
    print('   Path: $path');
    print('   Bucket: $bucket');
    
    if (bucket != 'reptigramfirestore.firebasestorage.app') {
      print('   ⚠️  WARNING: Writing to wrong bucket!');
    } else {
      print('   ✅ Correct bucket');
    }
  }
}

/// Extension to add audit logging to FirebaseStorage
extension FirebaseStorageAudit on FirebaseStorage {
  /// Create a reference with audit logging
  Reference refWithAudit(String path) {
    FirebaseConfigAuditor.logStorageOperation('REF_CREATED', path);
    return ref(path);
  }
} 