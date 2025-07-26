# Mobile PWA Idle Notification Fix Guide

## Issue Summary
- ✅ Mobile PWA foreground notifications work (when app is open and screen is on)
- ❌ Mobile PWA background notifications don't work (when phone is locked or running other apps)
- ❌ No notifications when phone is idle or screen is off

## Root Cause Analysis
Mobile browsers have strict limitations for background notifications:
1. **Battery Optimization**: Mobile devices aggressively kill background processes
2. **Service Worker Lifecycle**: Browsers terminate service workers when device is idle
3. **Wake Lock Restrictions**: Limited ability to wake up sleeping devices
4. **Background Processing Limits**: Mobile browsers restrict background processing
5. **Doze Mode**: Android's aggressive battery saving mode

## Fixes Applied ✅

### 1. Enhanced Service Worker with Wake-Up Strategies
- **File**: `web/firebase-messaging-sw.js`
- **Added**: Silent audio playback to wake up device
- **Added**: Enhanced vibration patterns for better wake-up
- **Added**: Wake lock request when supported
- **Added**: Periodic wake-up checks every 5 minutes
- **Added**: Enhanced error handling and logging

### 2. Improved Mobile PWA Setup
- **File**: `web/index.html`
- **Added**: Wake lock acquisition for mobile PWA
- **Added**: Background sync registration
- **Added**: Periodic sync registration
- **Added**: Visibility change handling
- **Added**: Enhanced service worker communication

### 3. Enhanced Cloud Function
- **File**: `functions/index.js`
- **Added**: Enhanced vibration patterns
- **Added**: High priority FCM options
- **Added**: Extended TTL for notifications
- **Added**: High urgency headers

## Step-by-Step Fix for Mobile PWA Idle Notifications

### Step 1: Uninstall and Reinstall Mobile PWA
1. **Uninstall current PWA**:
   - Long press PWA icon
   - Select "Uninstall" or "Remove from Chrome"
   - Or go to Chrome settings > Apps > ReptiGram > Remove

2. **Clear browser data completely**:
   - Open Chrome settings
   - Privacy and security > Clear browsing data
   - Select "All time" and clear everything
   - Restart mobile device

### Step 2: Reinstall Mobile PWA
1. **Open the web app**: https://reptigramfirestore.web.app
2. **Grant notification permissions** when prompted
3. **Install PWA**:
   - Tap the install icon in address bar, OR
   - Go to Chrome menu > Install ReptiGram

### Step 3: Configure Mobile Settings

#### Android Settings
1. **Chrome Settings**:
   - Open Chrome settings
   - Site Settings > Notifications
   - Find ReptiGram and set to "Allow"
   - Enable "Show notifications"

2. **Android System Settings**:
   - Settings > Apps > Chrome > Permissions
   - Enable "Notifications"
   - Enable "Display over other apps" (if available)
   - Enable "Auto-start" (if available)

3. **Battery Optimization**:
   - Settings > Apps > Chrome > Battery
   - Disable "Battery optimization" for Chrome
   - Or add Chrome to "Unrestricted" apps
   - Settings > Battery > Battery optimization > Unrestricted apps > Add Chrome

4. **Doze Mode Settings**:
   - Settings > Battery > Battery optimization
   - Tap "Advanced optimization"
   - Disable "Adaptive battery" for Chrome
   - Settings > Developer options > Standby apps > Add Chrome

#### iOS Settings
1. **Safari Settings**:
   - Settings > Safari > Notifications
   - Find ReptiGram and set to "Allow"
   - Enable "Sounds" and "Badges"

2. **iOS System Settings**:
   - Settings > Notifications > Safari
   - Enable "Allow Notifications"
   - Enable "Sounds" and "Badges"
   - Enable "Show on Lock Screen"

3. **Background App Refresh**:
   - Settings > General > Background App Refresh
   - Enable for Safari/Chrome

### Step 4: Verify Mobile PWA Setup
1. **Check mobile PWA mode**:
   - Open browser console (F12)
   - Look for: "📱 PWA Mode: true"
   - Look for: "📱 Mobile device: true"
   - Should see: "✅ Service worker is ready"

2. **Check enhanced features**:
   - Should see: "📱 Setting up additional mobile strategies..."
   - Should see: "🔒 Wake lock acquired for mobile PWA" (if supported)
   - Should see: "🔄 Background sync registered" (if supported)

3. **Check FCM token**:
   - Look for: "🔑 FCM Token generated for PWA: [token]..."
   - Should see: "💾 FCM Token stored in localStorage"

### Step 5: Test Idle Notifications
1. **Send message from desktop to mobile PWA**
2. **Lock the phone screen or switch to another app**
3. **Wait 1-2 minutes**
4. **Check if notification appears with sound and vibration**
5. **Verify notification wakes up the device**

## Advanced Mobile Settings

### Developer Options (Android)
1. **Enable Developer Options**:
   - Settings > About phone > Tap "Build number" 7 times
   - Settings > Developer options

2. **Configure for Better Notifications**:
   - Keep screen on while charging: ON
   - Don't keep activities: OFF
   - Background process limit: Standard limit
   - Show all ANRs: ON

