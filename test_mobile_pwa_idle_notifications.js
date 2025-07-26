const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to add your service account key)
// admin.initializeApp({
//   credential: admin.credential.cert(require('./serviceAccountKey.json')),
//   projectId: 'reptigramfirestore'
// });

async function testMobilePWAIdleNotifications() {
  console.log('📱 Testing Mobile PWA Idle Notifications...\n');

  // Test scenarios for mobile PWA idle notifications
  const testScenarios = [
    {
      name: 'Mobile PWA Locked Screen Test',
      description: 'Test notification when phone screen is locked',
      platform: 'mobile-pwa-locked',
      userEmail: 'gecko1@gmail.com',
      instructions: [
        '1. Install PWA on mobile device',
        '2. Grant notification permissions',
        '3. Configure battery optimization settings',
        '4. Lock the phone screen',
        '5. Send this test notification',
        '6. Check if notification wakes up device with sound'
      ]
    },
    {
      name: 'Mobile PWA Background App Test',
      description: 'Test notification when using other apps',
      platform: 'mobile-pwa-background',
      userEmail: 'gecko1@gmail.com',
      instructions: [
        '1. Keep PWA installed and running',
        '2. Switch to another app (e.g., camera, messages)',
        '3. Send this test notification',
        '4. Check if notification appears over other app'
      ]
    },
    {
      name: 'Mobile PWA Idle Device Test',
      description: 'Test notification when device is idle for 5+ minutes',
      platform: 'mobile-pwa-idle',
      userEmail: 'gecko1@gmail.com',
      instructions: [
        '1. Install PWA on mobile device',
        '2. Lock screen and leave device idle for 5+ minutes',
        '3. Send this test notification',
        '4. Check if notification wakes up idle device'
      ]
    }
  ];

  console.log('📋 Mobile PWA Idle Test Scenarios:');
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
  console.log('3. Run: node test_mobile_pwa_idle_notifications.js');
  console.log('4. Follow the instructions for each test scenario\n');

  console.log('⚠️  Important Mobile Settings to Check:');
  console.log('   • Disable battery optimization for Chrome');
  console.log('   • Add Chrome to unrestricted apps');
  console.log('   • Enable "Display over other apps"');
  console.log('   • Disable Doze mode for Chrome');
  console.log('   • Enable background app refresh');

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

      // Create mobile-specific idle test message
      const message = {
        token: userData.fcmToken,
        notification: {
          title: `Idle Test: ${scenario.name}`,
          body: `Testing ${scenario.platform} notifications on idle mobile PWA`
        },
        data: {
          test: 'true',
          platform: scenario.platform,
          scenario: scenario.name,
          mobile: 'true',
          idle: 'true',
          timestamp: Date.now().toString()
        },
        webpush: {
          notification: {
            title: `Idle Test: ${scenario.name}`,
            body: `Testing ${scenario.platform} notifications on idle mobile PWA`,
            icon: '/favicon.png',
            badge: '/favicon.png',
            tag: 'idle-test-notification',
            requireInteraction: true,
            renotify: true,
            silent: false,
            vibrate: [100, 200, 100, 200, 100, 200, 100, 200, 100, 200, 100, 200],
            actions: [
              {
                action: 'open',
                title: 'Open Chat'
              }
            ],
            // Enhanced mobile-specific options for idle devices
            dir: 'auto',
            lang: 'en',
            image: '/favicon.png'
          },
          fcm_options: {
            link: '/',
            analytics_label: 'idle_test',
            priority: 'high'
          },
          headers: {
            'Urgency': 'high',
            'TTL': '86400'
          }
        }
      };

      // Send test notification
      const response = await admin.messaging().send(message);
      console.log(`✅ Idle test notification sent successfully: ${response}`);
      console.log(`📱 Check mobile PWA for notification`);
      console.log(`⏰ Wait 30 seconds for notification to arrive...\n`);
      
      // Wait between tests
      await new Promise(resolve => setTimeout(resolve, 30000));
    }
  } catch (error) {
    console.error('❌ Error running mobile PWA idle tests:', error);
  }
  */
}

// Run the test
testMobilePWAIdleNotifications().then(() => {
  console.log('\n📱 Mobile PWA idle test script completed!');
  console.log('\n📋 Next Steps:');
  console.log('1. Uninstall and reinstall mobile PWA');
  console.log('2. Configure mobile system settings (battery optimization, etc.)');
  console.log('3. Test notifications when device is locked');
  console.log('4. Test notifications when using other apps');
  console.log('5. Test notifications when device is idle');
  console.log('\n🔍 Troubleshooting:');
  console.log('- Check mobile console logs for enhanced features');
  console.log('- Verify wake lock acquisition');
  console.log('- Check background sync registration');
  console.log('- Ensure battery optimization is disabled');
  console.log('- Verify notification permissions include sound');
  console.log('\n⚠️  Note: Mobile browsers have limitations for idle notifications');
  console.log('   • Results may vary based on device and browser');
  console.log('   • Some devices may still restrict background notifications');
  console.log('   • Consider using native app for best notification delivery');
  process.exit(0);
}).catch(error => {
  console.error('❌ Mobile PWA idle test failed:', error);
  process.exit(1);
}); 