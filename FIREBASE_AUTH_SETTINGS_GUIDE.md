# Firebase Authentication Settings Guide

## 🔍 Finding Password Reset Settings

The Firebase Console interface can vary, so here are the different places to check:

### Method 1: Authentication → Settings → General
1. Go to: https://console.firebase.google.com/project/reptigramfirestore
2. Navigate to **Authentication** → **Settings** → **General**
3. Look for:
   - "Allow users to reset their password"
   - "Password reset" option
   - "Email/Password" settings

### Method 2: Authentication → Sign-in method
1. Go to **Authentication** → **Sign-in method**
2. Look for **Email/Password** provider
3. Click on **Email/Password**
4. Check if there are password reset options there

### Method 3: Authentication → Templates
1. Go to **Authentication** → **Templates**
2. Look for **Password reset** template
3. If it exists, password reset is likely enabled

## 🎯 Most Important: Authorized Domains

The **most critical setting** for localhost is the authorized domains:

1. Go to **Authentication** → **Settings** → **Authorized domains**
2. Add these domains:
   - `localhost`
   - `127.0.0.1`
   - `reptigramfirestore.firebaseapp.com`

## 🔧 Alternative: Test Directly

Since your Flutter app is running, let's test if password reset works:

1. Go to http://localhost:8080
2. Click "Forgot Password?"
3. Enter `gecko1@gmail.com`
4. Click "Send Reset Email"
5. Check if you get an error message

## 📋 What to Look For

### If Password Reset is Working:
- You'll see a success message: "Reset email sent!"
- Check the email inbox for the reset link

### If Password Reset is NOT Working:
- You might see an error like "Domain not authorized"
- Or "User not found" if the email doesn't exist

## 🚨 Common Issues

### Issue: "Domain not authorized"
- **Solution**: Add `localhost` and `127.0.0.1` to authorized domains
- **Location**: Authentication → Settings → Authorized domains

### Issue: "User not found"
- **Solution**: Make sure the user exists in Firebase Authentication
- **Location**: Authentication → Users

### Issue: No email received
- **Solution**: Check spam folder and email template configuration
- **Location**: Authentication → Templates

## 🧪 Quick Test

Let's test the current setup:

1. **Open your app**: http://localhost:8080
2. **Try password reset**: Use "Forgot Password?" with `gecko1@gmail.com`
3. **Check the result**: 
   - Success = Password reset is working
   - Error = We need to configure the settings

## 📞 Next Steps

1. **First**: Test the password reset in your app
2. **If it fails**: Add localhost to authorized domains
3. **If still fails**: Check the error message for specific issues

The "Allow users to reset their password" setting might be enabled by default in newer Firebase projects, so the authorized domains are often the main issue. 