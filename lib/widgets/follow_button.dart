import 'package:flutter/material.dart';
import '../services/follow_service.dart';
import '../styles/colors.dart';

class FollowButton extends StatefulWidget {
  final String targetUserId;
  final bool isFollowing;
  final VoidCallback? onFollowChanged;
  final bool showText;
  final double? width;
  final double? height;

  const FollowButton({
    super.key,
    required this.targetUserId,
    required this.isFollowing,
    this.onFollowChanged,
    this.showText = true,
    this.width,
    this.height,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _isLoading = false;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  @override
  void didUpdateWidget(FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFollowing != widget.isFollowing) {
      _isFollowing = widget.isFollowing;
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isFollowing) {
        await FollowService.unfollowUser(widget.targetUserId);
        setState(() {
          _isFollowing = false;
        });
      } else {
        await FollowService.followUser(widget.targetUserId);
        setState(() {
          _isFollowing = true;
        });
      }
      
      widget.onFollowChanged?.call();
    } catch (e) {
      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = false; // TODO: Check if this is the current user
    
    if (isCurrentUser) {
      return const SizedBox.shrink(); // Don't show follow button for current user
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing 
              ? Colors.grey[300] 
              : AppColors.primary,
          foregroundColor: _isFollowing 
              ? Colors.black87 
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: _isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isFollowing ? Colors.black87 : Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isFollowing ? Icons.person_remove : Icons.person_add,
                    size: 16,
                  ),
                  if (widget.showText) ...[
                    const SizedBox(width: 4),
                    Text(
                      _isFollowing ? 'Unfollow' : 'Follow',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
