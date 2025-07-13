# Password Reset Fix Guide

## Current Issue
The password reset functionality is not sending reset links to users' email addresses.

## Root Causes Identified

### 1. Firebase Authentication Templates Not Configured
The password reset email templates are likely not configured in Firebase Console.

### 2. Authorized Domains Missing
The domain for password reset might not be authorized.

### 3. Email Service Configuration
The email service might not be properly configured.

## Step-by-Step Fix

### Step 1: Configure Firebase Authentication Templates

1. Go to [Firebase Console](https://console.firebase.google.com/project/reptigramfirestore)
2. Navigate to **Authentication** → **Templates**
3. Click on **Password reset** template
4. Configure the following:

#### Email Template Configuration:
```
Subject: Reset your ReptiGram password
From name: ReptiGram Support
From email: noreply@reptigramfirestore.firebaseapp.com

Email content:
Hello,

You requested a password reset for your ReptiGram account.

Click the link below to reset your password:
[Reset Password Link]

If you didn't request this reset, you can safely ignore this email.

Best regards,
ReptiGram Team
```

### Step 2: Configure Authorized Domains

1. Go to **Authentication** → **Settings** → **Authorized domains**
2. Add the following domains:
   - `localhost` (for development)
   - `127.0.0.1` (alternative localhost)
   - `reptigramfirestore.firebaseapp.com` (for production)

### Step 3: Enable Password Reset in Authentication Settings

1. Go to **Authentication** → **Settings** → **General**
2. Make sure **Allow users to reset their password** is enabled
3. Verify that **Email link sign-in** is enabled if you want to use email links

### Step 4: Test the Configuration

Run the test script to verify the setup:

```bash
node test_password_reset.js
```

### Step 5: Update Flutter App Configuration

The current Flutter app implementation looks correct, but let's verify the configuration:

1. Check `lib/firebase_options.dart` - ensure the correct project ID
2. Verify the authentication domain in the Firebase config
3. Test the password reset flow in the app

## Testing Steps

### Test 1: Manual Testing
1. Open the app (running on localhost:8080)
2. Go to Login screen
3. Click "Forgot Password?"
4. Enter a valid email address
5. Click "Send Reset Email"
6. Check the user's email inbox

### Test 2: Console Testing
1. Go to Firebase Console → Authentication → Users
2. Find a test user
3. Click on the user
4. Click "Send password reset email"
5. Verify the email is received

### Test 3: API Testing
Use the test script to verify the API is working:

```bash
node test_password_reset.js
```

## Common Issues and Solutions

### Issue 1: "User not found" error
- **Solution**: Ensure the user exists in Firebase Authentication
- **Check**: Go to Firebase Console → Authentication → Users

### Issue 2: "Invalid email" error
- **Solution**: Verify email format and domain
- **Check**: Ensure email is properly formatted

### Issue 3: "Permission denied" error
- **Solution**: Check service account permissions
- **Check**: Ensure the service account has proper IAM roles

### Issue 4: Email not received
- **Solution**: Check spam folder and email templates
- **Check**: Verify email template configuration in Firebase Console

## Verification Checklist

- [ ] Password reset template is configured in Firebase Console
- [ ] Authorized domains are set up correctly
- [ ] Password reset is enabled in authentication settings
- [ ] Email templates are properly formatted
- [ ] Test emails are being sent successfully
- [ ] Users can receive and use reset links
- [ ] Reset links work correctly in the app

## Next Steps

1. Configure Firebase Authentication templates
2. Set up authorized domains
3. Test the password reset functionality
4. Monitor for any errors in Firebase Console logs
5. Update users about the password reset feature

## Support

If issues persist after following this guide:
1. Check Firebase Console logs for errors
2. Verify network connectivity
3. Test with different email providers
4. Contact Firebase support if needed 