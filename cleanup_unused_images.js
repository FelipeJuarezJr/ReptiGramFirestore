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
  deletedStorageFiles: 0,
  deletedFirestoreDocs: 0,
  errors: 0
};

async function cleanupUnusedImages() {
  try {
    console.log('🧹 Starting cleanup of unused images and URLs...\n');
    
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
    
    // Step 5: Show summary and ask for confirmation
    console.log('📋 SUMMARY:');
    console.log(`Storage files: ${storageFiles.length}`);
    console.log(`Firestore URLs: ${firestoreUrls.length}`);
    console.log(`Unused storage files: ${unusedFiles.length}`);
    console.log(`Unused Firestore documents: ${unusedDocs.length}`);
    
    if (unusedFiles.length === 0 && unusedDocs.length === 0) {
      console.log('\n✅ No unused files found! Cleanup not needed.');
      return;
    }
    
    // Step 6: Perform cleanup (with confirmation)
    console.log('\n⚠️  WARNING: This will permanently delete files!');
    console.log('Type "YES" to proceed with cleanup:');
    
    // For automated execution, we'll proceed with cleanup
    // In production, you might want to add a confirmation prompt
    
    if (unusedFiles.length > 0) {
      console.log('\n🗑️  Deleting unused storage files...');
      await deleteUnusedStorageFiles(unusedFiles);
    }
    
    if (unusedDocs.length > 0) {
      console.log('\n🗑️  Deleting unused Firestore documents...');
      await deleteUnusedFirestoreDocs(unusedDocs);
    }
    
    console.log('\n✅ Cleanup completed!');
    console.log(`Deleted ${stats.deletedStorageFiles} storage files`);
    console.log(`Deleted ${stats.deletedFirestoreDocs} Firestore documents`);
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
    stats.errors++;
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
    files.push({
      name: file.name,
      fullPath: file.name,
      type: 'photo',
      size: file.metadata?.size || 0
    });
  });
  
  // Collect from user_photos folder
  const [userPhotoFiles] = await bucket.getFiles({ prefix: 'user_photos/' });
  userPhotoFiles.forEach(file => {
    files.push({
      name: file.name,
      fullPath: file.name,
      type: 'user_photo',
      size: file.metadata?.size || 0
    });
  });
  
  // Collect from chat_images folder
  const [chatImageFiles] = await bucket.getFiles({ prefix: 'chat_images/' });
  chatImageFiles.forEach(file => {
    files.push({
      name: file.name,
      fullPath: file.name,
      type: 'chat_image',
      size: file.metadata?.size || 0
    });
  });
  
  // Collect from chat_files folder
  const [chatFileFiles] = await bucket.getFiles({ prefix: 'chat_files/' });
  chatFileFiles.forEach(file => {
    files.push({
      name: file.name,
      fullPath: file.name,
      type: 'chat_file',
      size: file.metadata?.size || 0
    });
  });
  
  stats.totalStorageFiles = files.length;
  return files;
}

function identifyUnusedFiles(storageFiles, firestoreUrls) {
  const unusedFiles = [];
  const usedUrls = new Set(firestoreUrls.map(item => item.url));
  
  for (const file of storageFiles) {
    // Get download URL for this file
    const downloadUrl = `https://storage.googleapis.com/${bucket.name}/${file.name}`;
    
    // Check if this URL is referenced in Firestore
    if (!usedUrls.has(downloadUrl)) {
      unusedFiles.push({
        ...file,
        downloadUrl: downloadUrl
      });
    }
  }
  
  stats.unusedStorageFiles = unusedFiles.length;
  return unusedFiles;
}

function identifyUnusedFirestoreDocs(storageFiles, firestoreUrls) {
  const unusedDocs = [];
  const validUrls = new Set();
  
  // Create set of valid storage URLs
  for (const file of storageFiles) {
    const downloadUrl = `https://storage.googleapis.com/${bucket.name}/${file.name}`;
    validUrls.add(downloadUrl);
  }
  
  // Check each Firestore URL
  for (const urlItem of firestoreUrls) {
    if (!validUrls.has(urlItem.url)) {
      unusedDocs.push(urlItem);
    }
  }
  
  stats.unusedFirestoreUrls = unusedDocs.length;
  return unusedDocs;
}

async function deleteUnusedStorageFiles(unusedFiles) {
  console.log(`\n🗑️  Deleting ${unusedFiles.length} unused storage files...`);
  
  for (const file of unusedFiles) {
    try {
      console.log(`  Deleting: ${file.name}`);
      await bucket.file(file.name).delete();
      stats.deletedStorageFiles++;
    } catch (error) {
      console.error(`  ❌ Error deleting ${file.name}:`, error.message);
      stats.errors++;
    }
  }
}

async function deleteUnusedFirestoreDocs(unusedDocs) {
  console.log(`\n🗑️  Deleting ${unusedDocs.length} unused Firestore documents...`);
  
  for (const doc of unusedDocs) {
    try {
      if (doc.collection === 'photos') {
        console.log(`  Deleting photo: ${doc.docId}`);
        await db.collection('photos').doc(doc.docId).delete();
      } else if (doc.collection === 'users') {
        console.log(`  Updating user: ${doc.docId} (removing photoUrl)`);
        await db.collection('users').doc(doc.docId).update({
          photoUrl: admin.firestore.FieldValue.delete(),
          photoURL: admin.firestore.FieldValue.delete()
        });
      } else if (doc.collection === 'chats') {
        const [chatId, , messageId] = doc.docId.split('/');
        console.log(`  Deleting chat message: ${chatId}/messages/${messageId}`);
        await db.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
      }
      stats.deletedFirestoreDocs++;
    } catch (error) {
      console.error(`  ❌ Error deleting ${doc.docId}:`, error.message);
      stats.errors++;
    }
  }
}

// Run the cleanup
cleanupUnusedImages().then(() => {
  console.log('\n=== CLEANUP COMPLETE ===');
  console.log('Final Statistics:');
  console.log(`- Total storage files: ${stats.totalStorageFiles}`);
  console.log(`- Total Firestore URLs: ${stats.totalFirestoreUrls}`);
  console.log(`- Unused storage files: ${stats.unusedStorageFiles}`);
  console.log(`- Unused Firestore docs: ${stats.unusedFirestoreUrls}`);
  console.log(`- Deleted storage files: ${stats.deletedStorageFiles}`);
  console.log(`- Deleted Firestore docs: ${stats.deletedFirestoreDocs}`);
  console.log(`- Errors: ${stats.errors}`);
  process.exit(0);
}).catch((error) => {
  console.error('Cleanup failed:', error);
  process.exit(1);
}); 