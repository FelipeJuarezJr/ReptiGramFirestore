const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to add your service account key)
// admin.initializeApp({
//   credential: admin.credential.cert(require('./serviceAccountKey.json')),
//   projectId: 'reptigramfirestore'
// });

async function testNotificationStatus() {
  console.log('🔍 Testing Current Notification Status...\n');

  // Test scenarios to identify what's broken
  const testScenarios = [
    {
      name: 'Basic Notification Test',
      description: 'Test if basic notifications work at all',
      userEmail: 'gecko1@gmail.com',
      priority: 'HIGH'
    },
    {
      name: 'Mobile Browser Test',
      description: 'Test mobile browser notifications',
      userEmail: 'gecko1@gmail.com',
      priority: 'HIGH'
    },
    {
      name: 'PWA Test',
      description: 'Test PWA notifications',
      userEmail: 'gecko1@gmail.com',
      priority: 'HIGH'
    }
  ];

  console.log('📋 Test Scenarios:');
  testScenarios.forEach((scenario, index) => {
    console.log(`\n${index + 1}. ${scenario.name}`);
    console.log(`   Description: ${scenario.description}`);
    console.log(`   User: ${scenario.userEmail}`);
    console.log(`   Priority: ${scenario.priority}`);
  });

  console.log('\n🔧 To run tests:');
  console.log('1. Add your serviceAccountKey.json file');
  console.log('2. Uncomment the Firebase initialization code');
  console.log('3. Run: node test_notification_status.js');
  console.log('4. Check mobile device for notifications\n');

  console.log('🚨 CRITICAL: Push notifications completely stopped working!');
  console.log('   • This suggests a fundamental issue with the recent changes');
  console.log('   • Possible causes:');
  console.log('     - Service worker registration failure');
  console.log('     - Firebase initialization error');
  console.log('     - JavaScript error in HTML');
  console.log('     - FCM token generation failure');
  console.log('     - Cloud function deployment issue');

  // Uncomment the code below to actually run tests
  /*
  try {
    for (const scenario of testScenarios) {
      console.log(`\n🧪 Testing: ${scenario.name}`);
      
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

      // Create simple test message
      const message = {
        token: userData.fcmToken,
        notification: {
          title: `Status Test: ${scenario.name}`,
          body: `Testing if notifications work at all - ${new Date().toLocaleTimeString()}`
        },
        data: {
          test: 'true',
          scenario: scenario.name,
          timestamp: Date.now().toString()
        },
        webpush: {
          notification: {
            title: `Status Test: ${scenario.name}`,
            body: `Testing if notifications work at all - ${new Date().toLocaleTimeString()}`,
            icon: '/favicon.png',
            badge: '/favicon.png',
            tag: 'status-test',
            requireInteraction: true,
            silent: false,
            vibrate: [200, 100, 200]
          },
          fcm_options: {
            link: '/'
          }
        }
      };

      // Send test notification
      const response = await admin.messaging().send(message);
      console.log(`✅ Test notification sent: ${response}`);
      console.log(`📱 Check device for notification`);
      console.log(`⏰ Wait 10 seconds...\n`);
      
      await new Promise(resolve => setTimeout(resolve, 10000));
    }
  } catch (error) {
    console.error('❌ Error running notification tests:', error);
  }
  */
}

// Run the test
testNotificationStatus().then(() => {
  console.log('\n🔍 Next Steps:');
  console.log('1. Check mobile browser console for JavaScript errors');
  console.log('2. Verify service worker is registered');
  console.log('3. Check if FCM tokens are being generated');
  console.log('4. Verify Firebase initialization in HTML');
  console.log('5. Check Cloud Function logs');
  console.log('\n🚨 EMERGENCY FIX NEEDED:');
  console.log('   • Notifications completely broken');
  console.log('   • Need to identify root cause quickly');
  console.log('   • May need to revert recent changes');
  process.exit(0);
}).catch(error => {
  console.error('❌ Notification status test failed:', error);
  process.exit(1);
}); 