import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RegistrationScreen extends StatefulWidget {
  // ... (existing code)
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // ... (existing code)

  Future<void> _handleRegistration() async {
    try {
      // ... existing registration code ...

      // After creating the user, save their username
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(user.uid)
            .set({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
        });
      }

      // ... rest of your code ...
    } catch (e) {
      // ... error handling ...
    }
  }

  // ... (rest of the existing code)
} 