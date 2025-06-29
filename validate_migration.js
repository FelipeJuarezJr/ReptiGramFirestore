const admin = require('firebase-admin');

// Initialize Firebase Admin SDK (same as migration script)
const serviceAccount = require('./service-account-key.json');

// Initialize with reptigramfirestore project (for Firestore writes)
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'reptigramfirestore' // Target Firestore project
});

// Initialize separate Realtime Database connection to reptigram-lite (source)
const rtdbApp = admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://reptigram-lite-default-rtdb.firebaseio.com' // Source Realtime Database
}, 'rtdb');

const db = admin.app('rtdb').database(); // Source: reptigram-lite Realtime Database
const firestore = admin.firestore(); // Target: reptigramfirestore Firestore

// Validation functions
const validateUsers = async () => {
  console.log('🔍 Validating users migration...');
  
  try {
    // Get Realtime Database users count
    const rtdbUsersSnapshot = await db.ref('users').once('value');
    const rtdbUsers = rtdbUsersSnapshot.val();
    const rtdbUserCount = rtdbUsers ? Object.keys(rtdbUsers).length : 0;
    
    // Get Firestore users count
    const fsUsersSnapshot = await firestore.collection('users').get();
    const fsUserCount = fsUsersSnapshot.size;
    
    console.log(`📊 Realtime Database users: ${rtdbUserCount}`);
    console.log(`📊 Firestore users: ${fsUserCount}`);
    
    if (rtdbUserCount === fsUserCount) {
      console.log('✅ Users count matches!');
    } else {
      console.log('❌ Users count mismatch!');
    }
    
    return { rtdb: rtdbUserCount, firestore: fsUserCount, match: rtdbUserCount === fsUserCount };
  } catch (error) {
    console.error('❌ Error validating users:', error);
    return { error: error.message };
  }
};

const validateUsernames = async () => {
  console.log('🔍 Validating usernames migration...');
  
  try {
    // Get Realtime Database usernames count
    const rtdbUsernamesSnapshot = await db.ref('usernames').once('value');
    const rtdbUsernames = rtdbUsernamesSnapshot.val();
    const rtdbUsernameCount = rtdbUsernames ? Object.keys(rtdbUsernames).length : 0;
    
    // Get Firestore usernames count
    const fsUsernamesSnapshot = await firestore.collection('usernames').get();
    const fsUsernameCount = fsUsernamesSnapshot.size;
    
    console.log(`📊 Realtime Database usernames: ${rtdbUsernameCount}`);
    console.log(`📊 Firestore usernames: ${fsUsernameCount}`);
    
    if (rtdbUsernameCount === fsUsernameCount) {
      console.log('✅ Usernames count matches!');
    } else {
      console.log('❌ Usernames count mismatch!');
    }
    
    return { rtdb: rtdbUsernameCount, firestore: fsUsernameCount, match: rtdbUsernameCount === fsUsernameCount };
  } catch (error) {
    console.error('❌ Error validating usernames:', error);
    return { error: error.message };
  }
};

const validatePosts = async () => {
  console.log('🔍 Validating posts migration...');
  
  try {
    // Get Realtime Database posts count
    const rtdbPostsSnapshot = await db.ref('posts').once('value');
    const rtdbPosts = rtdbPostsSnapshot.val();
    const rtdbPostCount = rtdbPosts ? Object.keys(rtdbPosts).length : 0;
    
    // Get Firestore posts count
    const fsPostsSnapshot = await firestore.collection('posts').get();
    const fsPostCount = fsPostsSnapshot.size;
    
    console.log(`📊 Realtime Database posts: ${rtdbPostCount}`);
    console.log(`📊 Firestore posts: ${fsPostCount}`);
    
    if (rtdbPostCount === fsPostCount) {
      console.log('✅ Posts count matches!');
    } else {
      console.log('❌ Posts count mismatch!');
    }
    
    return { rtdb: rtdbPostCount, firestore: fsPostCount, match: rtdbPostCount === fsPostCount };
  } catch (error) {
    console.error('❌ Error validating posts:', error);
    return { error: error.message };
  }
};

const validateSampleData = async () => {
  console.log('🔍 Validating sample data structure...');
  
  try {
    // Get a sample post from both databases
    const rtdbPostsSnapshot = await db.ref('posts').limitToFirst(1).once('value');
    const rtdbPosts = rtdbPostsSnapshot.val();
    
    if (!rtdbPosts) {
      console.log('ℹ️ No posts found in Realtime Database');
      return;
    }
    
    const rtdbPostId = Object.keys(rtdbPosts)[0];
    const rtdbPost = rtdbPosts[rtdbPostId];
    
    // Get the same post from Firestore
    const fsPostDoc = await firestore.collection('posts').doc(rtdbPostId).get();
    
    if (!fsPostDoc.exists) {
      console.log(`❌ Post ${rtdbPostId} not found in Firestore`);
      return;
    }
    
    const fsPost = fsPostDoc.data();
    
    console.log('📋 Sample post validation:');
    console.log(`   Post ID: ${rtdbPostId}`);
    console.log(`   RTDB has content: ${!!rtdbPost.content}`);
    console.log(`   Firestore has content: ${!!fsPost.content}`);
    console.log(`   RTDB has userId: ${!!rtdbPost.userId}`);
    console.log(`   Firestore has userId: ${!!fsPost.userId}`);
    console.log(`   RTDB has timestamp: ${!!rtdbPost.timestamp}`);
    console.log(`   Firestore has timestamp: ${!!fsPost.timestamp}`);
    
    // Check comments structure
    if (rtdbPost.comments && fsPost.comments) {
      const rtdbCommentCount = Object.keys(rtdbPost.comments).length;
      const fsCommentCount = Array.isArray(fsPost.comments) ? fsPost.comments.length : 0;
      console.log(`   RTDB comments: ${rtdbCommentCount}`);
      console.log(`   Firestore comments: ${fsCommentCount}`);
    }
    
    // Check likes structure
    if (rtdbPost.likes && fsPost.likes) {
      const rtdbLikeCount = Object.keys(rtdbPost.likes).length;
      const fsLikeCount = Array.isArray(fsPost.likes) ? fsPost.likes.length : 0;
      console.log(`   RTDB likes: ${rtdbLikeCount}`);
      console.log(`   Firestore likes: ${fsLikeCount}`);
    }
    
    console.log('✅ Sample data validation completed');
    
  } catch (error) {
    console.error('❌ Error validating sample data:', error);
  }
};

// Main validation function
const runValidation = async () => {
  console.log('🔍 Starting migration validation...');
  console.log('');
  
  const results = {
    users: await validateUsers(),
    usernames: await validateUsernames(),
    posts: await validatePosts()
  };
  
  console.log('');
  await validateSampleData();
  
  console.log('');
  console.log('📊 Validation Summary:');
  console.log(`   Users: ${results.users.match ? '✅' : '❌'} ${results.users.rtdb} → ${results.users.firestore}`);
  console.log(`   Usernames: ${results.usernames.match ? '✅' : '❌'} ${results.usernames.rtdb} → ${results.usernames.firestore}`);
  console.log(`   Posts: ${results.posts.match ? '✅' : '❌'} ${results.posts.rtdb} → ${results.posts.firestore}`);
  
  const allMatch = results.users.match && results.usernames.match && results.posts.match;
  
  if (allMatch) {
    console.log('');
    console.log('🎉 All validations passed! Migration appears successful.');
  } else {
    console.log('');
    console.log('⚠️ Some validations failed. Please review the migration.');
  }
  
  process.exit(allMatch ? 0 : 1);
};

// Run validation
runValidation(); 