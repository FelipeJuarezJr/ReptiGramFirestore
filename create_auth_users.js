const admin = require('firebase-admin');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
});

const auth = app.auth();
const db = app.firestore();

async function createAuthUsers() {
  try {
    console.log('Reading users from Firestore and creating Auth accounts...');
    
    // Get all users from Firestore
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.docs.length} users in Firestore`);
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const firestoreUid = userDoc.id;
      const email = userData.email;
      
      if (!email) {
        console.log(`Skipping user ${firestoreUid} - no email found`);
        continue;
      }
      
      console.log(`Processing user: ${email} (Firestore UID: ${firestoreUid})`);
      
      // Check if user already exists in Auth
      try {
        const existingAuthUser = await auth.getUserByEmail(email);
        console.log(`  ✓ User ${email} already exists in Auth (UID: ${existingAuthUser.uid})`);
        
        // If UIDs don't match, we need to update the Firestore document
        if (existingAuthUser.uid !== firestoreUid) {
          console.log(`  ⚠️  UID mismatch! Auth UID: ${existingAuthUser.uid}, Firestore UID: ${firestoreUid}`);
          console.log(`  Updating Firestore document to use Auth UID...`);
          
          // Copy data to new document with Auth UID
          await db.collection('users').doc(existingAuthUser.uid).set({
            ...userData,
            uid: existingAuthUser.uid,
            originalFirestoreUid: firestoreUid, // Keep reference to original
          });
          
          // Delete old document
          await db.collection('users').doc(firestoreUid).delete();
          console.log(`  ✓ Updated Firestore document to use Auth UID`);
        }
        
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          console.log(`  ✗ User ${email} not found in Auth, creating...`);
          
          try {
            // Create user in Auth
            const authUser = await auth.createUser({
              email: email,
              password: 'password123', // Temporary password
              displayName: userData.displayName || userData.username || 'User',
              emailVerified: true,
            });
            
            console.log(`  ✓ Created Auth user: ${authUser.uid}`);
            
            // Update Firestore document to use new Auth UID
            await db.collection('users').doc(authUser.uid).set({
              ...userData,
              uid: authUser.uid,
              originalFirestoreUid: firestoreUid, // Keep reference to original
            });
            
            // Delete old document if UIDs are different
            if (authUser.uid !== firestoreUid) {
              await db.collection('users').doc(firestoreUid).delete();
            }
            
            console.log(`  ✓ Updated Firestore document with new Auth UID`);
            console.log(`  📧 User can login with: ${email} / password123`);
            
          } catch (createError) {
            console.log(`  ❌ Failed to create Auth user: ${createError.message}`);
          }
        } else {
          console.log(`  ❌ Error checking Auth user: ${error.message}`);
        }
      }
    }
    
    console.log('\n=== SUMMARY ===');
    console.log('Users have been processed. For any newly created accounts:');
    console.log('- Email: [user email]');
    console.log('- Password: password123');
    console.log('- Users should change password after first login');
    console.log('\nNext steps:');
    console.log('1. Test login with the credentials above');
    console.log('2. Enable password reset in Firebase Console');
    console.log('3. Consider enabling Google Sign-In for easier access');
    
  } catch (error) {
    console.error('Error processing users:', error);
  }
}

createAuthUsers(); 