const admin = require('firebase-admin');

// Initialize the old project ([OLD_PROJECT_ID] with Realtime Database)
const oldApp = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key-rtdb.json')),
  projectId: '[OLD_PROJECT_ID]',
  databaseURL: 'https://[OLD_PROJECT_ID]-default-rtdb.firebaseio.com', // Realtime Database URL
}, 'old');

// Initialize the new project (reptigramfirestore with Firestore)
const newApp = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
}, 'new');

const oldAuth = oldApp.auth();
const newAuth = newApp.auth();
const oldDb = oldApp.database(); // Realtime Database
const newDb = newApp.firestore(); // Firestore

async function migrateFromRealtimeToFirestore() {
  try {
    console.log('Starting migration from Realtime Database to Firestore...');
    
    // Step 1: Migrate Authentication Users
    console.log('\n=== STEP 1: MIGRATING USERS ===');
    await migrateUsers();
    
    // Step 2: Migrate Data from Realtime Database to Firestore
    console.log('\n=== STEP 2: MIGRATING DATA ===');
    await migrateData();
    
    console.log('\n=== MIGRATION COMPLETED ===');
    
  } catch (error) {
    console.error('Migration failed:', error);
  }
}

async function migrateUsers() {
  try {
    console.log('Migrating users from [OLD_PROJECT_ID] to reptigramfirestore...');
    
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
            
            // Note: Passwords cannot be migrated due to security restrictions
            console.log(`  📧 User will need to reset password or use Google Sign-In`);
            
          } else {
            console.log(`  ❌ Error checking user ${userRecord.email}: ${error.message}`);
          }
        }
        
      } catch (error) {
        console.log(`  ❌ Error processing user ${userRecord.email}: ${error.message}`);
      }
    }
    
  } catch (error) {
    console.error('Error migrating users:', error);
  }
}

async function migrateData() {
  try {
    console.log('Migrating data from Realtime Database to Firestore...');
    
    // Get all data from Realtime Database
    const snapshot = await oldDb.ref().once('value');
    const data = snapshot.val();
    
    if (!data) {
      console.log('No data found in Realtime Database');
      return;
    }
    
    console.log('Found data in Realtime Database, migrating to Firestore...');
    
    // Migrate users data
    if (data.users) {
      console.log('Migrating users data...');
      for (const [uid, userData] of Object.entries(data.users)) {
        try {
          // Check if user exists in new Auth
          try {
            const newUser = await newAuth.getUserByEmail(userData.email);
            console.log(`  Migrating user data for ${userData.email} (${newUser.uid})`);
            
            // Create user document in Firestore with new UID
            await newDb.collection('users').doc(newUser.uid).set({
              ...userData,
              uid: newUser.uid,
              originalUid: uid, // Keep reference to original UID
              migratedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            
            console.log(`  ✓ Migrated user data for ${userData.email}`);
            
          } catch (error) {
            if (error.code === 'auth/user-not-found') {
              console.log(`  ⚠️  User ${userData.email} not found in new Auth, skipping data migration`);
            } else {
              console.log(`  ❌ Error migrating user ${userData.email}: ${error.message}`);
            }
          }
        } catch (error) {
          console.log(`  ❌ Error processing user data for ${uid}: ${error.message}`);
        }
      }
    }
    
    // Migrate posts data
    if (data.posts) {
      console.log('Migrating posts data...');
      for (const [postId, postData] of Object.entries(data.posts)) {
        try {
          console.log(`  Migrating post: ${postId}`);
          
          // Create post document in Firestore
          await newDb.collection('posts').doc(postId).set({
            ...postData,
            migratedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          console.log(`  ✓ Migrated post: ${postId}`);
          
        } catch (error) {
          console.log(`  ❌ Error migrating post ${postId}: ${error.message}`);
        }
      }
    }
    
    // Migrate comments data (if they exist as separate collection)
    if (data.comments) {
      console.log('Migrating comments data...');
      for (const [commentId, commentData] of Object.entries(data.comments)) {
        try {
          console.log(`  Migrating comment: ${commentId}`);
          
          // Create comment document in Firestore
          await newDb.collection('comments').doc(commentId).set({
            ...commentData,
            migratedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          console.log(`  ✓ Migrated comment: ${commentId}`);
          
        } catch (error) {
          console.log(`  ❌ Error migrating comment ${commentId}: ${error.message}`);
        }
      }
    }
    
    // Migrate likes data (if they exist as separate collection)
    if (data.likes) {
      console.log('Migrating likes data...');
      for (const [likeId, likeData] of Object.entries(data.likes)) {
        try {
          console.log(`  Migrating like: ${likeId}`);
          
          // Create like document in Firestore
          await newDb.collection('likes').doc(likeId).set({
            ...likeData,
            migratedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          console.log(`  ✓ Migrated like: ${likeId}`);
          
        } catch (error) {
          console.log(`  ❌ Error migrating like ${likeId}: ${error.message}`);
        }
      }
    }
    
    // Migrate photos data (if they exist)
    if (data.photos) {
      console.log('Migrating photos data...');
      for (const [photoId, photoData] of Object.entries(data.photos)) {
        try {
          console.log(`  Migrating photo: ${photoId}`);
          
          // Create photo document in Firestore
          await newDb.collection('photos').doc(photoId).set({
            ...photoData,
            migratedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          console.log(`  ✓ Migrated photo: ${photoId}`);
          
        } catch (error) {
          console.log(`  ❌ Error migrating photo ${photoId}: ${error.message}`);
        }
      }
    }
    
    console.log('Data migration completed!');
    
  } catch (error) {
    console.error('Error migrating data:', error);
  }
}

migrateFromRealtimeToFirestore(); 