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

const sourceStorage = admin.app('rtdb').storage(); // Source: reptigram-lite storage
const targetStorage = admin.app('firestore').storage(); // Target: reptigramfirestore storage

// Test function
const testStorage = async () => {
  console.log('🔍 Testing Firebase Storage connections...');
  
  try {
    // Test source storage bucket (reptigram-lite)
    console.log('📊 Testing source storage bucket (reptigram-lite)...');
    const sourceBucket = sourceStorage.bucket('reptigram-lite.firebasestorage.app');
    const [sourceFiles] = await sourceBucket.getFiles({ maxResults: 5 });
    console.log(`✅ Source storage connected! Found ${sourceFiles.length} sample files`);
    
    // Test target storage bucket (reptigramfirestore)
    console.log('📊 Testing target storage bucket (reptigramfirestore)...');
    const targetBucket = targetStorage.bucket('reptigramfirestore.firebasestorage.app');
    const [targetFiles] = await targetBucket.getFiles({ maxResults: 5 });
    console.log(`✅ Target storage connected! Found ${targetFiles.length} sample files`);
    
    // Get total file counts
    console.log('📊 Getting total file counts...');
    const [allSourceFiles] = await sourceBucket.getFiles();
    const [allTargetFiles] = await targetBucket.getFiles();
    
    console.log('📋 Storage summary:');
    console.log(`   📁 Source bucket (reptigram-lite): ${allSourceFiles.length} files`);
    console.log(`   📁 Target bucket (reptigramfirestore): ${allTargetFiles.length} files`);
    
    // Show some sample files from source
    if (allSourceFiles.length > 0) {
      console.log('📋 Sample files in source bucket:');
      allSourceFiles.slice(0, 5).forEach(file => {
        console.log(`   📄 ${file.name} (${(file.metadata.size / 1024).toFixed(1)} KB)`);
      });
      if (allSourceFiles.length > 5) {
        console.log(`   ... and ${allSourceFiles.length - 5} more files`);
      }
    }
    
    console.log('');
    console.log('🎉 All storage connections successful! Ready to run storage migration.');
    console.log('📝 Storage migration will:');
    console.log('   📖 Read from: reptigram-lite.firebasestorage.app');
    console.log('   ✍️ Write to: reptigramfirestore.firebasestorage.app');
    
  } catch (error) {
    console.error('❌ Storage test failed:', error);
    process.exit(1);
  }
};

// Run the test
testStorage(); 