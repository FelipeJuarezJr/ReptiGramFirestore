class UserModel {
  final String uid;
  final String email;
  final String username;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final Map<String, dynamic>? preferences;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.createdAt,
    this.lastLogin,
    this.preferences,
  });

  // Create from Firebase User and additional data
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      lastLogin: json['lastLogin'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(json['lastLogin'] as int)
        : null,
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLogin': lastLogin?.millisecondsSinceEpoch,
      'preferences': preferences,
    };
  }

  // Create copy with updates
  UserModel copyWith({
    String? username,
    DateTime? lastLogin,
    Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      username: username ?? this.username,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      preferences: preferences ?? this.preferences,
    );
  }
} 