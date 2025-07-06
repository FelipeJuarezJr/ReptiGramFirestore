const admin = require('firebase-admin');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
});

const auth = app.auth();
const db = admin.firestore();

async function cleanupDuplicateUsers() {
  try {
    console.log('Starting comprehensive duplicate user cleanup...');
    
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    const users = usersSnapshot.docs;
    
    console.log(`Found ${users.length} total users`);
    
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
          data: userData,
          doc: doc
        });
      }
    });
    
    // Find duplicates
    const duplicates = [];
    Object.keys(usersByEmail).forEach(email => {
      if (usersByEmail[email].length > 1) {
        duplicates.push({
          email: email,
          users: usersByEmail[email]
        });
      }
    });
    
    console.log(`Found ${duplicates.length} emails with duplicate users`);
    
    // Process duplicates
    for (const duplicate of duplicates) {
      console.log(`\nProcessing duplicates for email: ${duplicate.email}`);
      
      // Sort by creation time and last login (keep the most active one)
      const sortedUsers = duplicate.users.sort((a, b) => {
        const aTime = a.data.lastLogin?.toDate?.() || a.data.createdAt?.toDate?.() || new Date(0);
        const bTime = b.data.lastLogin?.toDate?.() || b.data.createdAt?.toDate?.() || new Date(0);
        return bTime - aTime; // Keep most recent
      });
      
      const keepUser = sortedUsers[0];
      const deleteUsers = sortedUsers.slice(1);
      
      console.log(`Keeping user: ${keepUser.id} (most recent)`);
      console.log(`Deleting users: ${deleteUsers.map(u => u.id).join(', ')}`);
      
      // Merge user data from all duplicates into the kept user
      const mergedData = { ...keepUser.data };
      
      for (const deleteUser of deleteUsers) {
        // Merge user data (prefer non-null values from kept user)
        Object.keys(deleteUser.data).forEach(key => {
          if (mergedData[key] === null || mergedData[key] === undefined || mergedData[key] === '') {
            mergedData[key] = deleteUser.data[key];
          }
        });
      }
      
      // Update the kept user with merged data
      await db.collection('users').doc(keepUser.id).set(mergedData);
      console.log(`Updated kept user with merged data`);
      
      // Migrate chat data for each deleted user
      for (const deleteUser of deleteUsers) {
        console.log(`Migrating chat data for user: ${deleteUser.id}`);
        
        // Get all chat collections that contain this user's UID
        const chatCollections = await db.listCollections();
        
        for (const collection of chatCollections) {
          if (collection.id === 'chats') {
            // Handle chat collection
            const chatDocs = await collection.where('participants', 'array-contains', deleteUser.id).get();
            
            for (const chatDoc of chatDocs.docs) {
              const chatData = chatDoc.data();
              const participants = chatData.participants || [];
              
              // Replace the deleted user's UID with the kept user's UID
              const updatedParticipants = participants.map(uid => 
                uid === deleteUser.id ? keepUser.id : uid
              );
              
              // Update the chat document
              await chatDoc.ref.update({
                participants: updatedParticipants
              });
              
              console.log(`Updated chat ${chatDoc.id} participants`);
            }
          } else if (collection.id.startsWith('chat_')) {
            // Handle individual chat collections (chat_uid1_uid2 format)
            const chatDocs = await collection.get();
            
            for (const chatDoc of chatDocs.docs) {
              const chatData = chatDoc.data();
              
              // Check if this message involves the deleted user
              if (chatData.senderId === deleteUser.id) {
                // Update sender ID to kept user
                await chatDoc.ref.update({
                  senderId: keepUser.id
                });
                console.log(`Updated message ${chatDoc.id} sender`);
              }
            }
          }
        }
        
        // Delete the duplicate user document
        await db.collection('users').doc(deleteUser.id).delete();
        console.log(`Deleted user: ${deleteUser.id}`);
      }
    }
    
    console.log('\n=== CLEANUP COMPLETED ===');
    console.log('All duplicate users have been cleaned up.');
    console.log('Chat data has been migrated to the kept users.');
    
  } catch (error) {
    console.error('Error during cleanup:', error);
  }
}

// Run the cleanup
cleanupDuplicateUsers().then(() => {
  console.log('Cleanup process finished');
  process.exit(0);
}).catch((error) => {
  console.error('Cleanup failed:', error);
  process.exit(1);
}); 