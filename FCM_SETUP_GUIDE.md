# Firebase Cloud Messaging Setup Guide

## Current Status
✅ **Firebase Cloud Messaging API (V1) Enabled** - This is good for modern apps
❌ **Cloud Messaging API (Legacy) Disabled** - This is needed for client-side push notifications

## Option 1: In-App Notifications Only (Current Setup)
Your app currently supports:
- ✅ Real-time messaging
- ✅ In-app notifications when app is open
- ✅ Image and file sharing
- ✅ User avatars in chat

## Option 2: Full Push Notifications (Requires Legacy API)

To enable **full push notifications** (when app is closed/background):

1. **Enable Legacy API**:
   - Go to Firebase Console > Project Settings > Cloud Messaging
   - Click "Enable" next to "Cloud Messaging API (Legacy)"
   - This will give you a **Server Key** (starts with `AAAA...`)

2. **Update the Server Key**:
   - Copy the Server Key from Firebase Console
   - Replace `YOUR_FCM_SERVER_KEY_HERE` in `lib/services/chat_service.dart`

3. **Test Push Notifications**:
   - Send a message from one device
   - Close the app on the recipient device
   - You should receive a push notification

## Option 3: Server-Side V1 API (Advanced)

For production apps, consider using Firebase Cloud Functions with V1 API:
- More secure (server-side)
- Better performance
- Full V1 API features

## Current Features Working Now:
- ✅ Real-time chat messaging
- ✅ In-app notifications
- ✅ Image/file sharing
- ✅ User avatars
- ✅ Navigation from notifications
- ✅ FCM token management

## Next Steps:
1. Test the current in-app notifications
2. If you want full push notifications, enable Legacy API
3. Update the server key in the code
4. Test push notifications

The app is fully functional for chat with in-app notifications! 