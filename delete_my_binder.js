// delete_my_binder.js
// Deletes all 'My Binder' documents from the 'binders' collection for all users

const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json'); // Updated path

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function deleteMyBinderForAllUsers() {
  const snapshot = await db.collection('binders').where('name', '==', 'My Binder').get();
  if (snapshot.empty) {
    console.log('No "My Binder" documents found.');
    return;
  }
  let count = 0;
  const batch = db.batch();
  snapshot.forEach(doc => {
    batch.delete(doc.ref);
    count++;
  });
  await batch.commit();
  console.log(`Deleted ${count} 'My Binder' documents from binders collection.`);
}

deleteMyBinderForAllUsers().catch(console.error); 