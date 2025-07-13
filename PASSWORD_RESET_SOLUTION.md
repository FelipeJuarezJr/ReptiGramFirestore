# Password Reset Solution for ReptiGram

## 🚨 Current Issue
The password reset functionality is not sending reset links to users' email addresses.

## 🔍 Root Cause Analysis

### Primary Issue: Firebase Authentication Configuration
The password reset emails are not being sent because the Firebase Authentication templates and settings are not properly configured.

### Secondary Issue: Service Account Permissions (For Admin Operations)
The service account lacks proper permissions for admin operations, but this doesn't affect the Flutter app's password reset functionality.

## ✅ Immediate Solution

### Step 1: Configure Firebase Authentication Templates

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com/project/reptigramfirestore
   - Navigate to **Authentication** → **Templates**

2. **Configure Password Reset Template:**
   - Click on **Password reset** template
   - Set the following:
     ```
     Subject: Reset your ReptiGram password
     From name: ReptiGram Support
     From email: noreply@reptigramfirestore.firebaseapp.com
     ```

3. **Email Content Template:**
   ```
   Hello,
   
   You requested a password reset for your ReptiGram account.
   
   Click the link below to reset your password:
   [Reset Password Link]
   
   If you didn't request this reset, you can safely ignore this email.
   
   Best regards,
   ReptiGram Team
   ```

### Step 2: Configure Authorized Domains

1. **Go to Authentication Settings:**
   - Navigate to **Authentication** → **Settings** → **Authorized domains**

2. **Add Required Domains:**
   - `localhost` (for development)
   - `127.0.0.1` (alternative localhost)
   - `reptigramfirestore.firebaseapp.com` (for production)

### Step 3: Enable Password Reset

1. **Go to General Settings:**
   - Navigate to **Authentication** → **Settings** → **General**

2. **Enable Password Reset:**
   - ✅ Check "Allow users to reset their password"
   - ✅ Enable "Email link sign-in" (optional)

## 🧪 Testing the Fix

### Test 1: Manual App Testing
1. Open the ReptiGram app (running on localhost:8080)
2. Go to Login screen
3. Click "Forgot Password?"
4. Enter a valid email (e.g., `gecko1@gmail.com`)
5. Click "Send Reset Email"
6. Check the user's email inbox

### Test 2: Firebase Console Testing
1. Go to Firebase Console → Authentication → Users
2. Find a test user (e.g., `gecko1@gmail.com`)
3. Click on the user
4. Click "Send password reset email"
5. Verify the email is received

### Test 3: Code Verification
The Flutter app code is already correct:

```dart
// In forgot_password_screen.dart
await FirebaseAuth.instance.sendPasswordResetEmail(
  email: _emailController.text.trim(),
);
```

## 🔧 Additional Configuration (Optional)

### Fix Service Account Permissions (For Admin Operations)

If you need to use admin operations (like the test scripts), fix the service account permissions:

1. **Go to Google Cloud Console:**
   - Visit: https://console.cloud.google.com/iam-admin/iam?project=reptigramfirestore

2. **Find Your Service Account:**
   - Look for the service account used in `service-account-key.json`

3. **Add Required Roles:**
   - `Firebase Admin SDK Administrator Service Agent`
   - `Service Usage Consumer`
   - `Firebase Authentication Admin`

## 📋 Verification Checklist

- [ ] Password reset template configured in Firebase Console
- [ ] Authorized domains set up correctly
- [ ] Password reset enabled in authentication settings
- [ ] Email templates properly formatted
- [ ] Test emails being sent successfully
- [ ] Users can receive reset links
- [ ] Reset links work in the app

## 🚀 Expected Results

After implementing this solution:

1. **Users can request password resets** from the Flutter app
2. **Reset emails are sent** to user email addresses
3. **Reset links work** and allow users to set new passwords
4. **Proper error handling** for invalid emails or non-existent users

## 🆘 Troubleshooting

### Issue: "User not found" error
- **Solution**: Ensure the user exists in Firebase Authentication
- **Check**: Firebase Console → Authentication → Users

### Issue: "Invalid email" error
- **Solution**: Verify email format and domain
- **Check**: Ensure email is properly formatted

### Issue: Email not received
- **Solution**: Check spam folder and email templates
- **Check**: Verify email template configuration in Firebase Console

### Issue: Reset link doesn't work
- **Solution**: Check authorized domains configuration
- **Check**: Ensure `localhost` and `127.0.0.1` are in the authorized domains list
- **Note**: For localhost development, the reset link will redirect to localhost

## 📞 Support

If issues persist after following this guide:

1. Check Firebase Console logs for errors
2. Verify network connectivity
3. Test with different email providers
4. Contact Firebase support if needed

## 🎯 Priority Actions

1. **HIGH PRIORITY**: Configure Firebase Authentication templates (Step 1)
2. **HIGH PRIORITY**: Set up authorized domains (Step 2)
3. **HIGH PRIORITY**: Enable password reset (Step 3)
4. **MEDIUM PRIORITY**: Test the functionality
5. **LOW PRIORITY**: Fix service account permissions (for admin operations)

The Flutter app code is already correct and should work once the Firebase Console configuration is complete. 