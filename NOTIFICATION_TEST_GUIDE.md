# Notification & Unread Message Test Guide

## 🎯 **Testing Push Notifications & Unread Indicators**

Your chat system now has:
- ✅ **Push notifications** via FCM v1 API
- ✅ **Unread message indicators** in user list
- ✅ **Message count badges** in navigation drawer
- ✅ **Last message previews** with timestamps

## 📱 **Test Setup**

### **Option 1: Two Browser Tabs (Recommended)**
1. Open your app in **Tab 1** (http://localhost:8080)
2. Open your app in **Tab 2** (http://localhost:8080)
3. Sign in with different accounts in each tab

### **Option 2: Browser + Mobile**
1. Open your app in browser (http://localhost:8080)
2. Open your app on mobile device
3. Sign in with different accounts

## 🧪 **Step-by-Step Test**

### **Step 1: Grant Notification Permissions**
1. When the app loads, **allow notifications** when prompted
2. Check browser console for FCM token generation
3. Verify token is saved in Firestore

### **Step 2: Check FCM Token Storage**
1. Open browser console (F12)
2. Look for messages like:
   ```
   FCM Token: [long token string]
   Token saved to Firestore
   ```
3. If no token appears, check for permission errors

### **Step 3: Test Unread Indicators**
1. Navigate to **Messenger** in the navigation drawer
2. Look for:
   - **Red badges** on user avatars (if they have unread messages)
   - **Bold names** for users with unread messages
   - **Last message preview** under each user
   - **Timestamp** showing when last message was sent

### **Step 4: Test Push Notifications**
1. **Close the recipient's app/tab**
2. **Send a message from sender**
3. **Check for push notification** on recipient's device
4. **Click the notification** → Should open the chat

### **Step 5: Test Navigation Badge**
1. **Send a message** to a user
2. **Go back to main screen**
3. **Check navigation drawer** - Messenger should have a red badge with count

## 🔍 **What to Look For**

### ✅ **Success Indicators:**
- **FCM token generated** in console
- **Token saved** in Firestore users collection
- **Red badges** on user avatars in user list
- **Bold names** for users with unread messages
- **Last message preview** shows correctly
- **Timestamps** are accurate
- **Navigation badge** shows unread count
- **Push notifications** appear when app is closed
- **Click to open** functionality works

### ❌ **Troubleshooting:**
- **No FCM token**: Check notification permissions
- **No unread indicators**: Check if messages are being sent/received
- **No push notifications**: Check Cloud Function logs
- **Token not saved**: Check Firestore rules

## 📊 **Monitoring**

### **Check FCM Token Storage:**
```javascript
// In browser console
firebase.firestore().collection('users').doc('YOUR_UID').get()
  .then(doc => console.log('User data:', doc.data()));
```

### **Check Cloud Function Logs:**
```bash
firebase functions:log --only sendChatNotification
```

### **Check Firestore Rules:**
```bash
firebase firestore:rules:get
```

## 🐛 **Common Issues & Solutions**

### **Issue: No FCM Token Generated**
**Solution:**
1. Check notification permissions in browser
2. Clear browser data and try again
3. Check console for errors

### **Issue: No Push Notifications**
**Solution:**
1. Verify Cloud Functions are deployed
2. Check function logs for errors
3. Verify FCM token is saved in Firestore
4. Test with app completely closed

### **Issue: No Unread Indicators**
**Solution:**
1. Check if messages are being sent/received
2. Verify chat collections exist in Firestore
3. Check browser console for errors

### **Issue: Navigation Badge Not Updating**
**Solution:**
1. Refresh the app
2. Check if user is properly signed in
3. Verify chat data structure

## 🎉 **Expected Results**

After successful testing, you should see:

1. **User List Screen:**
   - Users with unread messages have red badges
   - Bold names for users with unread messages
   - Last message preview under each user
   - Timestamps showing message age

2. **Navigation Drawer:**
   - Messenger icon has red badge with unread count
   - Badge updates in real-time

3. **Push Notifications:**
   - Notifications appear when app is closed
   - Clicking notification opens the chat
   - Different messages for text/image/file

4. **Real-time Updates:**
   - All indicators update immediately when new messages arrive
   - No need to refresh the app

## 🔧 **Debug Commands**

### **Check FCM Token:**
```javascript
// In browser console
firebase.messaging().getToken().then(token => console.log('Current token:', token));
```

### **Check User Data:**
```javascript
// In browser console
firebase.firestore().collection('users').doc('YOUR_UID').get()
  .then(doc => console.log('User data:', doc.data()));
```

### **Check Chat Data:**
```javascript
// In browser console
firebase.firestore().collection('chats').get()
  .then(snapshot => snapshot.docs.forEach(doc => console.log('Chat:', doc.id, doc.data())));
```

## 📝 **Test Checklist**

- [ ] FCM token generated and saved
- [ ] Unread indicators appear in user list
- [ ] Navigation badge shows correct count
- [ ] Push notifications work when app closed
- [ ] Clicking notification opens chat
- [ ] Real-time updates work
- [ ] Different message types show correctly
- [ ] Timestamps are accurate
- [ ] No console errors
- [ ] All features work on mobile

## 🚀 **Next Steps**

Once testing is complete:
1. **Monitor function logs** for any errors
2. **Test with multiple users** simultaneously
3. **Verify mobile notifications** work
4. **Check performance** with many messages
5. **Consider adding** read receipts for better UX 