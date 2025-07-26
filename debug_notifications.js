const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'reptigramfirestore'
});

const db = admin.firestore();

async function debugNotifications() {
  console.log('🔍 Starting notification debugging...\n');

  try {
    // 1. Check if users have FCM tokens
    console.log('1. Checking user FCM tokens...');
    const usersSnapshot = await db.collection('users').get();
    const usersWithTokens = [];
    const usersWithoutTokens = [];

    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      if (userData.fcmToken) {
        usersWithTokens.push({
          uid: doc.id,
          username: userData.username || userData.displayName || 'Unknown',
          fcmToken: userData.fcmToken.substring(0, 20) + '...',
          lastTokenUpdate: userData.lastTokenUpdate
        });
      } else {
        usersWithoutTokens.push({
          uid: doc.id,
          username: userData.username || userData.displayName || 'Unknown'
        });
      }
    });

    console.log(`✅ Users with FCM tokens: ${usersWithTokens.length}`);
    usersWithTokens.forEach(user => {
      console.log(`   - ${user.username} (${user.uid}): ${user.fcmToken}`);
    });

    console.log(`❌ Users without FCM tokens: ${usersWithoutTokens.length}`);
    usersWithoutTokens.forEach(user => {
      console.log(`   - ${user.username} (${user.uid})`);
    });

    // 2. Check chat messages structure
    console.log('\n2. Checking chat messages structure...');
    const chatsSnapshot = await db.collection('chats').get();
    console.log(`📱 Total chats found: ${chatsSnapshot.size}`);

    if (chatsSnapshot.size > 0) {
      const firstChat = chatsSnapshot.docs[0];
      const messagesSnapshot = await firstChat.ref.collection('messages').get();
      console.log(`📨 Messages in first chat (${firstChat.id}): ${messagesSnapshot.size}`);
      
      if (messagesSnapshot.size > 0) {
        const firstMessage = messagesSnapshot.docs[0].data();
        console.log('📝 Sample message structure:');
        console.log(JSON.stringify(firstMessage, null, 2));
      }
    }

    // 3. Test FCM token validity
    console.log('\n3. Testing FCM token validity...');
    if (usersWithTokens.length > 0) {
      const testUser = usersWithTokens[0];
      try {
        const message = {
          token: testUser.fcmToken.replace('...', ''), // You'll need the full token
          notification: {
            title: 'Test Notification',
            body: 'This is a test notification from debug script'
          },
          data: {
            test: 'true',
            timestamp: Date.now().toString()
          }
        };

        console.log(`🧪 Testing notification to ${testUser.username}...`);
        // Uncomment the line below to actually send a test notification
        // const response = await admin.messaging().send(message);
        // console.log('✅ Test notification sent successfully:', response);
        console.log('⚠️  Test notification skipped (uncomment line to enable)');
      } catch (error) {
        console.log('❌ Error sending test notification:', error.message);
      }
    }

    // 4. Check Cloud Function logs
    console.log('\n4. Recent Cloud Function logs...');
    console.log('Run this command to see recent logs:');
    console.log('firebase functions:log --only sendChatNotification');

    // 5. Web-specific checks
    console.log('\n5. Web-specific checks...');
    console.log('✅ Firebase SDK versions should match:');
    console.log('   - Main app: 10.8.0');
    console.log('   - Service worker: 10.8.0');
    console.log('✅ Service worker should be registered');
    console.log('✅ Notification permissions should be granted');

    // 6. Recommendations
    console.log('\n6. Recommendations:');
    if (usersWithoutTokens.length > 0) {
      console.log('❌ Users without FCM tokens need to:');
      console.log('   - Grant notification permissions');
      console.log('   - Refresh the app to generate new tokens');
    }
    
    console.log('✅ Ensure users are logged in when testing');
    console.log('✅ Test on both web and mobile devices');
    console.log('✅ Check browser console for errors');
    console.log('✅ Verify Firebase project configuration');

  } catch (error) {
    console.error('❌ Error during debugging:', error);
  }
}

// Run the debug function
debugNotifications().then(() => {
  console.log('\n🔍 Debugging complete!');
  process.exit(0);
}).catch(error => {
  console.error('❌ Debugging failed:', error);
  process.exit(1);
}); 