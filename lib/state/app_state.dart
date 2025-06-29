import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/photo_data.dart';
import '../models/user_model.dart';

class AppState extends ChangeNotifier {
  User? _currentUser;
  final Map<String, String> _usernames = {};
  List<PhotoData> _photos = [];
  bool _isLoading = false;
  String? _error;
  UserModel? _userModel;

  // Getters
  User? get currentUser => _currentUser;
  Map<String, String> get usernames => _usernames;
  List<PhotoData> get photos => _photos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Set error state
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Set current user
  void setCurrentUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  // Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Username management
  Future<String?> fetchUsername(String? userId) async {
    // Return early if userId is null or empty
    if (userId == null || userId.isEmpty) {
      return 'Unknown User';
    }

    // Return cached username if available
    if (_usernames.containsKey(userId)) {
      return _usernames[userId];
    }

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(userId)
          .child('username')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        _usernames[userId] = snapshot.value.toString();
        notifyListeners();
        return _usernames[userId];
      }
      return 'Unknown User';
    } catch (e) {
      print('Error fetching username: $e');
      return 'Unknown User';
    }
  }

  String? getUsernameById(String userId) {
    return _usernames[userId];
  }

  // Photo management
  void setPhotos(List<PhotoData> photos) {
    _photos = photos;
    notifyListeners();
  }

  void addPhoto(PhotoData photo) {
    _photos.add(photo);
    notifyListeners();
  }

  void removePhoto(String photoId) {
    _photos.removeWhere((photo) => photo.id == photoId);
    notifyListeners();
  }

  void updatePhoto(PhotoData updatedPhoto) {
    final index = _photos.indexWhere((photo) => photo.id == updatedPhoto.id);
    if (index != -1) {
      _photos[index] = updatedPhoto;
      notifyListeners();
    }
  }

  void togglePhotoLike(String photoId) {
    final index = _photos.indexWhere((photo) => photo.id == photoId);
    if (index != -1) {
      _photos[index].isLiked = !_photos[index].isLiked;
      notifyListeners();
    }
  }

  // Clear state
  void clearState() {
    _currentUser = null;
    _usernames.clear();
    _photos.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      setLoading(true);
      setError(null);

      // First test if we can write to the database at all
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('temp_users')
            .child('test')
            .set({
              'timestamp': ServerValue.timestamp,
            });
        print('Test write successful');
      } catch (e) {
        print('Test write failed: $e');
      }

      // Create Firebase Auth user
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('User creation failed');

      print('Auth user created: ${user.uid}'); // Debug log

      // Try writing user data to a different path first
      final userData = {
        'uid': user.uid,
        'email': email,
        'username': username,
        'createdAt': ServerValue.timestamp,
        'lastLogin': ServerValue.timestamp,
        'preferences': {},
      };

      // Try writing to temp location
      await FirebaseDatabase.instance
          .ref()
          .child('temp_registrations')
          .child(user.uid)
          .set(userData);

      print('Temp registration saved'); // Debug log

      // Now try writing to actual users path
      await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .set(userData);

      print('User data saved'); // Debug log

      // Create user model
      final userModel = UserModel(
        uid: user.uid,
        email: email,
        username: username,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        preferences: {},
      );

      // Update state
      _currentUser = user;
      _userModel = userModel;
      _usernames[user.uid] = username;
      
      notifyListeners();
      print('State updated'); // Debug log

    } catch (e) {
      print('Registration error: $e'); // Debug log
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  // Initialize user from Firebase Auth
  Future<void> initializeUser() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    notifyListeners();
    
    // Listen for auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
    });
  }
} 