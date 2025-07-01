const admin = require('firebase-admin');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
});

const auth = app.auth();
const db = app.firestore();

async function addUsersFromList() {
  try {
    console.log('Adding users to reptigramfirestore project...');
    
    // List of users to add
    const usersToAdd = [
      'felipe.juarez.jr@outlook.com',
      'reptigram@gmail.com',
      'mr.felipe.juarez.jr@gmail.com',
      'geckoace@gmail.com',
      'gecko3@gmail.com',
      'joe@wildcardgeckos.com',
      'junior@gmail.com',
      'testy@gmail.com',
      'flippy@gmail.com',
      'flipper@gmail.com',
      'flip@gmail.com'
    ];
    
    const tempPassword = 'password123';
    
    for (const email of usersToAdd) {
      try {
        console.log(`\nProcessing: ${email}`);
        
        // Check if user already exists
        try {
          const existingUser = await auth.getUserByEmail(email);
          console.log(`  ✓ User already exists (UID: ${existingUser.uid})`);
          
          // Update password for existing user
          await auth.updateUser(existingUser.uid, {
            password: tempPassword,
          });
          console.log(`  🔑 Updated password for existing user`);
          
        } catch (error) {
          if (error.code === 'auth/user-not-found') {
            // User doesn't exist, create them
            console.log(`  Creating new user: ${email}`);
            
            const userRecord = await auth.createUser({
              email: email,
              password: tempPassword,
              displayName: email.split('@')[0], // Use email prefix as display name
              emailVerified: true,
            });
            
            console.log(`  ✓ Created user: ${userRecord.uid}`);
            
            // Create user document in Firestore
            await db.collection('users').doc(userRecord.uid).set({
              uid: userRecord.uid,
              email: email,
              username: email.split('@')[0], // Use email prefix as username
              displayName: email.split('@')[0],
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            
            console.log(`  ✓ Created Firestore document`);
            
          } else {
            console.log(`  ❌ Error checking user: ${error.message}`);
          }
        }
        
        console.log(`  📧 Login: ${email} / ${tempPassword}`);
        
      } catch (error) {
        console.log(`  ❌ Error processing ${email}: ${error.message}`);
      }
    }
    
    console.log('\n=== USER ADDITION COMPLETED ===');
    console.log('All users have been added to the project.');
    console.log('\nLOGIN CREDENTIALS:');
    console.log('All users can login with:');
    console.log('- Email: [their email]');
    console.log('- Password: password123');
    console.log('\nNEXT STEPS:');
    console.log('1. Test login with the credentials above');
    console.log('2. Enable password reset in Firebase Console');
    console.log('3. Users should change passwords after first login');
    console.log('4. Consider enabling Google Sign-In for easier access');
    
  } catch (error) {
    console.error('Error adding users:', error);
  }
}

addUsersFromList(); 