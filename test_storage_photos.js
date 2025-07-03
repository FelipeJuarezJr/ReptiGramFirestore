const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'reptigramfirestore.appspot.com'
});

const bucket = admin.storage().bucket();

async function listPhotos() {
  try {
    console.log('Listing photos in Firebase Storage...');
    
    // List all files in the photos folder
    const [files] = await bucket.getFiles({ prefix: 'photos/' });
    
    console.log(`Found ${files.length} files in photos folder:`);
    
    // Group files by type (direct photos vs user folders)
    const directPhotos = [];
    const userFolders = new Set();
    
    for (const file of files) {
      const path = file.name;
      const pathParts = path.split('/');
      
      if (pathParts.length === 2) {
        // Direct photo in photos folder
        directPhotos.push(pathParts[1]);
      } else if (pathParts.length >= 3) {
        // Photo in user folder
        userFolders.add(pathParts[1]);
      }
    }
    
    console.log('\nDirect photos in photos/ folder:');
    directPhotos.forEach(photo => console.log(`  - ${photo}`));
    
    console.log('\nUser folders found:');
    userFolders.forEach(folder => console.log(`  - ${folder}`));
    
    // Check a few user folders for photos
    console.log('\nChecking user folders for photos:');
    for (const folder of Array.from(userFolders).slice(0, 5)) {
      try {
        const [folderFiles] = await bucket.getFiles({ prefix: `photos/${folder}/` });
        console.log(`  ${folder}: ${folderFiles.length} files`);
        if (folderFiles.length > 0) {
          folderFiles.slice(0, 3).forEach(file => {
            console.log(`    - ${file.name.split('/').pop()}`);
          });
        }
      } catch (e) {
        console.log(`  ${folder}: Error - ${e.message}`);
      }
    }
    
  } catch (error) {
    console.error('Error listing photos:', error);
  }
}

listPhotos().then(() => {
  console.log('Done!');
  process.exit(0);
}).catch(error => {
  console.error('Script failed:', error);
  process.exit(1);
}); 