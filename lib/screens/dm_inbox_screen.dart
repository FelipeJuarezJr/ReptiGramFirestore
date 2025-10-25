import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_screen.dart';
import 'user_search_screen.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../state/app_state.dart';
import '../state/dark_mode_provider.dart';
import '../styles/colors.dart';
import '../utils/responsive_utils.dart';
import 'dart:async';
import 'home_dashboard_screen.dart';
import 'post_screen.dart';
import 'albums_screen.dart';
import 'feed_screen.dart';

class DMInboxScreen extends StatefulWidget {
  const DMInboxScreen({Key? key}) : super(key: key);

  @override
  State<DMInboxScreen> createState() => _DMInboxScreenState();
}

class _DMInboxScreenState extends State<DMInboxScreen> {
  final ChatService _chatService = ChatService();
  bool _isLoading = true;
  final Map<String, String?> _avatarCache = {}; // Cache for avatar URLs
  bool _isLoadingMore = false;
  bool _hasMoreConversations = true;
  List<ConversationData> _conversations = [];
  DocumentSnapshot? _lastConversationDocument;
  final ScrollController _scrollController = ScrollController();
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    print('🟢 DM Inbox Screen initialized');
    _loadConversations();
    // Add scroll listener for infinite scroll
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store reference to AppState for safe access in dispose()
    _appState = Provider.of<AppState>(context, listen: false);
    _appState?.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Remove listener to prevent memory leaks
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    // Clear avatar cache when AppState changes (profile pictures updated)
    if (mounted) {
      setState(() {
        _avatarCache.clear();
      });
    }
  }

  Future<String?> _getAvatarUrl(String userId) async {
    // Check local cache first
    if (_avatarCache.containsKey(userId)) {
      return _avatarCache[userId];
    }
    
    try {
      // First check AppState for cached profile picture
      final appState = Provider.of<AppState>(context, listen: false);
      final cachedUrl = appState.getProfilePicture(userId);
      
      if (cachedUrl != null) {
        setState(() {
          _avatarCache[userId] = cachedUrl;
        });
        return cachedUrl;
      }
      
      // If not in AppState cache, get from Firestore
      final url = await FirestoreService.getUserPhotoUrl(userId);
      
      // Cache in AppState for future use
      appState.updateProfilePicture(userId, url);
      
      // Cache the result locally
      setState(() {
        _avatarCache[userId] = url;
      });
      
      return url;
    } catch (e) {
      print('Error fetching avatar for user $userId: $e');
      return null;
    }
  }

  void _onScroll() {
    // Check if we've scrolled near the bottom (for loading more conversations)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreConversations();
    }
  }

  Future<void> _loadConversations({bool resetPagination = true}) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    
    print('🟢 ========== LOAD CONVERSATIONS DEBUG ==========');
    print('🟢 Current user UID: ${currentUser.uid}');
    print('🟢 Reset pagination: $resetPagination');
    
    try {
      setState(() {
        _isLoading = true;
      });

      if (resetPagination) {
        _conversations.clear();
        _lastConversationDocument = null;
        _hasMoreConversations = true;
        print('🟢 Reset pagination - cleared conversations list');
      }

      print('🟢 Loading conversations from Firestore...');
      // Use paginated conversation loading
      final conversationData = await _chatService.getConversationsPaginated(
        currentUserId: currentUser.uid,
        limit: 20,
        lastDocument: _lastConversationDocument,
      );

      print('🟢 Received ${conversationData.length} conversations from Firestore');
      final List<ConversationData> conversations = [];

      for (final convData in conversationData) {
        final otherParticipantId = convData['otherParticipantId'] as String;
        print('🟢 Processing conversation with participant: $otherParticipantId');
        
        // Get the other participant's user data
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherParticipantId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final name = userData['displayName'] ?? 
                      userData['username'] ?? 
                      userData['name'] ?? 
                      'No Name';
          
          print('🟢   - User name: $name');
          
          // Get photo URL using AppState integration
          final avatarUrl = await _getAvatarUrl(otherParticipantId);

          conversations.add(ConversationData(
            conversationId: convData['conversationId'] as String,
            otherParticipantId: otherParticipantId,
            otherParticipantName: name,
            otherParticipantAvatar: avatarUrl,
            lastMessage: convData['lastMessage'] as String,
            lastTimestamp: convData['lastTimestamp'] as int,
            unreadCount: convData['unreadCount'] as int,
          ));
          print('🟢   - Added conversation to list');
        } else {
          print('🟡   - User document not found for: $otherParticipantId');
        }
      }

      // Sort conversations by lastTimestamp in descending order (most recent first)
      conversations.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
      print('🟢 Sorted ${conversations.length} conversations by timestamp');

      if (mounted) {
        setState(() {
          _conversations.addAll(conversations);
          _hasMoreConversations = conversationData.length == 20;
          _isLoading = false;
        });
        print('🟢 Updated state with ${_conversations.length} total conversations');
      }
      print('🟢 ========== END LOAD CONVERSATIONS DEBUG ==========');
    } catch (e) {
      print('❌ Error loading conversations: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreConversations() async {
    if (_isLoadingMore || !_hasMoreConversations) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _loadConversations(resetPagination: false);

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _openChat(String conversationId, String peerName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          peerName: peerName,
        ),
      ),
    );
    // Refresh the list when returning from chat
    if (mounted) {
      await _loadConversations();
    }
  }

  void _openSearchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UserSearchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = ResponsiveUtils.isWideScreen(context);
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);
    
    print('💬 DMInboxScreen: build() called - isDarkMode: ${darkModeProvider.isDarkMode}');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: darkModeProvider.isDarkMode ? AppColors.darkCardBackground : AppColors.titleText,
        foregroundColor: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadConversations(resetPagination: true);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: darkModeProvider.isDarkMode 
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF424242), // Colors.grey[800]!
                    Color(0xFF212121), // Colors.grey[900]!
                    Color(0xFF000000), // Colors.black
                  ],
                ),
              )
            : null,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _conversations.isEmpty
                ? _buildEmptyState()
                : _buildConversationsList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSearchScreen,
        backgroundColor: darkModeProvider.isDarkMode ? AppColors.darkCardBackground : AppColors.titleText,
        foregroundColor: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'New Message',
      ),
      bottomNavigationBar: isWideScreen ? null : _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);
    return Container(
      decoration: BoxDecoration(
        color: darkModeProvider.isDarkMode ? AppColors.darkBackground : Colors.white,
        border: Border(
          top: BorderSide(
            color: darkModeProvider.isDarkMode ? AppColors.darkCardBorder : Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: darkModeProvider.isDarkMode ? AppColors.darkBackground : Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: darkModeProvider.isDarkMode ? AppColors.darkText : AppColors.titleText,
        unselectedItemColor: darkModeProvider.isDarkMode ? AppColors.darkTextSecondary : Colors.grey[600],
        currentIndex: 4, // Messages screen index
        onTap: (index) {
          // Handle navigation based on selected index
          switch (index) {
            case 0:
              // Home - navigate to HomeDashboardScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeDashboardScreen(isCurrentUser: true),
                ),
              );
              break;
            case 1:
              // Post - navigate to PostScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PostScreen(),
                ),
              );
              break;
            case 2:
              // Albums - navigate to AlbumsScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlbumsScreen(),
                ),
              );
              break;
            case 3:
              // Feed - navigate to FeedScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const FeedScreen(),
                ),
              );
              break;
            case 4:
              // Messages - stay on current screen (DMInboxScreen)
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.create),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Albums',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rss_feed),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to start one',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _conversations.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the bottom when loading more conversations
        if (index == _conversations.length && _isLoadingMore) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        final conversation = _conversations[index];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: conversation.unreadCount > 0 
                ? Colors.blue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: conversation.unreadCount > 0
                ? Border.all(color: Colors.blue.withOpacity(0.3))
                : null,
          ),
          child: ListTile(
            leading: _buildAvatar(conversation.otherParticipantAvatar, conversation.otherParticipantName),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    conversation.otherParticipantName,
                    style: TextStyle(
                      fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      color: conversation.unreadCount > 0 ? Colors.black : Colors.black87,
                    ),
                  ),
                ),
                if (conversation.lastTimestamp > 0)
                  Text(
                    _formatTimestamp(conversation.lastTimestamp),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.lastMessage.isNotEmpty ? conversation.lastMessage : 'No messages yet',
                  style: TextStyle(
                    color: conversation.unreadCount > 0 ? Colors.black : Colors.grey,
                    fontWeight: conversation.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: conversation.unreadCount > 0
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            onTap: () {
              _openChat(conversation.conversationId, conversation.otherParticipantName);
            },
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String? avatarUrl, String name) {
    // If we have a cached avatar URL, use it directly
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
      // Show network image with proper error handling
      return CircleAvatar(
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // Handle image loading errors by showing letter avatar
          print('DM inbox avatar image failed to load: $avatarUrl, error: $exception');
        },
        child: null, // Remove any child to let background image show
      );
    }

    // No photo or asset path - show letter avatar
    return _buildLetterAvatar(name);
  }

  Widget _buildLetterAvatar(String name) {
    // Get the first letter of the name, fallback to '?' if empty
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    
    // Generate a consistent color based on the name
    final color = _getColorFromName(name);
    
    return CircleAvatar(
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Color _getColorFromName(String name) {
    // Generate a consistent color based on the name
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
      Colors.red,
      Colors.cyan,
    ];
    
    // Use the first character's ASCII value to pick a color
    final index = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return colors[index];
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class ConversationData {
  final String conversationId;
  final String otherParticipantId;
  final String otherParticipantName;
  final String? otherParticipantAvatar;
  final String lastMessage;
  final int lastTimestamp;
  final int unreadCount;

  ConversationData({
    required this.conversationId,
    required this.otherParticipantId,
    required this.otherParticipantName,
    this.otherParticipantAvatar,
    required this.lastMessage,
    required this.lastTimestamp,
    required this.unreadCount,
  });
}
