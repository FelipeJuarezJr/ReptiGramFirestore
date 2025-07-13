# Localhost Password Reset Setup for ReptiGram

## 🎯 Quick Setup for Localhost Development

Since you're using localhost for development, here's the specific configuration needed:

### Step 1: Firebase Console Configuration

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com/project/reptigramfirestore
   - Navigate to **Authentication** → **Settings** → **Authorized domains**

2. **Add Localhost Domains:**
   - Click **Add domain**
   - Add: `localhost`
   - Click **Add domain**
   - Add: `127.0.0.1`
   - Click **Add domain**
   - Add: `reptigramfirestore.firebaseapp.com` (for production)

### Step 2: Configure Email Template

1. **Go to Authentication Templates:**
   - Navigate to **Authentication** → **Templates**
   - Click on **Password reset** template

2. **Set Template Configuration:**
   ```
   Subject: Reset your ReptiGram password
   From name: ReptiGram Support
   From email: noreply@reptigramfirestore.firebaseapp.com
   ```

3. **Email Content:**
   ```
   Hello,
   
   You requested a password reset for your ReptiGram account.
   
   Click the link below to reset your password:
   [Reset Password Link]
   
   If you didn't request this reset, you can safely ignore this email.
   
   Best regards,
   ReptiGram Team
   ```

### Step 3: Enable Password Reset

1. **Go to General Settings:**
   - Navigate to **Authentication** → **Settings** → **General**
   - ✅ Check "Allow users to reset their password"

## 🧪 Testing on Localhost

### Test the Password Reset Flow:

1. **Start your Flutter app:**
   ```bash
   flutter run -d chrome --web-port 8080
   ```

2. **Test the reset flow:**
   - Open: http://localhost:8080
   - Go to Login screen
   - Click "Forgot Password?"
   - Enter: `gecko1@gmail.com`
   - Click "Send Reset Email"
   - Check the email inbox

### Expected Behavior:

- ✅ Reset email should be sent to the user's email
- ✅ Reset link should redirect to localhost
- ✅ User should be able to set a new password
- ✅ User should be able to login with the new password

## 🔧 Troubleshooting for Localhost

### Issue: "Domain not authorized" error
- **Solution**: Make sure `localhost` and `127.0.0.1` are in authorized domains
- **Check**: Firebase Console → Authentication → Settings → Authorized domains

### Issue: Reset link redirects to wrong domain
- **Solution**: The reset link will redirect to localhost for development
- **Note**: This is expected behavior for localhost development

### Issue: Email not received
- **Solution**: Check spam folder and verify email template configuration
- **Check**: Firebase Console → Authentication → Templates

## 📋 Verification Checklist for Localhost

- [ ] `localhost` added to authorized domains
- [ ] `127.0.0.1` added to authorized domains
- [ ] Password reset template configured
- [ ] "Allow users to reset their password" enabled
- [ ] App running on localhost:8080
- [ ] Test email sent successfully
- [ ] Reset link works on localhost

## 🚀 Next Steps

1. **Configure Firebase Console** (Steps 1-3 above)
2. **Test the password reset flow** in your localhost app
3. **Verify emails are received** and reset links work
4. **Deploy to production** when ready (will use `reptigramfirestore.firebaseapp.com`)

The Flutter app code is already correct and will work once the Firebase Console configuration is complete! 