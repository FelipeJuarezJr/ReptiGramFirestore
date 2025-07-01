const admin = require('firebase-admin');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
});

const auth = app.auth();

async function checkUserMethods() {
  try {
    console.log('Checking user authentication details...');
    
    const testEmails = [
      'gecko1@gmail.com',
      'tester@example.com',
      'felipe.juarez.jr@outlook.com',
      'reptigram@gmail.com'
    ];
    
    for (const email of testEmails) {
      try {
        const user = await auth.getUserByEmail(email);
        console.log(`\n=== ${email} ===`);
        console.log(`UID: ${user.uid}`);
        console.log(`Display Name: ${user.displayName || 'Not set'}`);
        console.log(`Email Verified: ${user.emailVerified}`);
        console.log(`Disabled: ${user.disabled}`);
        console.log(`Created: ${user.metadata.creationTime}`);
        console.log(`Last Sign In: ${user.metadata.lastSignInTime}`);
        
        console.log('Providers:');
        for (const provider of user.providerData) {
          console.log(`  - ${provider.providerId} (${provider.uid})`);
        }
        
        // Check if user has password
        if (user.providerData.some(p => p.providerId === 'password')) {
          console.log('✓ Has password authentication');
        } else {
          console.log('✗ No password authentication (Google Sign-In only)');
        }
        
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          console.log(`\n=== ${email} ===`);
          console.log('✗ User not found in Authentication');
        } else {
          console.log(`\n=== ${email} ===`);
          console.log(`❌ Error: ${error.message}`);
        }
      }
    }
    
  } catch (error) {
    console.error('Error checking users:', error);
  }
}

checkUserMethods(); 