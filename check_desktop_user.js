const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to add your service account key)
// admin.initializeApp({
//   credential: admin.credential.cert(require('./serviceAccountKey.json')),
//   projectId: 'reptigramfirestore'
// });

async function checkDesktopUser() {
  console.log('🔍 Checking desktop user FCM token...\n');

  // Find user by email
  const email = 'mr.felipe.juarez.jr@gmail.com';
  
  try {
    // Query users collection by email
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('email', '==', email)
      .get();

    if (usersSnapshot.empty) {
      console.log(`❌ No user found with email: ${email}`);
      return;
    }

    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    
    console.log('👤 User found:');
    console.log(`   UID: ${userDoc.id}`);
    console.log(`   Email: ${userData.email}`);
    console.log(`   Display Name: ${userData.displayName || 'N/A'}`);
    console.log(`   Username: ${userData.username || 'N/A'}`);
    
    if (userData.fcmToken) {
      console.log(`✅ FCM Token: ${userData.fcmToken.substring(0, 20)}...`);
      console.log(`   Last Token Update: ${userData.lastTokenUpdate?.toDate() || 'N/A'}`);
      
      // Test if token is valid by sending a test notification
      console.log('\n🧪 Testing FCM token validity...');
      try {
        const message = {
          token: userData.fcmToken,
          notification: {
            title: 'Desktop Test',
            body: 'Testing desktop notification delivery'
          },
          data: {
            test: 'true',
            platform: 'desktop',
            timestamp: Date.now().toString()
          },
          webpush: {
            notification: {
              title: 'Desktop Test',
              body: 'Testing desktop notification delivery',
              icon: '/favicon.png',
              badge: '/favicon.png'
            }
          }
        };

        // Uncomment to actually send test notification
        // const response = await admin.messaging().send(message);
        // console.log('✅ Test notification sent successfully:', response);
        console.log('⚠️  Test notification skipped (uncomment line to enable)');
        
      } catch (error) {
        console.log('❌ Error testing FCM token:', error.message);
        if (error.code === 'messaging/invalid-registration-token') {
          console.log('💡 Token is invalid - user needs to refresh the page');
        }
      }
    } else {
      console.log('❌ No FCM token found for this user');
      console.log('💡 User needs to:');
      console.log('   1. Grant notification permissions');
      console.log('   2. Refresh the page');
      console.log('   3. Ensure they are logged in');
    }

  } catch (error) {
    console.error('❌ Error checking user:', error);
  }
}

// Instructions for running
console.log('📋 To check desktop user FCM token:');
console.log('1. Add your serviceAccountKey.json file');
console.log('2. Uncomment the Firebase initialization code');
console.log('3. Run: node check_desktop_user.js');
console.log('4. Uncomment the test notification line to send a test notification\n');

// Run the check
checkDesktopUser().then(() => {
  console.log('\n🔍 Check completed!');
  process.exit(0);
}).catch(error => {
  console.error('❌ Check failed:', error);
  process.exit(1);
}); 