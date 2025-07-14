const admin = require('firebase-admin');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
  storageBucket: 'reptigramfirestore.firebasestorage.app'
});

const auth = app.auth();
const db = admin.firestore();
const bucket = admin.storage().bucket();

// Statistics tracking
const stats = {
  totalStorageFiles: 0,
  totalFirestoreUrls: 0,
  unusedStorageFiles: 0,
  unusedFirestoreUrls: 0,
  storageSize: 0,
  unusedStorageSize: 0
};

async function analyzeUnusedImages() {
  try {
    console.log('🔍 Analyzing unused images and URLs...\n');
    
    // Step 1: Collect all URLs from Firestore
    console.log('📊 Step 1: Collecting URLs from Firestore...');
    const firestoreUrls = await collectFirestoreUrls();
    console.log(`Found ${firestoreUrls.length} URLs in Firestore\n`);
    
    // Step 2: Collect all files from Storage
    console.log('📁 Step 2: Collecting files from Storage...');
    const storageFiles = await collectStorageFiles();
    console.log(`Found ${storageFiles.length} files in Storage\n`);
    
    // Step 3: Identify unused files
    console.log('🔍 Step 3: Identifying unused files...');
    const unusedFiles = identifyUnusedFiles(storageFiles, firestoreUrls);
    console.log(`Found ${unusedFiles.length} unused files\n`);
    
    // Step 4: Identify unused Firestore documents
    console.log('📝 Step 4: Identifying unused Firestore documents...');
    const unusedDocs = identifyUnusedFirestoreDocs(storageFiles, firestoreUrls);
    console.log(`Found ${unusedDocs.length} unused Firestore documents\n`);
    
    // Step 5: Generate detailed report
    console.log('📋 GENERATING DETAILED REPORT...\n');
    generateDetailedReport(storageFiles, firestoreUrls, unusedFiles, unusedDocs);
    
  } catch (error) {
    console.error('❌ Error during analysis:', error);
  }
}

async function collectFirestoreUrls() {
  const urls = [];
  
  // Collect from photos collection
  const photosSnapshot = await db.collection('photos').get();
  photosSnapshot.docs.forEach(doc => {
    const data = doc.data();
    if (data.url) {
      urls.push({
        url: data.url,
        collection: 'photos',
        docId: doc.id,
        data: data
      });
    }
  });
  
  // Collect from users collection
  const usersSnapshot = await db.collection('users').get();
  usersSnapshot.docs.forEach(doc => {
    const data = doc.data();
    if (data.photoUrl || data.photoURL) {
      urls.push({
        url: data.photoUrl || data.photoURL,
        collection: 'users',
        docId: doc.id,
        data: data
      });
    }
  });
  
  // Collect from chat messages
  const chatsSnapshot = await db.collection('chats').get();
  for (const chatDoc of chatsSnapshot.docs) {
    const messagesSnapshot = await chatDoc.ref.collection('messages').get();
    messagesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.fileUrl) {
        urls.push({
          url: data.fileUrl,
          collection: 'chats',
          docId: `${chatDoc.id}/messages/${doc.id}`,
          data: data
        });
      }
    });
  }
  
  stats.totalFirestoreUrls = urls.length;
  return urls;
}

async function collectStorageFiles() {
  const files = [];
  
  // Collect from photos folder
  const [photoFiles] = await bucket.getFiles({ prefix: 'photos/' });
  photoFiles.forEach(file => {
    const size = parseInt(file.metadata?.size || '0');
    files.push({
      name: file.name,
      fullPath: file.name,
      type: 'photo',
      size: size,
      metadata: file.metadata
    });
    stats.storageSize += size;
  });
  
  // Collect from user_photos folder
  const [userPhotoFiles] = await bucket.getFiles({ prefix: 'user_photos/' });
  userPhotoFiles.forEach(file => {
    const size = parseInt(file.metadata?.size || '0');
    files.push({
      name: file.name,
      fullPath: file.name,
      type: 'user_photo',
      size: size,
      metadata: file.metadata
    });
    stats.storageSize += size;
  });
  
  // Collect from chat_images folder
  const [chatImageFiles] = await bucket.getFiles({ prefix: 'chat_images/' });
  chatImageFiles.forEach(file => {
    const size = parseInt(file.metadata?.size || '0');
    files.push({
      name: file.name,
      fullPath: file.name,
      type: 'chat_image',
      size: size,
      metadata: file.metadata
    });
    stats.storageSize += size;
  });
  
  // Collect from chat_files folder
  const [chatFileFiles] = await bucket.getFiles({ prefix: 'chat_files/' });
  chatFileFiles.forEach(file => {
    const size = parseInt(file.metadata?.size || '0');
    files.push({
      name: file.name,
      fullPath: file.name,
      type: 'chat_file',
      size: size,
      metadata: file.metadata
    });
    stats.storageSize += size;
  });
  
  stats.totalStorageFiles = files.length;
  return files;
}

