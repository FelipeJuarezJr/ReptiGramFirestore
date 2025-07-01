const admin = require('firebase-admin');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
});

const auth = app.auth();
const db = app.firestore();

async function checkUsers() {
  try {
    console.log('Checking users in reptigramfirestore project...');
    
    // Get all users from current project
    const listUsersResult = await auth.listUsers();
    console.log(`Found ${listUsersResult.users.length} users in current project:`);
    
    for (const userRecord of listUsersResult.users) {
      console.log(`- ${userRecord.email} (${userRecord.uid})`);
      console.log(`  Display Name: ${userRecord.displayName || 'Not set'}`);
      console.log(`  Email Verified: ${userRecord.emailVerified}`);
      console.log(`  Provider: ${userRecord.providerData.map(p => p.providerId).join(', ')}`);
      console.log(`  Created: ${userRecord.metadata.creationTime}`);
      console.log('');
    }
    
    // Check if specific users exist
    const testEmails = ['gecko1@gmail.com', 'tester@example.com'];
    
    for (const email of testEmails) {
      try {
        const user = await auth.getUserByEmail(email);
        console.log(`✓ User ${email} EXISTS in current project (UID: ${user.uid})`);
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          console.log(`✗ User ${email} NOT FOUND in current project`);
        } else {
          console.log(`? Error checking ${email}: ${error.message}`);
        }
      }
    }
    
  } catch (error) {
    console.error('Error checking users:', error);
  }
}

checkUsers(); 