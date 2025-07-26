# PWA & Flutter App Notification Fix Guide

## Issue Summary
- ✅ Chrome browser notifications work
- ❌ PWA (standalone mode) notifications don't work
- ❌ Flutter app notifications don't work

## Root Cause Analysis
PWA and Flutter apps have different notification handling mechanisms:
1. **PWA Mode**: Runs in standalone mode with different service worker behavior
2. **Flutter App**: Uses native notification handling, not web notifications
3. **Service Worker Scope**: PWA mode requires different service worker registration
4. **FCM Token Storage**: PWA mode needs localStorage for token persistence

## Fixes Applied ✅

### 1. Enhanced PWA Detection and Handling
- **File**: `web/index.html`
- **Added**: PWA mode detection
- **Added**: PWA-specific FCM token handling
- **Added**: localStorage token storage
- **Added**: PWA-specific messaging setup

### 2. Improved Service Worker
- **File**: `web/firebase-messaging-sw.js`
- **Added**: Service worker installation/activation handlers
- **Added**: Push event fallback for older browsers
- **Added**: PWA-specific notification options
- **Added**: Better error handling

### 3. Enhanced Flutter Web Handling
- **File**: `lib/main.dart`
- **Added**: PWA mode detection
- **Added**: localStorage token retrieval
- **Added**: Better token fallback mechanisms

## Step-by-Step Fix for PWA

### Step 1: Uninstall and Reinstall PWA
1. **Uninstall current PWA**:
   - Right-click PWA icon
   - Select "Uninstall" or "Remove from Chrome"
   - Or go to Chrome settings > Apps > ReptiGram > Remove

2. **Clear browser data**:
   - Open Chrome settings
   - Privacy and security > Clear browsing data
   - Select "All time" and clear everything

### Step 2: Reinstall PWA
1. **Open the web app**: https://reptigramfirestore.web.app
2. **Grant notification permissions** when prompted
3. **Install PWA**:
   - Click the install icon in address bar, OR
   - Go to Chrome menu > Install ReptiGram

### Step 3: Verify PWA Setup
1. **Check PWA mode**:
   - Open browser console (F12)
   - Look for: "📱 PWA Mode: true"
   - Should see: "✅ Service worker is ready"

2. **Check FCM token**:
   - Look for: "🔑 FCM Token generated for PWA: [token]..."
   - Should see: "💾 FCM Token stored in localStorage"

### Step 4: Test PWA Notifications
1. **Send message from mobile to PWA**
2. **Check if notification appears**
3. **Verify notification is clickable**

## Step-by-Step Fix for Flutter App

### Step 1: Check Flutter App Permissions
1. **Android**:
   - Settings > Apps > ReptiGram > Permissions
   - Enable "Notifications"
   - Enable "Display over other apps" (if available)

2. **iOS**:
   - Settings > ReptiGram > Notifications
   - Enable "Allow Notifications"
   - Enable "Sounds" and "Badges"

### Step 2: Verify Flutter App Setup
1. **Check app logs**:
   - Look for: "🔔 Notification permission status: authorized"
   - Should see: "🔑 FCM Token generated: [token]..."
   - Should see: "✅ FCM Token saved to Firestore"

2. **Check Firestore**:
   - Verify user has FCM token in database
   - Token should be recent (not expired)

### Step 3: Test Flutter App Notifications
1. **Send message from web to Flutter app**
2. **Check if notification appears**
3. **Verify notification opens the app**

## Debugging Commands

### Check PWA Status
```bash
# Check if PWA is properly installed
# Look for these console logs:
# - "📱 PWA Mode: true"
# - "✅ Service worker is ready"
# - "🔑 FCM Token generated for PWA: [token]..."
```

### Check Flutter App Status
```bash
# Check Flutter app logs
flutter logs

# Look for these logs:
# - "🔔 Notification permission status: authorized"
# - "🔑 FCM Token generated: [token]..."
# - "✅ FCM Token saved to Firestore"
```

### Check Cloud Function Logs
```bash
# Check if notifications are being sent
firebase functions:log --only sendChatNotification
```

## Common PWA Issues

### Issue 1: PWA Not Detecting Standalone Mode
**Symptoms**: PWA Mode shows false
**Solutions**:
1. Ensure PWA is properly installed
2. Check if running in standalone mode
3. Clear browser cache and reinstall

### Issue 2: Service Worker Not Ready
**Symptoms**: "Service worker is ready" not logged
**Solutions**:
1. Check for JavaScript errors in console
2. Clear browser cache
3. Reinstall PWA

### Issue 3: FCM Token Not Generated in PWA
**Symptoms**: No FCM token for PWA mode
**Solutions**:
1. Grant notification permissions
2. Check localStorage for token
3. Refresh PWA

### Issue 4: Notifications Not Showing in PWA
**Symptoms**: Messages sent but no notifications
**Solutions**:
1. Check service worker registration
2. Verify FCM token is valid
3. Check browser notification settings

## Common Flutter App Issues

### Issue 1: Notification Permissions Denied
**Symptoms**: Permission status shows denied
**Solutions**:
1. Go to device settings
2. Enable notifications for the app
3. Restart the app

### Issue 2: FCM Token Not Generated
**Symptoms**: No FCM token logs
**Solutions**:
1. Check Firebase initialization
2. Verify user is logged in
3. Check for network connectivity

### Issue 3: Token Not Saved to Firestore
**Symptoms**: Token generated but not saved
**Solutions**:
1. Check Firestore permissions
2. Verify user authentication
3. Check for Firestore errors

### Issue 4: Notifications Not Delivered
**Symptoms**: Token saved but no notifications
**Solutions**:
1. Check Cloud Function logs
2. Verify token is valid
3. Test with manual notification

## Testing Checklist

### ✅ PWA Setup
- [ ] PWA properly installed
- [ ] Running in standalone mode
- [ ] Service worker registered and ready
- [ ] FCM token generated and stored in localStorage
- [ ] Notification permissions granted

### ✅ Flutter App Setup
- [ ] App properly installed
- [ ] Notification permissions granted
- [ ] FCM token generated
- [ ] Token saved to Firestore
- [ ] No console errors

### ✅ Cloud Functions
- [ ] Functions deployed successfully
- [ ] No errors in function logs
- [ ] Notifications being sent
- [ ] Proper webpush configuration

### ✅ Cross-Platform Testing
- [ ] Web to PWA notifications work
- [ ] Web to Flutter app notifications work
- [ ] PWA to Web notifications work
- [ ] Flutter app to Web notifications work

## Emergency Fixes

### Force PWA Reinstall
1. Uninstall PWA completely
2. Clear all browser data
3. Restart browser
4. Reinstall PWA fresh

### Force Flutter App Reinstall
1. Uninstall Flutter app
2. Clear app data
3. Reinstall from store
4. Grant permissions again

### Manual Token Verification
```bash
# Check user's FCM token in Firestore
firebase firestore:get users/{userId}
```

### Test Notification
```bash
# Send test notification to specific user
node check_desktop_user.js
# Uncomment test notification line
```

## Next Steps
1. Apply all fixes
2. Test PWA installation and notifications
3. Test Flutter app notifications
4. Verify cross-platform functionality
5. Monitor for any remaining issues

## Support
If issues persist:
1. Check browser/device console for specific errors
2. Verify all fixes are applied
3. Test on different devices/browsers
4. Check if device has any notification restrictions 