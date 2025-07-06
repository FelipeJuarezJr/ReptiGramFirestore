const admin = require('firebase-admin');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
});

const db = admin.firestore();

async function checkUserPhotos() {
  try {
    console.log('Checking user photos in Firestore...\n');
    
    const usersSnapshot = await db.collection('users').get();
    const users = usersSnapshot.docs;
    
    console.log(`Found ${users.length} users:\n`);
    
    users.forEach(doc => {
      const userData = doc.data();
      const username = userData.username || userData.displayName || userData.name || 'No Name';
      const photoUrl = userData.photoUrl || userData.photoURL;
      const email = userData.email || 'No email';
      
      console.log(`👤 ${username} (${doc.id})`);
      console.log(`   📧 Email: ${email}`);
      console.log(`   🖼️  Photo: ${photoUrl || 'No photo URL'}`);
      
      if (photoUrl) {
        if (photoUrl.includes('googleusercontent.com')) {
          console.log(`   ⚠️  Google profile image (may have rate limits)`);
        } else if (photoUrl.includes('firebasestorage.googleapis.com')) {
          console.log(`   ✅ Firebase Storage image`);
        } else {
          console.log(`   🔗 External image URL`);
        }
      }
      console.log('');
    });
    
    console.log('✅ User photo check completed');
  } catch (error) {
    console.error('❌ Error checking user photos:', error);
  } finally {
    process.exit(0);
  }
}

checkUserPhotos(); 