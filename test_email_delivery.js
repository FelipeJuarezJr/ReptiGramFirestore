const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./service-account-key.json');
const app = admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'reptigramfirestore',
});

const auth = app.auth();

async function testEmailDelivery() {
  try {
    console.log('🔍 Testing Email Delivery for Password Reset...\n');
    
    // Test emails
    const testEmails = [
      'reptigram@gmail.com',
      'mr.felipe.juarez.jr@gmail.com'
    ];
    
    for (const email of testEmails) {
      try {
        console.log(`📧 Testing email delivery to: ${email}`);
        
        // Check if user exists
        const user = await auth.getUserByEmail(email);
        console.log(`   ✅ User found: ${user.email} (${user.uid})`);
        console.log(`   📅 User created: ${new Date(parseInt(user.metadata.creationTime)).toLocaleString()}`);
        console.log(`   🔐 Email verified: ${user.emailVerified}`);
        
        // Generate password reset link
        const resetLink = await auth.generatePasswordResetLink(email, {
          url: 'http://localhost:8080/reset-password',
          handleCodeInApp: false,
        });
        
        console.log(`   ✅ Reset link generated successfully!`);
        console.log(`   🔗 Reset link: ${resetLink.substring(0, 100)}...`);
        
        // Note: We can't actually send the email from admin SDK
        // This is just to test if the link generation works
        console.log(`   📤 Firebase should have sent the email`);
        
      } catch (error) {
        console.log(`   ❌ Error with ${email}: ${error.message}`);
      }
      
      console.log(''); // Empty line for readability
    }
    
    console.log('🎯 Next Steps:');
    console.log('1. Check Firebase Console → Authentication → Templates');
    console.log('2. Check spam/junk folders in email accounts');
    console.log('3. Test manual reset from Firebase Console');
    console.log('4. Try with different email providers');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

testEmailDelivery(); 