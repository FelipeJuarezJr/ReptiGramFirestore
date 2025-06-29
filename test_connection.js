const admin = require('firebase-admin');

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

// Test function
const testConnection = async () => {
  console.log('🔍 Testing Firebase connections...');
  
  try {
    // Test Realtime Database connection (reptigram-lite)
    console.log('📊 Testing Realtime Database connection (reptigram-lite)...');
    const rtdbTest = await db.ref('users').limitToFirst(1).once('value');
    const rtdbData = rtdbTest.val();
    console.log(`✅ Realtime Database connected! Found ${rtdbData ? Object.keys(rtdbData).length : 0} users`);
    
    // Test Firestore connection (reptigramfirestore)
    console.log('📊 Testing Firestore connection (reptigramfirestore)...');
    const fsTest = await firestore.collection('users').limit(1).get();
    console.log(`✅ Firestore connected! Found ${fsTest.size} users in Firestore`);
    
    // Test data access
    console.log('📊 Testing data access...');
    const usersSnapshot = await db.ref('users').once('value');
    const users = usersSnapshot.val();
    const userCount = users ? Object.keys(users).length : 0;
    
    const postsSnapshot = await db.ref('posts').once('value');
    const posts = postsSnapshot.val();
    const postCount = posts ? Object.keys(posts).length : 0;
    
    const usernamesSnapshot = await db.ref('usernames').once('value');
    const usernames = usernamesSnapshot.val();
    const usernameCount = usernames ? Object.keys(usernames).length : 0;
    
    console.log('📋 Data summary:');
    console.log(`   Users: ${userCount}`);
    console.log(`   Posts: ${postCount}`);
    console.log(`   Usernames: ${usernameCount}`);
    
    console.log('');
    console.log('🎉 All connections successful! Ready to run migration.');
    console.log('📝 Migration will:');
    console.log('   📖 Read from: reptigram-lite Realtime Database');
    console.log('   ✍️ Write to: reptigramfirestore Firestore');
    
  } catch (error) {
    console.error('❌ Connection test failed:', error);
    process.exit(1);
  }
};

// Run the test
testConnection(); 