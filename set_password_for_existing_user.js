const admin = require('firebase-admin');

// Initialize the current project (reptigramfirestore)
const app = admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json')),
  projectId: 'reptigramfirestore',
});

const auth = app.auth();

async function setPasswordForUser() {
  try {
    console.log('Setting password for existing user...');
    
    const email = 'gecko1@gmail.com';
    const newPassword = 'password123';
    
    // Get the user
    const user = await auth.getUserByEmail(email);
    console.log(`Found user: ${user.email} (${user.uid})`);
    
    // Update the user's password
    await auth.updateUser(user.uid, {
      password: newPassword,
    });
    
    console.log(`✓ Password updated for ${email}`);
    console.log(`📧 User can now login with:`);
    console.log(`   Email: ${email}`);
    console.log(`   Password: ${newPassword}`);
    
  } catch (error) {
    console.error('Error setting password:', error);
  }
}

setPasswordForUser(); 