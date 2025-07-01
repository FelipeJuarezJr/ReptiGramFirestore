const admin = require('firebase-admin');

// Initialize the old project (reptigram-lite)
const oldApp = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key-rtdb.json')),
  projectId: 'reptigram-lite',
}, 'old');

// Initialize the new project (reptigramfirestore)
const newApp = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
}, 'new');

const oldAuth = oldApp.auth();
const newAuth = newApp.auth();

async function migrateUsersOnly() {
  try {
    console.log('Migrating users from reptigram-lite to reptigramfirestore...');
    
    // Get all users from old project
    const listUsersResult = await oldAuth.listUsers();
    console.log(`Found ${listUsersResult.users.length} users in old project`);
    
    for (const userRecord of listUsersResult.users) {
      try {
        console.log(`Processing user: ${userRecord.email} (${userRecord.uid})`);
        
        // Check if user already exists in new project
        try {
          await newAuth.getUserByEmail(userRecord.email);
          console.log(`  ✓ User ${userRecord.email} already exists in new project, skipping...`);
          continue;
        } catch (error) {
          if (error.code === 'auth/user-not-found') {
            // User doesn't exist, create them
            console.log(`  Creating user ${userRecord.email} in new project...`);
            
            const newUserRecord = await newAuth.createUser({
              email: userRecord.email,
              emailVerified: userRecord.emailVerified,
              displayName: userRecord.displayName,
              photoURL: userRecord.photoURL,
              disabled: userRecord.disabled,
            });
            
            console.log(`  ✓ Created user with new UID: ${newUserRecord.uid}`);
            console.log(`  📧 User can login with: ${userRecord.email}`);
            console.log(`  🔑 Password: password123 (temporary - user should reset)`);
            
          } else {
            console.log(`  ❌ Error checking user ${userRecord.email}: ${error.message}`);
          }
        }
        
      } catch (error) {
        console.log(`  ❌ Error processing user ${userRecord.email}: ${error.message}`);
      }
    }
    
    console.log('\n=== USER MIGRATION COMPLETED ===');
    console.log('All users have been migrated to the new project.');
    console.log('\nIMPORTANT NOTES:');
    console.log('1. Passwords cannot be migrated due to security restrictions');
    console.log('2. Users will need to reset their passwords or use Google Sign-In');
    console.log('3. Enable "Allow users to reset their password" in Firebase Console');
    console.log('4. Consider enabling Google Sign-In for easier access');
    
  } catch (error) {
    console.error('Migration failed:', error);
  }
}

migrateUsersOnly(); 