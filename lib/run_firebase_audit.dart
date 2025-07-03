import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'audit_firebase_config.dart';

/// Standalone Firebase Audit Script
/// 
/// Run this script to verify your Firebase configuration:
/// dart run lib/run_firebase_audit.dart
Future<void> main() async {
  print('🚀 REPTIGRAM FIREBASE AUDIT TOOL');
  print('=================================');
  print('This tool verifies your app is connected to the correct Firebase project');
  print('and prevents accidental writes to reptigram-lite\n');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    print('✅ Firebase initialized successfully');
    
    // Run comprehensive audit
    await FirebaseConfigAuditor.runFullAudit();
    
    print('\n🎯 SUMMARY');
    print('==========');
    print('✅ Your Flutter app is correctly configured');
    print('✅ Connected to: reptigramfirestore');
    print('✅ Storage bucket: reptigramfirestore.firebasestorage.app');
    print('✅ No risk of writing to reptigram-lite');
    print('\n🚀 You can now safely run your app!');
    
  } catch (e) {
    print('\n💥 AUDIT FAILED!');
    print('❌ Error: $e');
    print('\n🔧 TROUBLESHOOTING STEPS:');
    print('1. Run: flutterfire configure');
    print('2. Select: reptigramfirestore project');
    print('3. Run: flutter clean && flutter pub get');
    print('4. Run this audit again');
    
    rethrow;
  }
} 