const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to add your service account key)
// admin.initializeApp({
//   credential: admin.credential.cert(require('./serviceAccountKey.json')),
//   projectId: 'reptigramfirestore'
// });

async function testMobilePWANotifications() {
  console.log('📱 Testing Mobile PWA Background Notifications...\n');

  // Test scenarios for mobile PWA
  const testScenarios = [
    {
      name: 'Mobile PWA Background Test',
      description: 'Test background notification to mobile PWA when app is closed',
      platform: 'mobile-pwa-background',
      userEmail: 'gecko1@gmail.com',
      instructions: [
        '1. Install PWA on mobile device',
        '2. Grant notification permissions',
        '3. Close/minimize the PWA',
        '4. Send this test notification',
        '5. Check if notification appears with sound'
      ]
    },
    {
      name: 'Mobile PWA Foreground Test',
      description: 'Test foreground notification to mobile PWA when app is open',
      platform: 'mobile-pwa-foreground',
      userEmail: 'gecko1@gmail.com',
      instructions: [
        '1. Keep PWA open on mobile device',
        '2. Send this test notification',
        '3. Check if notification appears as drawer popup'
      ]
    }
  ];

  console.log('📋 Mobile PWA Test Scenarios:');
  testScenarios.forEach((scenario, index) => {
    console.log(`\n${index + 1}. ${scenario.name}`);
    console.log(`   Description: ${scenario.description}`);
    console.log(`   Platform: ${scenario.platform}`);
    console.log(`   User: ${scenario.userEmail}`);
    console.log(`   Instructions:`);
    scenario.instructions.forEach(instruction => {
      console.log(`     ${instruction}`);
    });
  });

  console.log('\n🔧 To run tests:');
  console.log('1. Add your serviceAccountKey.json file');
  console.log('2. Uncomment the Firebase initialization code');
  console.log('3. Run: node test_mobile_pwa_notifications.js');
  console.log('4. Follow the instructions for each test scenario\n');

  // Uncomment the code below to actually run tests
  /*
  try {
    for (const scenario of testScenarios) {
      console.log(`\n🧪 Testing: ${scenario.name}`);
      console.log(`📋 Instructions:`);
      scenario.instructions.forEach(instruction => {
        console.log(`   ${instruction}`);
      });
      
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

      // Create mobile-specific test message
      const message = {
        token: userData.fcmToken,
        notification: {
          title: `Mobile Test: ${scenario.name}`,
          body: `Testing ${scenario.platform} notifications on mobile PWA`
        },
        data: {
          test: 'true',
          platform: scenario.platform,
          scenario: scenario.name,
          mobile: 'true',
          timestamp: Date.now().toString()
        },
        webpush: {
          notification: {
            title: `Mobile Test: ${scenario.name}`,
            body: `Testing ${scenario.platform} notifications on mobile PWA`,
            icon: '/favicon.png',
            badge: '/favicon.png',
            tag: 'mobile-test-notification',
            requireInteraction: true,
            renotify: true,
            silent: false,
            vibrate: [200, 100, 200, 100, 200],
            actions: [
              {
                action: 'open',
                title: 'Open Chat'
              }
            ]
          },
          fcm_options: {
            link: '/'
          }
        }
      };

      // Send test notification
      const response = await admin.messaging().send(message);
      console.log(`✅ Test notification sent successfully: ${response}`);
      console.log(`📱 Check mobile PWA for notification`);
      console.log(`⏰ Wait 10 seconds for notification to arrive...\n`);
      
      // Wait between tests
      await new Promise(resolve => setTimeout(resolve, 10000));
    }
  } catch (error) {
    console.error('❌ Error running mobile PWA tests:', error);
  }
  */
}

// Run the test
testMobilePWANotifications().then(() => {
  console.log('\n📱 Mobile PWA test script completed!');
  console.log('\n📋 Next Steps:');
  console.log('1. Uninstall and reinstall mobile PWA');
  console.log('2. Check mobile notification settings');
  console.log('3. Disable battery optimization for Chrome');
  console.log('4. Run the test script with Firebase initialized');
  console.log('5. Test both foreground and background notifications');
  console.log('\n🔍 Troubleshooting:');
  console.log('- Check mobile console logs for errors');
  console.log('- Verify service worker is active');
  console.log('- Check notification permissions');
  console.log('- Ensure device volume is enabled');
  process.exit(0);
}).catch(error => {
  console.error('❌ Mobile PWA test failed:', error);
  process.exit(1);
}); 