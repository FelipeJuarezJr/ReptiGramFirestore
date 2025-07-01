# User Migration Checklist

## Google Sign-In Users ✅ WORKING
These users can sign in with Google (if they have Google accounts):
- ✅ gecko1@gmail.com (tested and working)
- felipe.juarez.jr@outlook.com
- reptigram@gmail.com
- mr.felipe.juarez.jr@gmail.com
- geckoace@gmail.com
- gecko3@gmail.com
- joe@wildcardgeckos.com
- junior@gmail.com
- testy@gmail.com
- flippy@gmail.com
- flipper@gmail.com
- flip@gmail.com

## Manual User Creation (Email/Password)
For users who don't have Google accounts, add them manually in Firebase Console:

### Steps:
1. Go to Firebase Console → reptigramfirestore project
2. Authentication → Users
3. Click "Add user" for each user below

### Users to Add:
- [ ] felipe.juarez.jr@outlook.com
- [ ] reptigram@gmail.com
- [ ] joe@wildcardgeckos.com
- [ ] testy@gmail.com
- [ ] flippy@gmail.com
- [ ] flipper@gmail.com
- [ ] flip@gmail.com

### For Each User:
- Email: [user email]
- Password: password123
- ✅ Check "Email verified"

## Login Credentials
After setup, users can login with:

### Google Sign-In Users: ✅ WORKING
- Click "Sign in with Google" button
- Use their Google account

### Email/Password Users:
- Email: [their email]
- Password: password123

## Next Steps
1. ✅ Enable Google Sign-In in Firebase Console
2. ✅ Test Google Sign-In with existing users
3. ⏳ Add email/password users manually
4. ⏳ Test both login methods
5. ⏳ Enable password reset in Firebase Console
6. ⏳ Inform users about login options

## Current Status
- **Google Sign-In**: ✅ Working
- **User Document Creation**: ✅ Working
- **Email/Password Users**: ⏳ Need to add manually 