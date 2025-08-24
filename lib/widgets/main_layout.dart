import 'package:flutter/material.dart';
import '../common/header.dart';
import 'bottom_navigation_bar.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final int headerIndex;
  
  const MainLayout({
    super.key,
    required this.child,
    this.headerIndex = 0,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Original header at the top
          Header(initialIndex: widget.headerIndex),
          
          // Main content
          Expanded(
            child: widget.child,
          ),
        ],
      ),
      
      // Bottom navigation bar
      bottomNavigationBar: const BottomNavigationBarWidget(),
    );
  }
}