function identifyUnusedFiles(storageFiles, firestoreUrls) {
  const unusedFiles = [];
  const usedUrls = new Set();
  
  // Create a set of all URLs from Firestore
  firestoreUrls.forEach(item => {
    usedUrls.add(item.url);
  });
  
  for (const file of storageFiles) {
    // Get download URL for this file
    const downloadUrl = `https://storage.googleapis.com/${bucket.name}/${file.name}`;
    
    // Also check the Firebase Storage URL format
    const firebaseStorageUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(file.name)}?alt=media`;
    
    // Check if this URL is referenced in Firestore
    const isUsed = usedUrls.has(downloadUrl) || 
                   Array.from(usedUrls).some(url => url.includes(file.name) || url.includes(encodeURIComponent(file.name)));
    
    if (!isUsed) {
      unusedFiles.push({
        ...file,
        downloadUrl: downloadUrl
      });
      stats.unusedStorageSize += file.size;
    }
  }
  
  stats.unusedStorageFiles = unusedFiles.length;
  return unusedFiles;
}

function identifyUnusedFirestoreDocs(storageFiles, firestoreUrls) {
  const unusedDocs = [];
  const validFiles = new Set();
  
  // Create set of valid storage file names
  for (const file of storageFiles) {
    validFiles.add(file.name);
  }
  
  // Check each Firestore URL
  for (const urlItem of firestoreUrls) {
    const url = urlItem.url;
    
    // Extract file path from URL
    let filePath = '';
    if (url.includes('firebasestorage.googleapis.com')) {
      // Firebase Storage URL format
      const match = url.match(/\/o\/([^?]+)/);
      if (match) {
        filePath = decodeURIComponent(match[1]);
      }
    } else if (url.includes('storage.googleapis.com')) {
      // Direct storage URL format
      const match = url.match(/\/o\/([^?]+)/);
      if (match) {
        filePath = decodeURIComponent(match[1]);
      }
    }
    
    // Check if the file exists in storage
    const isValid = validFiles.has(filePath);
    
    if (!isValid) {
      unusedDocs.push(urlItem);
    }
  }
  
  stats.unusedFirestoreUrls = unusedDocs.length;
  return unusedDocs;
}

function generateDetailedReport(storageFiles, firestoreUrls, unusedFiles, unusedDocs) {
  console.log('='.repeat(80));
  console.log('📊 STORAGE ANALYSIS REPORT');
  console.log('='.repeat(80));
  
  // Summary statistics
  console.log('\n📈 SUMMARY STATISTICS:');
  console.log(`Total storage files: ${stats.totalStorageFiles}`);
  console.log(`Total storage size: ${formatBytes(stats.storageSize)}`);
  console.log(`Total Firestore URLs: ${stats.totalFirestoreUrls}`);
  console.log(`Unused storage files: ${stats.unusedStorageFiles}`);
  console.log(`Unused storage size: ${formatBytes(stats.unusedStorageSize)}`);
  console.log(`Unused Firestore documents: ${stats.unusedFirestoreUrls}`);
  
  // Storage breakdown by type
  console.log('\n📁 STORAGE BREAKDOWN BY TYPE:');
  const typeStats = {};
  storageFiles.forEach(file => {
    if (!typeStats[file.type]) {
      typeStats[file.type] = { count: 0, size: 0 };
    }
    typeStats[file.type].count++;
    typeStats[file.type].size += file.size;
  });
  
  Object.keys(typeStats).forEach(type => {
    const stats = typeStats[type];
    console.log(`${type}: ${stats.count} files (${formatBytes(stats.size)})`);
  });
  
  // Unused files breakdown
  if (unusedFiles.length > 0) {
    console.log('\n🗑️  UNUSED STORAGE FILES:');
    const unusedTypeStats = {};
    unusedFiles.forEach(file => {
      if (!unusedTypeStats[file.type]) {
        unusedTypeStats[file.type] = { count: 0, size: 0, files: [] };
      }
      unusedTypeStats[file.type].count++;
      unusedTypeStats[file.type].size += file.size;
      unusedTypeStats[file.type].files.push(file.name);
    });
    
    Object.keys(unusedTypeStats).forEach(type => {
      const stats = unusedTypeStats[type];
      console.log(`\n${type}: ${stats.count} files (${formatBytes(stats.size)})`);
      stats.files.slice(0, 5).forEach(file => {
        console.log(`  - ${file}`);
      });
      if (stats.files.length > 5) {
        console.log(`  ... and ${stats.files.length - 5} more files`);
      }
    });
  }
  
  // Unused Firestore documents
  if (unusedDocs.length > 0) {
    console.log('\n📝 UNUSED FIRESTORE DOCUMENTS:');
    const unusedCollectionStats = {};
    unusedDocs.forEach(doc => {
      if (!unusedCollectionStats[doc.collection]) {
        unusedCollectionStats[doc.collection] = [];
      }
      unusedCollectionStats[doc.collection].push(doc);
    });
    
    Object.keys(unusedCollectionStats).forEach(collection => {
      const docs = unusedCollectionStats[collection];
      console.log(`\n${collection}: ${docs.length} documents`);
      docs.slice(0, 5).forEach(doc => {
        console.log(`  - ${doc.docId}: ${doc.url}`);
      });
      if (docs.length > 5) {
        console.log(`  ... and ${docs.length - 5} more documents`);
      }
    });
  }
  
  // Recommendations
  console.log('\n💡 RECOMMENDATIONS:');
  if (unusedFiles.length === 0 && unusedDocs.length === 0) {
    console.log('✅ No cleanup needed - all files are properly referenced!');
  } else {
    console.log('⚠️  Cleanup recommended:');
    if (unusedFiles.length > 0) {
      console.log(`  - Delete ${unusedFiles.length} unused storage files (${formatBytes(stats.unusedStorageSize)})`);
    }
    if (unusedDocs.length > 0) {
      console.log(`  - Clean up ${unusedDocs.length} unused Firestore documents`);
    }
    console.log('\nTo perform cleanup, run: node cleanup_unused_images.js');
  }
  
  console.log('\n' + '='.repeat(80));
}

function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Run the analysis
analyzeUnusedImages().then(() => {
  console.log('\n✅ Analysis completed!');
  process.exit(0);
}).catch((error) => {
  console.error('Analysis failed:', error);
  process.exit(1);
}); 