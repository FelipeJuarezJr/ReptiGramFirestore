import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import '../models/user_model.dart';
import '../state/app_state.dart';
import '../services/follow_service.dart';
import '../widgets/user_profile_card.dart';

class UserDiscoveryScreen extends StatefulWidget {
  const UserDiscoveryScreen({super.key});

  @override
  State<UserDiscoveryScreen> createState() => _UserDiscoveryScreenState();
}

class _UserDiscoveryScreenState extends State<UserDiscoveryScreen> {
  List<UserModel> _suggestedUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSuggestedUsers();
  }

  Future<void> _loadSuggestedUsers() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final suggestions = await FollowService.getFollowSuggestions(limit: 20);
      
      if (mounted) {
        setState(() {
          _suggestedUsers = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading suggestions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshSuggestions() async {
    await _loadSuggestedUsers();
  }

  List<UserModel> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _suggestedUsers;
    }
    
    return _suggestedUsers.where((user) {
      return user.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             user.email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TitleHeader(title: 'Discover Users'),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No suggestions available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new user suggestions',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshSuggestions,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return RefreshIndicator(
      onRefresh: _refreshSuggestions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          return FutureBuilder<bool>(
            future: FollowService.isFollowing(user.uid),
            builder: (context, snapshot) {
              final isFollowing = snapshot.data ?? false;
              
              return UserProfileCard(
                user: user,
                isFollowing: isFollowing,
                onFollowChanged: () {
                  // Refresh the follow status
                  setState(() {});
                },
                onTap: () {
                  // TODO: Navigate to user profile
                },
                showFollowButton: true,
                compact: false,
              );
            },
          );
        },
      ),
    );
  }
}
