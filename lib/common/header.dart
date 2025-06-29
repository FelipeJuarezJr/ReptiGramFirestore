import 'package:flutter/material.dart';
import '../styles/colors.dart';
import '../screens/albums_screen.dart';
import '../screens/post_screen.dart';
import '../screens/feed_screen.dart';
import '../screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Header extends StatefulWidget {
  final int initialIndex;
  
  const Header({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  Widget _buildNavItem(String title, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const PostScreen(),
            ),
          );
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const AlbumsScreen(),
            ),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const Feed(),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        width: MediaQuery.of(context).size.width / 3,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _selectedIndex == index ? AppColors.titleText : Colors.brown,
            fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCommonNavMenu() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem('Post', 0),
            _buildNavItem('Albums', 1),
            _buildNavItem('Feed', 2),
          ],
        ),
        Container(
          width: double.infinity,
          height: 2,
          child: Stack(
            children: [
              Positioned(
                left: _selectedIndex * (MediaQuery.of(context).size.width / 3),
                width: MediaQuery.of(context).size.width / 3,
                child: Container(
                  height: 2,
                  color: const Color(0xFFf6e29b),
                ),
              ),
            ],
          ),
        ),
        if (_selectedIndex == 2)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.grid_on),
                  color: const Color(0xFFf6e29b),
                  onPressed: () {
                    print('Grid icon pressed');
                    FeedState.setFeedType(FeedType.images);
                    setState(() {}); // Trigger rebuild
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.star),
                  color: const Color(0xFFf6e29b),
                  onPressed: () {
                    print('Star icon pressed');
                    FeedState.setFeedType(FeedType.favorites);
                    setState(() {}); // Trigger rebuild
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  color: Colors.grey[400],
                  onPressed: null, // Disable the button
                ),
                IconButton(
                  icon: const Icon(Icons.people_outline),
                  color: Colors.grey[400],
                  onPressed: null, // Disable the button
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildCommonNavMenu();
  }
}

// Enum for feed types
enum FeedType {
  images,
  videos,
  groups,
  favorites,
}

// Feed state class
class FeedState extends State<Feed> {
  static FeedType _currentType = FeedType.images;
  static final ValueNotifier<FeedType> _typeNotifier = ValueNotifier<FeedType>(_currentType);

  @override
  void initState() {
    super.initState();
    print('FeedState initialized with type: $_currentType');
  }

  static void setFeedType(FeedType type) {
    print('Setting feed type to: $type');
    _currentType = type;
    _typeNotifier.value = type;
    print('Feed type changed to: $type');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FeedType>(
      valueListenable: _typeNotifier,
      builder: (context, type, child) {
        print('Building Feed with type: $type');
        switch (type) {
          case FeedType.images:
            return const FeedScreen();
          case FeedType.videos:
            return const Center(child: Text('Videos coming soon'));
          case FeedType.groups:
            return const Center(child: Text('Groups coming soon'));
          case FeedType.favorites:
            print('Building favorites view');
            return const FeedScreen(showLikedOnly: true);
        }
      },
    );
  }
}

class Feed extends StatefulWidget {
  const Feed({super.key});

  @override
  State<Feed> createState() => FeedState();
} 