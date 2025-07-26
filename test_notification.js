const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to add your service account key)
// admin.initializeApp({
//   credential: admin.credential.cert(require('./serviceAccountKey.json')),
//   projectId: 'reptigramfirestore'
// });

async function testNotification() {
  console.log('🧪 Testing notification system...\n');

  // Test data - replace with actual user IDs and FCM tokens
  const testData = {
    chatId: 'user1_user2', // Replace with actual chat ID
    senderId: 'user1',     // Replace with actual sender ID
    recipientId: 'user2',  // Replace with actual recipient ID
    fcmToken: 'fcm_token_here', // Replace with actual FCM token
    message: {
      text: 'Test notification message',
      messageType: 'text',
      timestamp: Date.now()
    }
  };

  console.log('📝 Test data:');
  console.log(JSON.stringify(testData, null, 2));

  console.log('\n🔧 To test notifications:');
  console.log('1. Replace the test data above with real values');
  console.log('2. Uncomment the Firebase initialization code');
  console.log('3. Run: node test_notification.js');
  console.log('4. Check if notification is received');

  // Uncomment the code below to actually send a test notification
  /*
  try {
    const message = {
      token: testData.fcmToken,
      notification: {
        title: 'Test Notification',
        body: testData.message.text
      },
      data: {
        senderId: testData.senderId,
        messageType: testData.message.messageType,
        chatId: testData.chatId,
        test: 'true'
      },
      webpush: {
        notification: {
          title: 'Test Notification',
          body: testData.message.text,
          icon: '/favicon.png',
          badge: '/favicon.png'
        }
      }
    };

    const response = await admin.messaging().send(message);
    console.log('✅ Test notification sent successfully:', response);
  } catch (error) {
    console.error('❌ Error sending test notification:', error);
  }
  */
}

// Run the test
testNotification().then(() => {
  console.log('\n🧪 Test script completed!');
  process.exit(0);
}).catch(error => {
  console.error('❌ Test failed:', error);
  process.exit(1);
}); 