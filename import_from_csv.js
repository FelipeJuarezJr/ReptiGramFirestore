const admin = require('firebase-admin');
const fs = require('fs');
const csv = require('csv-parser');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
});

const auth = app.auth();
const db = app.firestore();

async function importFromCSV() {
  try {
    console.log('Importing users from CSV...');
    
    const users = [];
    
    // Read CSV file
    fs.createReadStream('users_to_migrate.csv')
      .pipe(csv())
      .on('data', (row) => {
        users.push(row);
      })
      .on('end', async () => {
        console.log(`Found ${users.length} users in CSV`);
        
        for (const userData of users) {
          try {
            console.log(`\nProcessing: ${userData.email}`);
            
            // Check if user already exists
            try {
              const existingUser = await auth.getUserByEmail(userData.email);
              console.log(`  ✓ User already exists (UID: ${existingUser.uid})`);
              continue;
            } catch (error) {
              if (error.code === 'auth/user-not-found') {
                // User doesn't exist, create them
                console.log(`  Creating user: ${userData.email}`);
                
                const userRecord = await auth.createUser({
                  email: userData.email,
                  password: 'password123', // Temporary password
                  displayName: userData.displayName,
                  emailVerified: userData.emailVerified === 'true',
                  disabled: userData.disabled === 'true',
                });
                
                console.log(`  ✓ Created user: ${userRecord.uid}`);
                
                // Create user document in Firestore
                await db.collection('users').doc(userRecord.uid).set({
                  uid: userRecord.uid,
                  email: userData.email,
                  username: userData.email.split('@')[0], // Use email prefix as username
                  displayName: userData.displayName,
                  createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                
                console.log(`  ✓ Created Firestore document`);
                console.log(`  📧 Login: ${userData.email} / password123`);
                
              } else {
                console.log(`  ❌ Error checking user: ${error.message}`);
              }
            }
            
          } catch (error) {
            console.log(`  ❌ Error processing ${userData.email}: ${error.message}`);
          }
        }
        
        console.log('\n=== MIGRATION COMPLETED ===');
        console.log('All users have been processed.');
        console.log('Users can login with:');
        console.log('- Email: [their email]');
        console.log('- Password: password123');
        console.log('\nNext steps:');
        console.log('1. Test login with the credentials above');
        console.log('2. Enable password reset in Firebase Console');
        console.log('3. Users should change passwords after first login');
        
      });
      
  } catch (error) {
    console.error('Import failed:', error);
  }
}

importFromCSV(); 