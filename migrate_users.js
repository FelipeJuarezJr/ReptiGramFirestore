const admin = require('firebase-admin');

// Initialize the old project ([OLD_PROJECT_ID])
const oldApp = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key-rtdb.json')),
  projectId: '[OLD_PROJECT_ID]',
}, 'old');

// Initialize the new project (reptigramfirestore)
const newApp = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
}, 'new');

const oldAuth = oldApp.auth();
const newAuth = newApp.auth();
const oldDb = oldApp.firestore();
const newDb = newApp.firestore();

async function migrateUsers() {
  try {
    console.log('Starting user migration from [OLD_PROJECT_ID] to reptigramfirestore...');
    
    // Get all users from old project
    const listUsersResult = await oldAuth.listUsers();
    console.log(`Found ${listUsersResult.users.length} users in old project`);
    
    for (const userRecord of listUsersResult.users) {
      try {
        console.log(`Processing user: ${userRecord.email} (${userRecord.uid})`);
        
        // Check if user already exists in new project
        try {
          await newAuth.getUserByEmail(userRecord.email);
          console.log(`  User ${userRecord.email} already exists in new project, skipping...`);
          continue;
        } catch (error) {
          if (error.code === 'auth/user-not-found') {
            // User doesn't exist, we can create them
            console.log(`  Creating user ${userRecord.email} in new project...`);
            
            // Create user in new project
            const newUserRecord = await newAuth.createUser({
              email: userRecord.email,
              emailVerified: userRecord.emailVerified,
              displayName: userRecord.displayName,
              photoURL: userRecord.photoURL,
              disabled: userRecord.disabled,
            });
            
            console.log(`  Created user with new UID: ${newUserRecord.uid}`);
            
            // Note: We cannot migrate passwords due to security restrictions
            // Users will need to reset their password or use Google Sign-In
            
            // Migrate user data from Firestore if it exists
            try {
              const oldUserDoc = await oldDb.collection('users').doc(userRecord.uid).get();
              if (oldUserDoc.exists) {
                const userData = oldUserDoc.data();
                await newDb.collection('users').doc(newUserRecord.uid).set({
                  ...userData,
                  uid: newUserRecord.uid, // Update UID reference
                });
                console.log(`  Migrated user data for ${userRecord.email}`);
              }
            } catch (error) {
              console.log(`  No user data to migrate for ${userRecord.email}: ${error.message}`);
            }
            
          } else {
            console.log(`  Error checking user ${userRecord.email}: ${error.message}`);
          }
        }
        
      } catch (error) {
        console.log(`  Error processing user ${userRecord.email}: ${error.message}`);
      }
    }
    
    console.log('User migration completed!');
    console.log('\nIMPORTANT NOTES:');
    console.log('1. Passwords cannot be migrated due to security restrictions');
    console.log('2. Users will need to reset their passwords or use Google Sign-In');
    console.log('3. You should enable "Allow users to reset their password" in Firebase Console');
    console.log('4. Consider enabling Google Sign-In for easier user access');
    
  } catch (error) {
    console.error('Migration failed:', error);
  }
}

migrateUsers(); 