import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'follow_button.dart';
import '../styles/colors.dart';

class UserProfileCard extends StatelessWidget {
  final UserModel user;
  final bool isFollowing;
  final VoidCallback? onFollowChanged;
  final VoidCallback? onTap;
  final bool showFollowButton;
  final bool compact;

  const UserProfileCard({
    super.key,
    required this.user,
    required this.isFollowing,
    this.onFollowChanged,
    this.onTap,
    this.showFollowButton = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: compact ? 20 : 30,
                backgroundImage: user.photoUrl != null 
                    ? NetworkImage(user.photoUrl!)
                    : null,
                child: user.photoUrl == null
                    ? Text(
                        user.username.isNotEmpty 
                            ? user.username[0].toUpperCase() 
                            : '?',
                        style: TextStyle(
                          fontSize: compact ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: TextStyle(
                        fontSize: compact ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Follow counts
                      Row(
                        children: [
                          _buildFollowCount(
                            context,
                            user.followersCount,
                            'followers',
                          ),
                          const SizedBox(width: 16),
                          _buildFollowCount(
                            context,
                            user.followingCount,
                            'following',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Follow button
              if (showFollowButton) ...[
                const SizedBox(width: 16),
                FollowButton(
                  targetUserId: user.uid,
                  isFollowing: isFollowing,
                  onFollowChanged: onFollowChanged,
                  showText: !compact,
                  width: compact ? 80 : null,
                  height: compact ? 32 : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowCount(BuildContext context, int count, String label) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to followers/following list
      },
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
