import 'package:flutter/material.dart';

class PostScreen extends StatelessWidget {
  final bool shouldLoadPosts;
  
  const PostScreen({super.key, this.shouldLoadPosts = false});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Post Screen Coming Soon'),
      ),
    );
  }
} 