# 🧹 Image Cleanup Guide - ReptiGram

This guide explains how to identify and clean up unused images and URLs in your ReptiGram Firebase project to avoid corrupted files and unnecessary storage usage.

## 📋 Overview

The cleanup process identifies:
- **Unused Storage Files**: Images in Firebase Storage that aren't referenced in Firestore
- **Unused Firestore Documents**: Firestore documents with URLs pointing to non-existent storage files
- **Orphaned URLs**: Broken references between Firestore and Storage

## 🛠️ Scripts Available

### 1. `analyze_unused_images.js` - Analysis Only
**Purpose**: Safely analyze your project without making any changes
**Use Case**: Review what would be cleaned up before proceeding

```bash
node analyze_unused_images.js
```

**Output**: Detailed report showing:
- Total storage files and size
- Total Firestore URLs
- Unused files breakdown by type
- Storage space that can be freed
- Recommendations for cleanup

### 2. `cleanup_unused_images.js` - Full Cleanup
**Purpose**: Actually delete unused files and documents
**Use Case**: After reviewing the analysis, perform the cleanup

```bash
node cleanup_unused_images.js
```

**⚠️ WARNING**: This script permanently deletes files!

## 📁 Storage Structure Analyzed

The scripts analyze these Firebase Storage paths:

```
photos/{userId}/{photoId}          # Main photo uploads
user_photos/{userId}.jpg           # Profile photos
chat_images/{chatId}/{messageId}.jpg  # Chat images
chat_files/{chatId}/{messageId}_{fileName}  # Chat files
```

## 📊 Firestore Collections Analyzed

The scripts check these Firestore collections:

```
photos/{photoId}                   # Photo documents with 'url' field
users/{userId}                     # User documents with 'photoUrl' field
chats/{chatId}/messages/{messageId} # Chat messages with 'fileUrl' field
```

## 🔍 How It Works

### Step 1: Collect Firestore URLs
- Scans all relevant Firestore collections
- Extracts all image/file URLs
- Maps URLs to their document locations

### Step 2: Collect Storage Files
- Lists all files in Firebase Storage
- Calculates file sizes and metadata
- Groups files by type (photos, user_photos, chat_images, chat_files)

### Step 3: Cross-Reference Analysis
- Compares Storage files with Firestore URLs
- Identifies files without Firestore references
- Identifies Firestore documents with broken URLs

### Step 4: Generate Report/Cleanup
- **Analysis**: Shows detailed breakdown without changes
- **Cleanup**: Deletes identified unused files and documents

## 📈 Sample Output

```
📊 STORAGE ANALYSIS REPORT
================================================================================

📈 SUMMARY STATISTICS:
Total storage files: 150
Total storage size: 45.2 MB
Total Firestore URLs: 142
Unused storage files: 8
Unused storage size: 2.1 MB
Unused Firestore documents: 3

📁 STORAGE BREAKDOWN BY TYPE:
photo: 120 files (35.8 MB)
user_photo: 15 files (5.2 MB)
chat_image: 10 files (3.1 MB)
chat_file: 5 files (1.1 MB)

🗑️  UNUSED STORAGE FILES:
photo: 5 files (1.2 MB)
  - photos/user123/1234567890
  - photos/user456/1234567891
  ... and 3 more files

user_photo: 3 files (0.9 MB)
  - user_photos/user789.jpg
  - user_photos/user101.jpg
  - user_photos/user102.jpg

💡 RECOMMENDATIONS:
⚠️  Cleanup recommended:
  - Delete 8 unused storage files (2.1 MB)
  - Clean up 3 unused Firestore documents

To perform cleanup, run: node cleanup_unused_images.js
```

## 🚨 Safety Features

### Analysis First
- Always run `analyze_unused_images.js` first
- Review the report carefully
- Understand what will be deleted

### Backup Recommendation
Before running cleanup:
```bash
# Export your Firestore data
firebase firestore:export ./backup

# List all storage files (for reference)
gsutil ls gs://reptigramfirestore.appspot.com/
```

### Error Handling
- Scripts continue even if individual files fail to delete
- Detailed error logging for each failed operation
- Statistics tracking for successful vs failed operations

## 🔧 Troubleshooting

### Common Issues

**1. Permission Errors**
```
❌ Error deleting photos/user123/1234567890: Permission denied
```
**Solution**: Ensure your service account has Storage Admin permissions

**2. Network Timeouts**
```
❌ Error: Request timeout
```
**Solution**: Retry the script - Firebase operations can be slow with many files

**3. Invalid URLs**
```
❌ Error: Invalid URL format
```
**Solution**: Check if your Firestore documents have properly formatted URLs

### Debug Mode

To see more detailed output, modify the scripts to add:
```javascript
console.log('Debug: Processing file:', file.name);
console.log('Debug: URL comparison:', { storageUrl, firestoreUrl });
```

## 📝 Best Practices

### Before Cleanup
1. **Run analysis first**: `node analyze_unused_images.js`
2. **Review the report**: Understand what will be deleted
3. **Backup important data**: Export Firestore collections
4. **Test on staging**: If possible, test on a copy of your data

### After Cleanup
1. **Verify results**: Run analysis again to confirm cleanup
2. **Monitor app**: Ensure no broken images appear
3. **Check storage costs**: Monitor Firebase Storage usage
4. **Document changes**: Note what was cleaned up

### Regular Maintenance
- Run analysis monthly to catch orphaned files early
- Monitor storage usage trends
- Review cleanup reports for patterns

## 🎯 Expected Results

After successful cleanup:
- ✅ Reduced Firebase Storage costs
- ✅ Faster app performance (fewer files to process)
- ✅ Cleaner database structure
- ✅ No broken image links in your app

## 📞 Support

If you encounter issues:
1. Check the error messages in the script output
2. Verify your Firebase project configuration
3. Ensure your service account has proper permissions
4. Review the troubleshooting section above

---

**Remember**: Always analyze before cleaning up, and keep backups of important data! 