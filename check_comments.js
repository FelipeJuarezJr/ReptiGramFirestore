const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://reptigramfirestore-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function checkComments() {
  try {
    console.log('Checking comments collection...');
    
    const commentsSnapshot = await db.collection('comments').get();
    console.log(`Total comments found: ${commentsSnapshot.size}`);
    
    if (commentsSnapshot.size > 0) {
      console.log('\nComments:');
      commentsSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`- ID: ${doc.id}`);
        console.log(`  Photo ID: ${data.photoId}`);
        console.log(`  User ID: ${data.userId}`);
        console.log(`  Content: ${data.content}`);
        console.log(`  Timestamp: ${data.timestamp}`);
        console.log('');
      });
    } else {
      console.log('No comments found in the database.');
    }
    
    // Also check photos to see what photo IDs exist
    console.log('\nChecking photos collection...');
    const photosSnapshot = await db.collection('photos').limit(5).get();
    console.log(`Found ${photosSnapshot.size} photos (showing first 5):`);
    
    photosSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`- Photo ID: ${doc.id}`);
      console.log(`  User ID: ${data.userId}`);
      console.log(`  URL: ${data.url || data.firebaseUrl}`);
      console.log('');
    });
    
  } catch (error) {
    console.error('Error checking comments:', error);
  }
  
  process.exit(0);
}

checkComments(); 