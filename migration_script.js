const admin = require('firebase-admin');
const fs = require('fs');

// Load both service account keys
const rtdbServiceAccount = require('./service-account-key-rtdb.json'); // For reading from reptigram-lite
const firestoreServiceAccount = require('./service-account-key.json'); // For writing to reptigramfirestore

// Initialize Realtime Database connection (reptigram-lite)
const rtdbApp = admin.initializeApp({
  credential: admin.credential.cert(rtdbServiceAccount),
  databaseURL: 'https://reptigram-lite-default-rtdb.firebaseio.com'
}, 'rtdb');

// Initialize Firestore connection (reptigramfirestore)
const firestoreApp = admin.initializeApp({
  credential: admin.credential.cert(firestoreServiceAccount),
  projectId: 'reptigramfirestore'
}, 'firestore');

const db = admin.app('rtdb').database(); // Source: reptigram-lite Realtime Database
const firestore = admin.app('firestore').firestore(); // Target: reptigramfirestore Firestore

// Migration configuration
const BATCH_SIZE = 500; // Firestore batch limit
const DELAY_BETWEEN_BATCHES = 1000; // 1 second delay between batches

// Helper function to delay execution
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Helper function to convert Realtime Database data to Firestore format
const convertToFirestoreFormat = (data) => {
  if (data === null || data === undefined) return null;
  if (typeof data === 'object' && !Array.isArray(data)) {
    const converted = {};
    for (const [key, value] of Object.entries(data)) {
      converted[key] = convertToFirestoreFormat(value);
    }
    return converted;
  }
  return data;
};

// Helper function to write batch to Firestore
const writeBatch = async (batch) => {
  try {
    await batch.commit();
    console.log(`✅ Batch committed successfully`);
  } catch (error) {
    console.error(`❌ Error committing batch:`, error);
    throw error;
  }
};

// Migration function for users collection
const migrateUsers = async () => {
  console.log('🔄 Starting users migration...');
  
  try {
    const usersSnapshot = await db.ref('users').once('value');
    const users = usersSnapshot.val();
    
    if (!users) {
      console.log('ℹ️ No users found to migrate');
      return;
    }
    
    let batch = firestore.batch();
    let batchCount = 0;
    let totalUsers = 0;
    
    for (const [userId, userData] of Object.entries(users)) {
      if (!userData) continue;
      
      const userRef = firestore.collection('users').doc(userId);
      const convertedData = convertToFirestoreFormat(userData);
      
      // Add createdAt timestamp if not present
      if (!convertedData.createdAt) {
        convertedData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }
      
      batch.set(userRef, convertedData);
      batchCount++;
      totalUsers++;
      
      if (batchCount >= BATCH_SIZE) {
        await writeBatch(batch);
        batch = firestore.batch();
        batchCount = 0;
        await delay(DELAY_BETWEEN_BATCHES);
      }
    }
    
    // Write remaining documents
    if (batchCount > 0) {
      await writeBatch(batch);
    }
    
    console.log(`✅ Users migration completed: ${totalUsers} users migrated`);
  } catch (error) {
    console.error('❌ Error migrating users:', error);
    throw error;
  }
};

// Migration function for usernames collection
const migrateUsernames = async () => {
  console.log('🔄 Starting usernames migration...');
  
  try {
    const usernamesSnapshot = await db.ref('usernames').once('value');
    const usernames = usernamesSnapshot.val();
    
    if (!usernames) {
      console.log('ℹ️ No usernames found to migrate');
      return;
    }
    
    let batch = firestore.batch();
    let batchCount = 0;
    let totalUsernames = 0;
    
    for (const [username, userId] of Object.entries(usernames)) {
      if (!userId) continue;
      
      const usernameRef = firestore.collection('usernames').doc(username);
      batch.set(usernameRef, { userId });
      batchCount++;
      totalUsernames++;
      
      if (batchCount >= BATCH_SIZE) {
        await writeBatch(batch);
        batch = firestore.batch();
        batchCount = 0;
        await delay(DELAY_BETWEEN_BATCHES);
      }
    }
    
    // Write remaining documents
    if (batchCount > 0) {
      await writeBatch(batch);
    }
    
    console.log(`✅ Usernames migration completed: ${totalUsernames} usernames migrated`);
  } catch (error) {
    console.error('❌ Error migrating usernames:', error);
    throw error;
  }
};

// Migration function for posts collection
const migratePosts = async () => {
  console.log('🔄 Starting posts migration...');
  
  try {
    const postsSnapshot = await db.ref('posts').once('value');
    const posts = postsSnapshot.val();
    
    if (!posts) {
      console.log('ℹ️ No posts found to migrate');
      return;
    }
    
    let batch = firestore.batch();
    let batchCount = 0;
    let totalPosts = 0;
    
    for (const [postId, postData] of Object.entries(posts)) {
      if (!postData) continue;
      
      const postRef = firestore.collection('posts').doc(postId);
      const convertedData = convertToFirestoreFormat(postData);
      
      // Add postId to the document
      convertedData.postId = postId;
      
      // Convert likes object to array if it exists
      if (convertedData.likes && typeof convertedData.likes === 'object') {
        convertedData.likes = Object.keys(convertedData.likes);
      }
      
      // Process comments if they exist
      if (convertedData.comments && typeof convertedData.comments === 'object') {
        const comments = [];
        for (const [commentId, commentData] of Object.entries(convertedData.comments)) {
          if (commentData && typeof commentData === 'object') {
            comments.push({
              commentId,
              ...commentData
            });
          }
        }
        convertedData.comments = comments;
      }
      
      batch.set(postRef, convertedData);
      batchCount++;
      totalPosts++;
      
      if (batchCount >= BATCH_SIZE) {
        await writeBatch(batch);
        batch = firestore.batch();
        batchCount = 0;
        await delay(DELAY_BETWEEN_BATCHES);
      }
    }
    
    // Write remaining documents
    if (batchCount > 0) {
      await writeBatch(batch);
    }
    
    console.log(`✅ Posts migration completed: ${totalPosts} posts migrated`);
  } catch (error) {
    console.error('❌ Error migrating posts:', error);
    throw error;
  }
};

// Main migration function
const runMigration = async () => {
  console.log('🚀 Starting Firebase Realtime Database to Firestore migration...');
  console.log('📋 This will migrate: users, usernames, and posts');
  console.log('');
  
  const startTime = Date.now();
  
  try {
    // Run migrations in order
    await migrateUsers();
    await delay(DELAY_BETWEEN_BATCHES);
    
    await migrateUsernames();
    await delay(DELAY_BETWEEN_BATCHES);
    
    await migratePosts();
    
    const endTime = Date.now();
    const duration = (endTime - startTime) / 1000;
    
    console.log('');
    console.log('🎉 Migration completed successfully!');
    console.log(`⏱️ Total time: ${duration} seconds`);
    console.log('');
    console.log('📝 Next steps:');
    console.log('1. Verify the data in Firestore Console');
    console.log('2. Update your app to use Firestore instead of Realtime Database');
    console.log('3. Test your app thoroughly');
    console.log('4. Consider backing up your Realtime Database before switching');
    
  } catch (error) {
    console.error('💥 Migration failed:', error);
    process.exit(1);
  }
};

// Run the migration
runMigration();