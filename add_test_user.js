const admin = require('firebase-admin');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
});

const auth = app.auth();
const db = app.firestore();

async function addTestUser() {
  try {
    console.log('Adding test user gecko1@gmail.com...');
    
    // Check if user already exists
    try {
      const existingUser = await auth.getUserByEmail('gecko1@gmail.com');
      console.log(`User gecko1@gmail.com already exists with UID: ${existingUser.uid}`);
      return;
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log('User not found, creating new user...');
      } else {
        throw error;
      }
    }
    
    // Create the user
    const userRecord = await auth.createUser({
      email: 'gecko1@gmail.com',
      password: 'password123', // Temporary password
      displayName: 'Gecko User',
      emailVerified: true,
    });
    
    console.log(`Successfully created user: ${userRecord.uid}`);
    
    // Create user document in Firestore
    await db.collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      email: 'gecko1@gmail.com',
      username: 'gecko1',
      displayName: 'Gecko User',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('User document created in Firestore');
    console.log('\nUser can now login with:');
    console.log('Email: gecko1@gmail.com');
    console.log('Password: password123');
    console.log('\nIMPORTANT: User should change password after first login!');
    
  } catch (error) {
    console.error('Error adding user:', error);
  }
}

addTestUser(); 