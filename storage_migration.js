const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const os = require('os');

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

// Use the correct service accounts for each storage operation
const sourceStorage = admin.app('rtdb').storage(); // Source: reptigram-lite storage (using rtdb service account)
const targetStorage = admin.app('firestore').storage(); // Target: reptigramfirestore storage (using firestore service account)

// Migration configuration
const BATCH_SIZE = 5; // Number of files to process in parallel (reduced for download/upload)
const DELAY_BETWEEN_BATCHES = 2000; // 2 second delay between batches

// Helper function to delay execution
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Helper function to get all files from a storage bucket
const getAllFiles = async (bucket, prefix = '') => {
  const [files] = await bucket.getFiles({ prefix });
  return files;
};

// Helper function to copy a single file (download then upload)
const copyFile = async (sourceBucket, targetBucket, fileName) => {
  try {
    const sourceFile = sourceBucket.file(fileName);
    const targetFile = targetBucket.file(fileName);
    
    // Check if file already exists in target
    const [exists] = await targetFile.exists();
    if (exists) {
      console.log(`⏭️ Skipping ${fileName} (already exists)`);
      return { success: true, skipped: true };
    }
    
    // Create temporary file path
    const tempFilePath = path.join(os.tmpdir(), `migration_${Date.now()}_${path.basename(fileName)}`);
    
    // Download file from source
    await sourceFile.download({ destination: tempFilePath });
    
    // Upload file to target
    await targetBucket.upload(tempFilePath, {
      destination: fileName,
      metadata: {
        cacheControl: 'public, max-age=31536000',
      }
    });
    
    // Clean up temporary file
    fs.unlinkSync(tempFilePath);
    
    console.log(`✅ Copied ${fileName}`);
    return { success: true, skipped: false };
  } catch (error) {
    console.error(`❌ Error copying ${fileName}:`, error.message);
    // Clean up temp file if it exists
    try {
      if (fs.existsSync(tempFilePath)) {
        fs.unlinkSync(tempFilePath);
      }
    } catch (cleanupError) {
      // Ignore cleanup errors
    }
    return { success: false, error: error.message };
  }
};

// Main storage migration function
const migrateStorage = async () => {
  console.log('🚀 Starting Firebase Storage migration...');
  console.log('📋 This will migrate images from reptigram-lite to reptigramfirestore');
  console.log('🔑 Using reptigram-lite service account to READ from source');
  console.log('🔑 Using reptigramfirestore service account to WRITE to target');
  console.log('📥 Using download-then-upload approach for cross-project migration');
  console.log('');
  
  const startTime = Date.now();
  
  try {
    // Get source and target buckets using the correct service accounts
    const sourceBucket = sourceStorage.bucket('reptigram-lite.firebasestorage.app');
    const targetBucket = targetStorage.bucket('reptigramfirestore.firebasestorage.app');
    
    console.log('📊 Getting list of files from source bucket...');
    
    // Get all files from source bucket
    const files = await getAllFiles(sourceBucket);
    
    if (files.length === 0) {
      console.log('ℹ️ No files found in source bucket');
      return;
    }
    
    console.log(`📋 Found ${files.length} files to migrate`);
    console.log('');
    
    let successCount = 0;
    let skipCount = 0;
    let errorCount = 0;
    let processedCount = 0;
    
    // Process files in batches
    for (let i = 0; i < files.length; i += BATCH_SIZE) {
      const batch = files.slice(i, i + BATCH_SIZE);
      
      console.log(`🔄 Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(files.length / BATCH_SIZE)}...`);
      
      // Process batch in parallel
      const promises = batch.map(file => {
        const fileName = file.name;
        return copyFile(sourceBucket, targetBucket, fileName);
      });
      
      const results = await Promise.all(promises);
      
      // Count results
      results.forEach(result => {
        if (result.success) {
          if (result.skipped) {
            skipCount++;
          } else {
            successCount++;
          }
        } else {
          errorCount++;
        }
        processedCount++;
      });
      
      // Progress update
      console.log(`📊 Progress: ${processedCount}/${files.length} files processed`);
      console.log(`   ✅ Copied: ${successCount}, ⏭️ Skipped: ${skipCount}, ❌ Errors: ${errorCount}`);
      console.log('');
      
      // Delay between batches (except for the last batch)
      if (i + BATCH_SIZE < files.length) {
        await delay(DELAY_BETWEEN_BATCHES);
      }
    }
    
    const endTime = Date.now();
    const duration = (endTime - startTime) / 1000;
    
    console.log('🎉 Storage migration completed!');
    console.log(`⏱️ Total time: ${duration} seconds`);
    console.log('');
    console.log('📊 Final Results:');
    console.log(`   ✅ Successfully copied: ${successCount} files`);
    console.log(`   ⏭️ Skipped (already existed): ${skipCount} files`);
    console.log(`   ❌ Errors: ${errorCount} files`);
    console.log(`   📋 Total processed: ${processedCount} files`);
    console.log('');
    console.log('📝 Next steps:');
    console.log('1. Verify the images in reptigramfirestore Storage Console');
    console.log('2. Update your app to use the new storage bucket');
    console.log('3. Test image loading in your app');
    
  } catch (error) {
    console.error('💥 Storage migration failed:', error);
    process.exit(1);
  }
};

// Run the migration
migrateStorage(); 