const admin = require('firebase-admin');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
});

const auth = app.auth();
const db = admin.firestore();

async function verifyCleanup() {
  try {
    console.log('Verifying duplicate user cleanup...\n');
    
    // Get all users from Firestore
    const usersSnapshot = await db.collection('users').get();
    const users = usersSnapshot.docs;
    
    console.log(`Total users in Firestore: ${users.length}`);
    
    // Group users by email
    const usersByEmail = {};
    users.forEach(doc => {
      const userData = doc.data();
      const email = userData.email;
      if (email) {
        if (!usersByEmail[email]) {
          usersByEmail[email] = [];
        }
        usersByEmail[email].push({
          id: doc.id,
          data: userData
        });
      }
    });
    
    console.log('\nUsers by email:');
    Object.keys(usersByEmail).forEach(email => {
      const userList = usersByEmail[email];
      console.log(`\n${email}:`);
      userList.forEach(user => {
        console.log(`  - UID: ${user.id}`);
        console.log(`    Display Name: ${user.data.displayName || user.data.username || 'No Name'}`);
        console.log(`    Last Login: ${user.data.lastLogin?.toDate?.() || 'Never'}`);
        console.log(`    Created: ${user.data.createdAt?.toDate?.() || 'Unknown'}`);
      });
    });
    
    // Check for duplicates
    const duplicates = Object.keys(usersByEmail).filter(email => usersByEmail[email].length > 1);
    
    if (duplicates.length === 0) {
      console.log('\n✅ SUCCESS: No duplicate users found!');
    } else {
      console.log('\n❌ ISSUE: Found duplicate users for emails:');
      duplicates.forEach(email => {
        console.log(`  - ${email}: ${usersByEmail[email].length} users`);
      });
    }
    
    // Check specific problematic emails
    const problematicEmails = ['mr.felipe.juarez.jr@gmail.com', 'gecko1@gmail.com'];
    
    console.log('\nChecking specific emails:');
    problematicEmails.forEach(email => {
      const userList = usersByEmail[email] || [];
      if (userList.length === 1) {
        console.log(`✅ ${email}: 1 user (${userList[0].id})`);
      } else if (userList.length === 0) {
        console.log(`⚠️  ${email}: No users found`);
      } else {
        console.log(`❌ ${email}: ${userList.length} users (still has duplicates)`);
      }
    });
    
    // Check chat collections
    console.log('\nChecking chat collections...');
    const collections = await db.listCollections();
    const chatCollections = collections.filter(col => col.id.startsWith('chat_'));
    
    console.log(`Found ${chatCollections.length} chat collections`);
    
    // Sample a few chat collections to verify they exist
    if (chatCollections.length > 0) {
      console.log('\nSample chat collections:');
      const sampleCollections = chatCollections.slice(0, 5);
      
      for (const collection of sampleCollections) {
        const messages = await collection.get();
        console.log(`  ${collection.id}: ${messages.docs.length} messages`);
      }
    }
    
    console.log('\n=== VERIFICATION COMPLETE ===');
    
  } catch (error) {
    console.error('Error during verification:', error);
  }
}

// Run the verification
verifyCleanup().then(() => {
  console.log('Verification process finished');
  process.exit(0);
}).catch((error) => {
  console.error('Verification failed:', error);
  process.exit(1);
}); 