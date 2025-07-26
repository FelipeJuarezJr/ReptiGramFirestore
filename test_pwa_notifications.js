const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to add your service account key)
// admin.initializeApp({
//   credential: admin.credential.cert(require('./serviceAccountKey.json')),
//   projectId: 'reptigramfirestore'
// });

async function testPWANotifications() {
  console.log('🧪 Testing PWA and Flutter App Notifications...\n');

  // Test data for different platforms
  const testScenarios = [
    {
      name: 'Desktop PWA Test',
      description: 'Test notification to desktop PWA user',
      platform: 'pwa-desktop',
      userEmail: 'mr.felipe.juarez.jr@gmail.com'
    },
    {
      name: 'Mobile PWA Test',
      description: 'Test notification to mobile PWA user',
      platform: 'pwa-mobile',
      userEmail: 'gecko1@gmail.com'
    },
    {
      name: 'Flutter App Test',
      description: 'Test notification to Flutter app user',
      platform: 'flutter-app',
      userEmail: 'gecko1@gmail.com'
    }
  ];

  console.log('📋 Test Scenarios:');
  testScenarios.forEach((scenario, index) => {
    console.log(`${index + 1}. ${scenario.name}`);
    console.log(`   Description: ${scenario.description}`);
    console.log(`   Platform: ${scenario.platform}`);
    console.log(`   User: ${scenario.userEmail}\n`);
  });

  console.log('🔧 To run tests:');
  console.log('1. Add your serviceAccountKey.json file');
  console.log('2. Uncomment the Firebase initialization code');
  console.log('3. Run: node test_pwa_notifications.js');
  console.log('4. Check if notifications are received on each platform\n');

  // Uncomment the code below to actually run tests
  /*
  try {
    for (const scenario of testScenarios) {
      console.log(`🧪 Testing: ${scenario.name}`);
      
      // Find user by email
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('email', '==', scenario.userEmail)
        .get();

      if (usersSnapshot.empty) {
        console.log(`❌ User not found: ${scenario.userEmail}`);
        continue;
      }

      const userDoc = usersSnapshot.docs[0];
      const userData = userDoc.data();
      
      if (!userData.fcmToken) {
        console.log(`❌ No FCM token for user: ${scenario.userEmail}`);
        continue;
      }

      console.log(`✅ User found: ${userData.displayName || userData.username}`);
      console.log(`🔑 FCM Token: ${userData.fcmToken.substring(0, 20)}...`);

      // Create test message
      const message = {
        token: userData.fcmToken,
        notification: {
          title: `Test: ${scenario.name}`,
          body: `Testing ${scenario.platform} notifications`
        },
        data: {
          test: 'true',
          platform: scenario.platform,
          scenario: scenario.name,
          timestamp: Date.now().toString()
        },
        webpush: {
          notification: {
            title: `Test: ${scenario.name}`,
            body: `Testing ${scenario.platform} notifications`,
            icon: '/favicon.png',
            badge: '/favicon.png',
            tag: 'test-notification',
            requireInteraction: true
          }
        },
        android: {
          notification: {
            title: `Test: ${scenario.name}`,
            body: `Testing ${scenario.platform} notifications`,
            sound: 'default',
            channelId: 'test_messages'
          }
        },
        apns: {
          payload: {
            aps: {
              title: `Test: ${scenario.name}`,
              body: `Testing ${scenario.platform} notifications`,
              sound: 'default',
              badge: 1
            }
          }
        }
      };

      // Send test notification
      const response = await admin.messaging().send(message);
      console.log(`✅ Test notification sent successfully: ${response}`);
      console.log(`📱 Check ${scenario.platform} for notification\n`);
      
      // Wait a bit between tests
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  } catch (error) {
    console.error('❌ Error running tests:', error);
  }
  */
}

// Run the test
testPWANotifications().then(() => {
  console.log('\n🧪 Test script completed!');
  console.log('\n📋 Next Steps:');
  console.log('1. Uninstall and reinstall PWA');
  console.log('2. Check Flutter app permissions');
  console.log('3. Run the test script with Firebase initialized');
  console.log('4. Verify notifications on each platform');
  process.exit(0);
}).catch(error => {
  console.error('❌ Test failed:', error);
  process.exit(1);
}); 