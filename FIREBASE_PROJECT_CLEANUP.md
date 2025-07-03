# 🔒 Firebase Project Cleanup Guide

## 🚨 CRITICAL: Prevent Writing to reptigram-lite

This guide ensures your Flutter app **ONLY** writes to `reptigramfirestore` and **NEVER** to `reptigram-lite`.

## ✅ Current Status

- ✅ All "reptigram-lite" references removed from code
- ✅ `firebase_options.dart` correctly configured for `reptigramfirestore`
- ✅ `google-services.json` updated for `reptigramfirestore`
- ✅ Audit tools created to prevent future issues

## 🔍 Verification Steps

### 1. Run Firebase Audit
```bash
# Run the audit tool to verify configuration
dart run lib/run_firebase_audit.dart
```

Expected output:
```
✅ CORRECT PROJECT: Connected to reptigramfirestore
✅ CORRECT STORAGE: Using reptigramfirestore bucket
✅ ALL TESTS PASSED!
```

### 2. Check App Startup Logs
When you run your app, you should see:
```
✅ Firebase configuration verified - connected to correct project
```

### 3. Verify Storage Operations
All storage operations should use:
- **Bucket**: `reptigramfirestore.firebasestorage.app`
- **Path**: `photos/{userId}/{photoId}`

## 🛡️ Safety Measures Implemented

### 1. Startup Audit
Your app now audits Firebase configuration on startup and warns if connected to wrong project.

### 2. Storage Operation Logging
The audit tool logs all storage operations to help you verify correct bucket usage.

### 3. Configuration Validation
All Firebase configurations are validated against expected values.

## 🔧 If Audit Fails

### Step 1: Reconfigure Firebase
```bash
flutterfire configure
```
- Select: `reptigramfirestore`
- Platforms: Web, Android, iOS (as needed)

### Step 2: Clean Build
```bash
flutter clean
flutter pub get
```

### Step 3: Verify Configuration
```bash
dart run lib/run_firebase_audit.dart
```

## 📋 Pre-Launch Checklist

Before running your app, verify:

- [ ] `dart run lib/run_firebase_audit.dart` passes
- [ ] App startup shows "✅ Firebase configuration verified"
- [ ] No errors about wrong project
- [ ] Storage operations log correct bucket

## 🚫 What NOT to Do

❌ **Never hardcode URLs** like:
```dart
// WRONG - Don't do this
"https://firebasestorage.googleapis.com/v0/b/reptigram-lite..."
```

✅ **Always use dynamic references**:
```dart
// CORRECT - Do this
final ref = FirebaseStorage.instance.ref('photos/$userId/$photoId');
```

## 🔍 Monitoring Storage Operations

Add this to your storage upload code for debugging:
```dart
import 'audit_firebase_config.dart';

// Before uploading
FirebaseConfigAuditor.logStorageOperation('UPLOAD', 'photos/$userId/$photoId');
```

## 🆘 Emergency Contacts

If you accidentally write to reptigram-lite:
1. **STOP** the app immediately
2. Run the audit tool to identify the issue
3. Check for hardcoded URLs or wrong configuration
4. Fix the issue and run audit again

## 📊 Project Configuration Summary

| Setting | Value |
|---------|-------|
| **Project ID** | `reptigramfirestore` |
| **Storage Bucket** | `reptigramfirestore.firebasestorage.app` |
| **Auth Domain** | `reptigramfirestore.firebaseapp.com` |
| **Database URL** | `https://reptigramfirestore-default-rtdb.firebaseio.com` |

## 🎯 Success Criteria

Your app is safe when:
- ✅ Audit tool passes all checks
- ✅ App startup shows correct project
- ✅ All storage operations use correct bucket
- ✅ No hardcoded reptigram-lite references

---

**Remember**: Always run the audit tool before deploying or making changes to ensure you're writing to the correct project! 