import 'package:flutter/material.dart';
import 'lib/screens/home_dashboard_screen.dart';

void main() {
  runApp(const HomeDashboardPreviewApp());
}

class HomeDashboardPreviewApp extends StatelessWidget {
  const HomeDashboardPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Dashboard Preview',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        body: const HomeDashboardScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

