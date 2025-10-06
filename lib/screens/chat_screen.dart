import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../services/message_cache_service.dart';
import '../services/avatar_cache_service.dart';
import '../state/app_state.dart';
import '../styles/colors.dart';
import '../utils/responsive_utils.dart';

class ChatScreen extends StatefulWidget {
  final String? peerUid; // For backward compatibility
  final String? peerName; // For backward compatibility
  final String? conversationId; // New conversation-based approach
  final String? peerNameFromConversation; // New conversation-based approach

  const ChatScreen({
    Key? key, 
    this.peerUid, 
    this.peerName,
    this.conversationId,
    this.peerNameFromConversation,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  late final currentUser = FirebaseAuth.instance.currentUser!;

  final Map<String, String?> _avatarCache = {};
  
  // Pagination state
  List<ChatMessage> _messages = [];
  bool _isLoadingMessages = true;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  DocumentSnapshot? _lastMessageDocument;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening the chat
    _markMessagesAsRead();
    // Load initial messages with pagination
    _loadInitialMessages();
    // Add scroll listener for infinite scroll
    _scrollController.addListener(_onScroll);
    
    // Listen to AppState changes to clear avatar cache when profile pictures are updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.addListener(_onAppStateChanged);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Remove listener to prevent memory leaks
    final appState = Provider.of<AppState>(context, listen: false);
    appState.removeListener(_onAppStateChanged);
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

  void _onScroll() {
    // Check if we've scrolled near the top (for loading older messages)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingMessages = true;
      _messages.clear();
      _lastMessageDocument = null;
      _hasMoreMessages = true;
    });

    try {
      // Try to load from cache first
      String? cacheKey;
      if (widget.conversationId != null) {
        cacheKey = widget.conversationId!;
      } else if (widget.peerUid != null) {
        cacheKey = _chatService.getChatId(currentUser.uid, widget.peerUid!);
      }

      List<ChatMessage>? cachedMessages;
      if (cacheKey != null) {
        cachedMessages = await MessageCacheService.getCachedMessages(cacheKey);
      }

      // Load from server
      Map<String, dynamic> result;
      
      if (widget.conversationId != null) {
        // New conversation-based approach
        result = await _chatService.getMessagesByConversationIdPaginated(
          widget.conversationId!,
          limit: 50,
        );
      } else if (widget.peerUid != null) {
        // Old approach for backward compatibility
        result = await _chatService.getMessagesPaginated(
          currentUser.uid,
          widget.peerUid!,
          limit: 50,
        );
      } else {
        return;
      }

      final serverMessages = List<ChatMessage>.from(result['messages']);

      if (mounted) {
        setState(() {
          // Use server messages if available, otherwise use cached messages
          _messages = serverMessages.isNotEmpty ? serverMessages : (cachedMessages ?? []);
          _lastMessageDocument = result['lastDocument'];
          _hasMoreMessages = result['hasMore'];
          _isLoadingMessages = false;
        });

        // Cache the messages for offline access
        if (cacheKey != null && serverMessages.isNotEmpty) {
          await MessageCacheService.cacheMessages(cacheKey, serverMessages);
        }
      }
    } catch (e) {
      print('Error loading initial messages: $e');
      
      // If server fails, try to show cached messages
      String? cacheKey;
      if (widget.conversationId != null) {
        cacheKey = widget.conversationId!;
      } else if (widget.peerUid != null) {
        cacheKey = _chatService.getChatId(currentUser.uid, widget.peerUid!);
      }

      if (cacheKey != null) {
        final cachedMessages = await MessageCacheService.getCachedMessages(cacheKey);
        if (mounted && cachedMessages != null) {
          setState(() {
            _messages = cachedMessages;
            _isLoadingMessages = false;
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      Map<String, dynamic> result;
      
      if (widget.conversationId != null) {
        // New conversation-based approach
        result = await _chatService.getMessagesByConversationIdPaginated(
          widget.conversationId!,
          limit: 50,
          lastDocument: _lastMessageDocument,
        );
      } else if (widget.peerUid != null) {
        // Old approach for backward compatibility
        result = await _chatService.getMessagesPaginated(
          currentUser.uid,
          widget.peerUid!,
          limit: 50,
          lastDocument: _lastMessageDocument,
        );
      } else {
        return;
      }

      final moreMessages = List<ChatMessage>.from(result['messages']);
      
      if (mounted && moreMessages.isNotEmpty) {
        setState(() {
          _messages.addAll(moreMessages);
          _lastMessageDocument = result['lastDocument'];
          _hasMoreMessages = result['hasMore'];
          _isLoadingMore = false;
        });
      } else if (mounted) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more messages: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      if (widget.conversationId != null) {
        // New conversation-based approach
        // TODO: Implement mark as read for conversations
      } else if (widget.peerUid != null) {
        // Old approach for backward compatibility
        await _chatService.markMessagesAsRead(currentUser.uid, widget.peerUid!);
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      // Create message object for immediate UI update
      final newMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        senderId: currentUser.uid,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        readBy: [currentUser.uid],
      );

      // Add message to local list immediately for instant UI feedback
      setState(() {
        _messages.insert(0, newMessage);
      });

      // Cache the new message
      String? cacheKey;
      if (widget.conversationId != null) {
        cacheKey = widget.conversationId!;
      } else if (widget.peerUid != null) {
        cacheKey = _chatService.getChatId(currentUser.uid, widget.peerUid!);
      }
      
      if (cacheKey != null) {
        MessageCacheService.addMessageToCache(cacheKey, newMessage);
      }

      // Send to server
      if (widget.conversationId != null) {
        // New conversation-based approach
        print('Sending message to conversation ${widget.conversationId}: $text');
        _chatService.sendMessageToConversation(widget.conversationId!, currentUser.uid, text);
      } else if (widget.peerUid != null) {
        // Old approach for backward compatibility
        print('Sending message from ${currentUser.uid} to ${widget.peerUid}: $text');
        _chatService.sendMessage(currentUser.uid, widget.peerUid!, text);
      }
      _controller.clear();
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (widget.conversationId != null) {
          await _chatService.sendImageMessageToConversation(widget.conversationId!, currentUser.uid, bytes, image.name);
        } else if (widget.peerUid != null) {
          await _chatService.sendImageMessage(currentUser.uid, widget.peerUid!, bytes, image.name);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
                  if (widget.conversationId != null) {
          await _chatService.sendFileMessageToConversation(widget.conversationId!, currentUser.uid, file.bytes!, file.name);
        } else if (widget.peerUid != null) {
          await _chatService.sendFileMessage(currentUser.uid, widget.peerUid!, file.bytes!, file.name);
        }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending file: $e')),
      );
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

  Widget _buildChatAvatar(String? avatarUrl, String userId) {
    // Check if it's a network URL (real photo) or asset/default
    if (avatarUrl == null || avatarUrl.isEmpty || !avatarUrl.startsWith('http')) {
      // No photo or asset path - show letter avatar with actual name
      final peerName = widget.peerNameFromConversation ?? widget.peerName ?? 'User';
      return _buildLetterAvatar(peerName);
    }

    // Show network image with proper error handling
    return CircleAvatar(
      radius: 16,
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (exception, stackTrace) {
        // Handle image loading errors by showing letter avatar
        print('Chat avatar image failed to load: $avatarUrl, error: $exception');
      },
      child: null, // Remove the preemptive fallback for Google URLs
    );
  }

  Widget _buildLetterAvatar(String name) {
    // Get the first letter of the name, fallback to '?' if empty
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    
    // Generate a consistent color based on the name
    final color = _getColorFromName(name);
    
    return CircleAvatar(
      radius: 16,
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

  Widget _buildMessageContent(ChatMessage msg) {
    switch (msg.messageType) {
      case MessageType.text:
        return Text(msg.text, style: TextStyle(color: msg.senderId == currentUser.uid ? Colors.white : Colors.black));
      
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(msg.text, style: TextStyle(color: msg.senderId == currentUser.uid ? Colors.white : Colors.black)),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                msg.fileUrl!,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[300],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(height: 4),
                          Text('Image failed to load', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      
      case MessageType.file:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(msg.text, style: TextStyle(color: msg.senderId == currentUser.uid ? Colors.white : Colors.black)),
              ),
            InkWell(
              onTap: () async {
                if (msg.fileUrl != null) {
                  await launchUrl(Uri.parse(msg.fileUrl!));
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file, color: Colors.blue),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.fileName ?? 'File',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (msg.fileSize != null)
                            Text(
                              '${(msg.fileSize! / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('ChatScreen: currentUser.uid = ${currentUser.uid}');
    print('ChatScreen: widget.peerUid = ${widget.peerUid}');
    print('ChatScreen: widget.peerName = ${widget.peerName}');
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat with ${widget.peerNameFromConversation ?? widget.peerName ?? 'Unknown'}"),
        backgroundColor: AppColors.titleText,
        foregroundColor: Colors.white,
      ),
      body: ResponsiveUtils.isWideScreen(context) 
          ? _buildDesktopLayout(context)
          : _buildMobileLayout(context),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1400),
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Chat info and user details
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.only(top: 24.0, right: 16.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF8E1), // Light cream
                        Color(0xFFFFE0B2), // Light orange
                        Color(0xFFFFCC80), // Medium orange
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat Info',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.titleText,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildUserInfo(),
                        const SizedBox(height: 20),
                        _buildChatActions(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Right side - Chat messages
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(top: 24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Chat header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.titleText,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            FutureBuilder<String?>(
                              future: _getAvatarUrl(widget.peerUid ?? ''),
                              builder: (context, snapshot) {
                                final avatarUrl = snapshot.data;
                                return _buildChatAvatar(avatarUrl, widget.peerUid ?? '');
                              },
                            ),
                            const SizedBox(width: 12),
                            Text(
                              widget.peerNameFromConversation ?? widget.peerName ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Messages area
                      Expanded(
                        child: _buildMessagesList(),
                      ),
                      // Input area
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                        ),
                        child: _buildMessageInput(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _buildMessagesList(),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: _buildMessageInput(),
        )
      ],
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FutureBuilder<String?>(
              future: _getAvatarUrl(widget.peerUid ?? ''),
              builder: (context, snapshot) {
                final avatarUrl = snapshot.data;
                if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
                  return CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(avatarUrl),
                    onBackgroundImageError: (exception, stackTrace) {
                      print('User info avatar image failed to load: $avatarUrl, error: $exception');
                    },
                  );
                } else {
                  // No photo - show letter avatar
                  final peerName = widget.peerNameFromConversation ?? widget.peerName ?? 'User';
                  return CircleAvatar(
                    radius: 30,
                    backgroundColor: _getColorFromName(peerName),
                    child: Text(
                      peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerNameFromConversation ?? widget.peerName ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.titleText,
                    ),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChatActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.titleText,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: const Text('Send Image'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: const Text('Send File'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickFile();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.attach_file),
            label: const Text('Attach File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.titleText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (_, index) {
        // Show loading indicator at the top when loading more messages
        if (index == _messages.length && _isLoadingMore) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final msg = _messages[index];
        final isMe = msg.senderId == currentUser.uid;
        return Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
                if (!isMe)
                  FutureBuilder<String?>(
                    future: _getAvatarUrl(msg.senderId),
                    builder: (context, snapshot) {
                      final avatarUrl = snapshot.data;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6, left: 8, bottom: 2),
                        child: _buildChatAvatar(avatarUrl, msg.senderId),
                      );
                    },
                  ),
                Flexible(
                  child: Container(
                    margin: isMe
                        ? const EdgeInsets.only(left: 40, right: 8, top: 4, bottom: 4)
                        : const EdgeInsets.only(left: 8, right: 40, top: 4, bottom: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.titleText : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildMessageContent(msg),
                  ),
                ),
                if (isMe)
                  FutureBuilder<String?>(
                    future: _getAvatarUrl(msg.senderId),
                    builder: (context, snapshot) {
                      final avatarUrl = snapshot.data;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6, right: 8, bottom: 2),
                        child: _buildChatAvatar(avatarUrl, msg.senderId),
                      );
                    },
                  ),
              ],
            );
          },
        );
  }

  Widget _buildMessageInput() {
    return Row(
      children: [
        Container(
          decoration: AppColors.inputDecoration,
          child: IconButton(
            icon: const Icon(Icons.attach_file, color: AppColors.titleText),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: const Text('Send Image'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: const Text('Send File'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickFile();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: AppColors.inputDecoration,
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "Type a message...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: AppColors.inputDecoration,
          child: IconButton(
            icon: const Icon(Icons.send, color: AppColors.titleText),
            onPressed: _sendMessage,
          ),
        ),
      ],
    );
  }
} 