### Chrome Flags (Android)
1. **Open Chrome**:
   - Go to chrome://flags/

2. **Enable Experimental Features**:
   - Search for "background"
   - Enable "Background sync"
   - Enable "Periodic background sync"
   - Enable "Push messaging"

### iOS Advanced Settings
1. **Focus Mode**:
   - Settings > Focus > Do Not Disturb
   - Add ReptiGram to "Allowed Notifications"

2. **Screen Time**:
   - Settings > Screen Time > Content & Privacy Restrictions
   - Allow notifications for ReptiGram

## Debugging Mobile PWA Idle Issues

### Check Mobile Console Logs
```bash
# Connect mobile device to computer and use Chrome DevTools
# Look for these enhanced logs:
# - "📱 Mobile device: true"
# - "📱 PWA Mode: true"
# - "✅ Service worker is ready"
# - "📱 Setting up additional mobile strategies..."
# - "🔒 Wake lock acquired for mobile PWA"
# - "🔄 Background sync registered"
# - "📱 Attempting to wake up mobile device..."
# - "🔊 Silent audio played to wake up device"
```

### Check Service Worker Status
1. **Open Chrome DevTools on mobile**:
   - Connect mobile to computer
   - Open Chrome DevTools
   - Go to Application tab > Service Workers
   - Verify `firebase-messaging-sw.js` is active

2. **Check for enhanced features**:
   - Look for wake lock requests
   - Check background sync registration
   - Verify periodic wake-up messages

### Test Idle Notifications
```bash
# Send test notification to mobile PWA when idle
node test_mobile_pwa_notifications.js
# Uncomment the test notification line
```

## Common Mobile PWA Idle Issues

### Issue 1: Notifications Don't Wake Up Device
**Symptoms**: Notifications arrive but don't wake up locked screen
**Solutions**:
1. Check battery optimization settings
2. Disable Doze mode for Chrome
3. Enable "Display over other apps"
4. Check notification priority settings

### Issue 2: Notifications Delayed When Idle
**Symptoms**: Notifications arrive late when device is idle
**Solutions**:
1. Disable battery optimization
2. Add Chrome to unrestricted apps
3. Enable background app refresh
4. Check network connectivity

### Issue 3: No Sound When Device is Locked
**Symptoms**: Notifications appear but no sound when locked
**Solutions**:
1. Check device volume settings
2. Enable notification sounds in system settings
3. Check "Do Not Disturb" mode
4. Verify notification permissions include sound

### Issue 4: Service Worker Terminated When Idle
**Symptoms**: Service worker becomes inactive when device is idle
**Solutions**:
1. Check periodic wake-up messages
2. Verify service worker keep-alive
3. Enable background processing
4. Check browser version compatibility

## Mobile Browser Compatibility

### Chrome Mobile (Android)
- ✅ Wake lock support (Android 9+)
- ✅ Background sync support
- ✅ Enhanced notification delivery
- ⚠️ Limited by battery optimization

### Safari Mobile (iOS)
- ⚠️ Limited wake lock support
- ⚠️ Restricted background processing
- ✅ Good notification delivery
- ⚠️ Requires user interaction

### Firefox Mobile
- ✅ Good wake lock support
- ✅ Background sync support
- ✅ Enhanced notification delivery
- ✅ Better background processing

## Testing Checklist

### ✅ Mobile PWA Setup
- [ ] PWA properly installed on mobile
- [ ] Running in standalone mode
- [ ] Mobile device detected
- [ ] Service worker registered and active
- [ ] Enhanced features enabled
- [ ] Wake lock acquired (if supported)

### ✅ Mobile System Settings
- [ ] Chrome notifications enabled
- [ ] Android battery optimization disabled
- [ ] Doze mode disabled for Chrome
- [ ] iOS notification settings configured
- [ ] Background app refresh enabled
- [ ] Device volume enabled

### ✅ Idle Notification Test
- [ ] Send message from desktop to mobile PWA
- [ ] Lock phone screen or switch to other app
- [ ] Wait 1-2 minutes
- [ ] Notification appears with sound
- [ ] Device wakes up from notification
- [ ] Notification is clickable

## Emergency Fixes

### Force Mobile PWA Reinstall
1. Uninstall PWA completely
2. Clear all browser data
3. Restart mobile device
4. Reinstall PWA fresh
5. Configure all settings again

### Reset Mobile Notification Settings
1. Go to Chrome settings > Site Settings > Notifications
2. Clear all notification permissions
3. Reset battery optimization settings
4. Reinstall PWA and grant permissions again

### Check Mobile Network
1. Ensure stable internet connection
2. Try on WiFi and mobile data
3. Check if firewall blocks notifications
4. Verify FCM connectivity

## Next Steps
1. Apply all mobile-specific idle fixes
2. Configure mobile system settings
3. Test notifications when device is locked
4. Verify wake-up functionality
5. Test on different mobile devices/browsers
6. Monitor for any remaining issues

## Support
If issues persist:
1. Check mobile console for specific errors
2. Verify all mobile idle fixes are applied
3. Test on different mobile devices
4. Check mobile browser version compatibility
5. Verify mobile system settings
6. Consider using native app for better notification delivery 