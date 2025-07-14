const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./firebase-adminsdk.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'reptigram-12345.appspot.com'
});

const db = admin.firestore();

async function testNotebookPhotos() {
  try {
    console.log('🔍 Testing notebook photos...');
    
    // Get all notebooks
    const notebooksSnapshot = await db.collection('notebooks').get();
    console.log(`📚 Found ${notebooksSnapshot.size} notebooks`);
    
    for (const doc of notebooksSnapshot.docs) {
      const data = doc.data();
      console.log(`  📚 Notebook: ${data.name} (ID: ${doc.id})`);
      console.log(`    User: ${data.userId}`);
      console.log(`    Binder: ${data.binderName}`);
      console.log(`    Album: ${data.albumName}`);
      console.log(`    Created: ${data.createdAt?.toDate()}`);
    }
    
    // Get all photos
    const photosSnapshot = await db.collection('photos').get();
    console.log(`📸 Found ${photosSnapshot.size} photos`);
    
    const photosByNotebook = {};
    
    for (const doc of photosSnapshot.docs) {
      const data = doc.data();
      const notebookName = data.notebookName || 'My Notebook';
      
      if (!photosByNotebook[notebookName]) {
        photosByNotebook[notebookName] = [];
      }
      
      photosByNotebook[notebookName].push({
        id: doc.id,
        url: data.url,
        albumName: data.albumName,
        binderName: data.binderName,
        userId: data.userId,
        timestamp: data.timestamp?.toDate()
      });
    }
    
    console.log('📸 Photos by notebook:');
    for (const [notebookName, photos] of Object.entries(photosByNotebook)) {
      console.log(`  📚 ${notebookName}: ${photos.length} photos`);
      for (const photo of photos) {
        console.log(`    📸 ${photo.id} - ${photo.url}`);
        console.log(`      Album: ${photo.albumName}, Binder: ${photo.binderName}, User: ${photo.userId}`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

testNotebookPhotos(); 