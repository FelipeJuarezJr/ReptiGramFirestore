# ReptiGram Data Migration Guide

This guide will help you migrate your ReptiGram data from Firebase Realtime Database to Firestore.

## 📋 Prerequisites

1. **Node.js** (version 14 or higher)
2. **Firebase Admin SDK** service account key
3. **Access to your Firebase project**

## 🔧 Setup Instructions

### 1. Install Dependencies

```bash
npm install
```

### 2. Get Firebase Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** (gear icon)
4. Click on **Service Accounts** tab
5. Click **Generate New Private Key**
6. Save the JSON file as `service-account-key.json` in this directory

### 3. Configure the Migration Script

Edit `migration_script.js` and update these values:

```javascript
// Replace with your actual service account key file path
const serviceAccount = require('./service-account-key.json');

// Replace with your actual Firebase project details
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://your-project-id.firebaseio.com', // Your Realtime Database URL
  projectId: 'your-project-id' // Your Firebase project ID
});
```

### 4. Verify Firestore is Enabled

1. In Firebase Console, go to **Firestore Database**
2. If not already created, click **Create Database**
3. Choose your preferred location and security rules

## 🚀 Running the Migration

### Before Running

1. **Backup your data**: Export your Realtime Database data as JSON
2. **Test in development**: Consider running this on a test project first
3. **Check Firestore rules**: Ensure your Firestore security rules allow writes

### Run the Migration

```bash
npm run migrate
```

Or directly:

```bash
node migration_script.js
```

## 📊 What Gets Migrated

The script will migrate the following data:

### Users Collection
- All user profiles with their data
- Photos, albums, binders, notebooks
- Profile information (displayName, email, photoURL, etc.)
- Timestamps and metadata

### Usernames Collection
- Username to user ID mappings
- Used for username uniqueness validation

### Posts Collection
- All posts with their content
- Comments (converted from object to array format)
- Likes (converted from object to array format)
- Timestamps and metadata

## 🔄 Data Structure Changes

### Posts - Comments Format
**Before (Realtime Database):**
```json
{
  "comments": {
    "-OOzzwsf5Qrenk77BcM6": {
      "content": "nice!",
      "timestamp": 1745904192240,
      "userId": "xqxeHCrMwQUuVLfVMxHKSSc1ULG3"
    }
  }
}
```

**After (Firestore):**
```json
{
  "comments": [
    {
      "commentId": "-OOzzwsf5Qrenk77BcM6",
      "content": "nice!",
      "timestamp": 1745904192240,
      "userId": "xqxeHCrMwQUuVLfVMxHKSSc1ULG3"
    }
  ]
}
```

### Posts - Likes Format
**Before (Realtime Database):**
```json
{
  "likes": {
    "xqxeHCrMwQUuVLfVMxHKSSc1ULG3": true,
    "v2FICGlNkwYMBD2LMBh5tru2yCs2": true
  }
}
```

**After (Firestore):**
```json
{
  "likes": ["xqxeHCrMwQUuVLfVMxHKSSc1ULG3", "v2FICGlNkwYMBD2LMBh5tru2yCs2"]
}
```

## ⚙️ Configuration Options

You can modify these settings in `migration_script.js`:

```javascript
const BATCH_SIZE = 500; // Firestore batch limit (max 500)
const DELAY_BETWEEN_BATCHES = 1000; // Delay in milliseconds between batches
```

## 📈 Migration Progress

The script will show real-time progress:

```
🚀 Starting Firebase Realtime Database to Firestore migration...
📋 This will migrate: users, usernames, and posts

🔄 Starting users migration...
✅ Batch committed successfully
✅ Users migration completed: 15 users migrated

🔄 Starting usernames migration...
✅ Batch committed successfully
✅ Usernames migration completed: 12 usernames migrated

🔄 Starting posts migration...
✅ Batch committed successfully
✅ Posts migration completed: 45 posts migrated

🎉 Migration completed successfully!
⏱️ Total time: 12.5 seconds
```

## 🔍 Verification

After migration, verify the data in Firebase Console:

1. Go to **Firestore Database**
2. Check that all collections are present:
   - `users`
   - `usernames`
   - `posts`
3. Verify document counts match your expectations
4. Check a few sample documents to ensure data integrity

## 🛠️ Troubleshooting

### Common Issues

**Error: "Permission denied"**
- Check your service account key has proper permissions
- Verify Firestore security rules allow writes

**Error: "Batch size exceeded"**
- Reduce `BATCH_SIZE` in the script (max 500)

**Error: "Quota exceeded"**
- Increase `DELAY_BETWEEN_BATCHES` to reduce request rate

**Error: "Invalid document path"**
- Check for invalid characters in document IDs
- The script handles most cases, but some edge cases may need manual intervention

### Recovery

If the migration fails partway through:

1. **Don't panic** - your original Realtime Database data is safe
2. **Check the error logs** to identify the issue
3. **Fix the issue** and re-run the script
4. **The script is idempotent** - it's safe to run multiple times (it will overwrite existing documents)

## 🔒 Security Considerations

1. **Keep your service account key secure** - never commit it to version control
2. **Use appropriate Firestore security rules** after migration
3. **Consider using environment variables** for sensitive configuration

## 📝 Post-Migration Steps

1. **Update your app code** to use Firestore instead of Realtime Database
2. **Test thoroughly** with the migrated data
3. **Update security rules** for Firestore
4. **Monitor performance** and adjust indexes if needed
5. **Consider backing up** your Realtime Database before switching completely

## 🆘 Support

If you encounter issues:

1. Check the Firebase documentation
2. Review the error logs carefully
3. Test with a smaller dataset first
4. Consider running the migration in stages

## 📄 License

This migration script is provided as-is for the ReptiGram project. Use at your own risk and always backup your data before running migrations. 