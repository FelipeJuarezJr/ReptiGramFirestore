const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

async function migrateWithFirebaseCLI() {
  try {
    console.log('Starting Firebase CLI migration...');
    
    // Step 1: Export users from old project
    console.log('\n1. Exporting users from reptigram-lite...');
    const exportCommand = 'firebase auth:export users_old.json --project reptigram-lite';
    
    exec(exportCommand, (error, stdout, stderr) => {
      if (error) {
        console.log('Error exporting users:', error.message);
        console.log('You may need to:');
        console.log('1. Run: firebase login');
        console.log('2. Run: firebase use reptigram-lite');
        console.log('3. Then run this script again');
        return;
      }
      
      console.log('Users exported successfully');
      
      // Step 2: Import users to new project
      console.log('\n2. Importing users to reptigramfirestore...');
      const importCommand = 'firebase auth:import users_old.json --project reptigramfirestore';
      
      exec(importCommand, (error, stdout, stderr) => {
        if (error) {
          console.log('Error importing users:', error.message);
          return;
        }
        
        console.log('Users imported successfully');
        console.log('\nMigration completed!');
        console.log('Users can now login with their original passwords or use "Forgot Password"');
      });
    });
    
  } catch (error) {
    console.error('Migration failed:', error);
  }
}

migrateWithFirebaseCLI(); 