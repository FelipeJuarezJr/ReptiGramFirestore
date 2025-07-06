# Push Notification Test Guide

## 🎯 **Testing Your FCM V1 API Push Notifications**

Your Cloud Functions have been successfully deployed! Now let's test the push notifications.

## 📱 **Test Setup**

### **Option 1: Two Browser Tabs (Easiest)**
1. Open your app in **Tab 1** (http://localhost:8080)
2. Open your app in **Tab 2** (http://localhost:8080)
3. Sign in with different accounts in each tab

### **Option 2: Browser + Mobile (Best Test)**
1. Open your app in browser (http://localhost:8080)
2. Open your app on mobile device
3. Sign in with different accounts

## 🧪 **Step-by-Step Test**

### **Step 1: Grant Notification Permissions**
1. When the app loads, **allow notifications** when prompted
2. Check browser console for FCM token generation
3. Verify token is saved in Firestore

### **Step 2: Navigate to Chat**
1. Click **"Messenger"** in the navigation drawer
2. Select a user to chat with
3. You should see the chat interface

### **Step 3: Send Test Messages**
1. **Send a text message** → Should trigger notification
2. **Send an image** → Should show "📷 Sent you an image"
3. **Send a file** → Should show "📎 Sent you a file: [filename]"

### **Step 4: Test Push Notifications**
1. **Close the recipient's app/tab**
2. **Send a message from sender**
3. **Check for push notification** on recipient's device
4. **Click the notification** → Should open the chat

## 🔍 **What to Look For**

### ✅ **Success Indicators:**
- **In-app notifications** when app is open
- **Push notifications** when app is closed
- **Click to open** functionality works
- **Different messages** for text/image/file
- **Sender name** appears in notification

### ❌ **Troubleshooting:**
- **No notifications**: Check browser console for errors
- **Permission denied**: Grant notification permissions
- **Token not saved**: Check Firestore for FCM tokens
- **Function errors**: Check Firebase Console > Functions > Logs

## 📊 **Monitoring**

### **Check Function Logs:**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (reptigramfirestore)
3. Go to **Functions** > **Logs**
4. Look for `sendChatNotification` function calls

### **Check FCM Tokens:**
1. Go to **Firestore Database**
2. Navigate to `users/{userId}`
3. Verify `fcmToken` field exists and has a value

## 🎉 **Expected Results**

### **When App is Open:**
- In-app SnackBar notification appears
- Message appears in chat immediately
- No push notification (by design)

### **When App is Closed:**
- Push notification appears on device
- Clicking opens the app and navigates to chat
- Message appears in chat history

### **Notification Content:**
- **Text**: "New message from [Username]: [Message]"
- **Image**: "New message from [Username]: 📷 Sent you an image"
- **File**: "New message from [Username]: 📎 Sent you a file: [filename]"

## 🚀 **Next Steps After Testing**

1. **If everything works**: Your FCM V1 API is fully functional!
2. **If issues found**: Check the troubleshooting section above
3. **For production**: Deploy to your production Firebase project
4. **For mobile**: Add Android/iOS configuration

## 📞 **Need Help?**

- Check **Firebase Console** > **Functions** > **Logs** for errors
- Verify **FCM tokens** are saved in Firestore
- Ensure **notification permissions** are granted
- Test with **different browsers/devices**

Your ReptiGram chat system with FCM V1 API is now ready for testing! 🎯 