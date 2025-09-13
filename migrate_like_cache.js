const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://reptigramfirestore-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function migratePhotosToLikeCache() {
  console.log('🔄 Starting migration of photos to include like cache...');
  
  try {
    // Get all photos
    const photosSnapshot = await db.collection('photos').get();
    console.log(`📊 Found ${photosSnapshot.docs.length} photos to migrate`);
    
    let migratedCount = 0;
    let skippedCount = 0;
    
    for (const doc of photosSnapshot.docs) {
      const data = doc.data();
      
      // Skip if already has like cache fields
      if (data.recentLikers && data.likesMap) {
        skippedCount++;
        continue;
      }
      
      try {
        // Get current like count from likes collection
        const likesSnapshot = await db
          .collection('likes')
          .where('photoId', '==', doc.id)
          .get();
        
        const likesCount = likesSnapshot.docs.length;
        const likerIds = likesSnapshot.docs
          .map(likeDoc => likeDoc.data().userId)
          .filter(userId => userId); // Filter out null/undefined
        
        // Create likes map
        const likesMap = {};
        for (const likerId of likerIds) {
          likesMap[likerId] = true;
        }
        
        // Update photo document with cached like data
        await doc.ref.update({
          likesCount: likesCount,
          recentLikers: likerIds.slice(0, 5), // Keep only last 5 likers
          likesMap: likesMap,
        });
        
        migratedCount++;
        
        if (migratedCount % 10 === 0) {
          console.log(`📊 Migrated ${migratedCount} photos...`);
        }
        
      } catch (error) {
        console.error(`❌ Error migrating photo ${doc.id}:`, error);
      }
    }
    
    console.log('✅ Migration complete!');
    console.log(`📊 Migrated: ${migratedCount} photos`);
    console.log(`⏭️ Skipped: ${skippedCount} photos (already had cache)`);
    
  } catch (error) {
    console.error('❌ Error during migration:', error);
  } finally {
    process.exit(0);
  }
}

// Run migration
migratePhotosToLikeCache();
