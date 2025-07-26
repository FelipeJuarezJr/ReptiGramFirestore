# Chat Notification Troubleshooting Guide

## Issue Summary
Chat messages are not being notified to users on both website and PWA on mobile devices.

## Root Cause Found ✅
The Cloud Function `sendChatNotification` was failing because it was looking for a separate chat document that doesn't exist. The chat structure only contains messages directly under the chat ID.

## Fixes Applied ✅

### 1. Fixed Cloud Function
- **File**: `functions/index.js`
- **Issue**: Function was looking for `chats/{chatId}` document
- **Fix**: Removed the chat document check since messages are stored directly under `chats/{chatId}/messages/{messageId}`
- **Added**: Web push notification support with proper configuration

### 2. Updated Service Worker
- **File**: `web/firebase-messaging-sw.js`
- **Issue**: Firebase SDK version mismatch (9.0.0 vs 10.8.0)
- **Fix**: Updated to version 10.8.0 to match main app
- **Added**: Better notification options (requireInteraction, tag, renotify)

### 3. Deployed Updated Functions
- Deleted old `onNotificationOpen` function
- Deployed updated `sendChatNotification` and `updateFcmToken` functions

## How to Test Notifications

### 1. Web Testing
```bash
# Build and serve the web app
flutter clean
flutter pub get
flutter build web
firebase serve --only hosting
```

### 2. Mobile Testing
```bash
# For Android
flutter run -d android

# For iOS
flutter run -d ios
```

### 3. Manual Testing Steps
1. **Login with two different users** (use different browsers or devices)
2. **Grant notification permissions** when prompted
3. **Send a message** from one user to another
4. **Check for notifications** on the recipient's device
5. **Verify FCM tokens** are saved in Firestore

## Debugging Commands

### Check Cloud Function Logs
```bash
firebase functions:log --only sendChatNotification
```

### Check User FCM Tokens
```bash
# Run the debug script (requires serviceAccountKey.json)
node debug_notifications.js
```

### Check Firebase Functions Status
```bash
firebase functions:list
```

## Common Issues and Solutions

### Issue 1: No FCM Token Generated
**Symptoms**: Users don't receive notifications
**Causes**:
- Notification permissions not granted
- Firebase not properly initialized
- User not logged in

**Solutions**:
1. Ensure users grant notification permissions
2. Check browser console for Firebase initialization errors
3. Verify user is logged in before sending messages

### Issue 2: Cloud Function Failing
**Symptoms**: Messages sent but no notifications
**Causes**:
- Function deployment issues
- Incorrect Firestore structure
- Missing FCM tokens

**Solutions**:
1. Check function logs: `firebase functions:log --only sendChatNotification`
2. Verify chat message structure in Firestore
3. Ensure recipient has valid FCM token

### Issue 3: Web Notifications Not Working
**Symptoms**: Mobile works but web doesn't
**Causes**:
- Service worker not registered
- Firebase SDK version mismatch
- HTTPS required for service workers

**Solutions**:
1. Check service worker registration in browser dev tools
2. Verify Firebase SDK versions match (10.8.0)
3. Ensure app is served over HTTPS

### Issue 4: PWA Notifications Not Working
**Symptoms**: Web works but PWA doesn't
**Causes**:
- PWA not properly installed
- Service worker not active in PWA mode
- Notification permissions not granted in PWA

**Solutions**:
1. Install PWA properly
2. Check service worker status in PWA
3. Grant notification permissions in PWA

## Verification Checklist

### ✅ Cloud Functions
- [ ] `sendChatNotification` function deployed
- [ ] Function logs show successful execution
- [ ] No "Chat document not found" errors

### ✅ FCM Tokens
- [ ] Users have FCM tokens in Firestore
- [ ] Tokens are updated when users sign in
- [ ] Tokens are valid and not expired

### ✅ Web Configuration
- [ ] Firebase SDK versions match (10.8.0)
- [ ] Service worker registered
- [ ] Notification permissions granted
- [ ] HTTPS enabled

### ✅ Mobile Configuration
- [ ] Firebase properly initialized
- [ ] Notification permissions granted
- [ ] FCM token generated and saved

### ✅ Chat Structure
- [ ] Messages stored in `chats/{chatId}/messages/{messageId}`
- [ ] Message structure includes required fields
- [ ] Chat ID format is `uid1_uid2` (sorted)

## Testing Scenarios

### Scenario 1: Web to Web
1. Open app in two different browsers
2. Login with different users
3. Send message from User A to User B
4. Verify notification appears for User B

### Scenario 2: Mobile to Web
1. Use mobile app for User A
2. Use web app for User B
3. Send message from mobile to web
4. Verify notification appears on web

### Scenario 3: PWA to Mobile
1. Install PWA for User A
2. Use mobile app for User B
3. Send message from PWA to mobile
4. Verify notification appears on mobile

## Monitoring and Maintenance

### Regular Checks
1. Monitor Cloud Function logs for errors
2. Check FCM token validity
3. Verify notification delivery rates
4. Update Firebase SDK versions when needed

### Performance Optimization
1. Batch FCM token updates
2. Implement notification grouping
3. Add notification preferences
4. Monitor function execution times

## Support Commands

### Emergency Debugging
```bash
# Check all function logs
firebase functions:log

# Check specific function
firebase functions:log --only sendChatNotification

# Redeploy functions
firebase deploy --only functions

# Check deployment status
firebase functions:list
```

### User Token Verification
```bash
# Run debug script
node debug_notifications.js

# Check specific user
firebase firestore:get users/{userId}
```

## Next Steps
1. Test notifications with the fixes applied
2. Monitor function logs for any remaining issues
3. Implement notification preferences if needed
4. Add notification history/management features 