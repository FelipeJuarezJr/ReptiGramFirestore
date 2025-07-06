import 'package:flutter/material.dart';
import 'custom_loader.dart';

class LoaderTestPage extends StatelessWidget {
  const LoaderTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Loader Test'),
        backgroundColor: const Color(0xFF554236),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Custom Loader Demo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF554236),
              ),
            ),
            const SizedBox(height: 40),
            const CustomLoader(
              size: 60,
            ),
            const SizedBox(height: 40),
            const CustomLoader(
              size: 40,
            ),
            const SizedBox(height: 40),
            const CustomLoader(
              size: 30,
            ),
            const SizedBox(height: 40),
            const Text(
              'Different Colors:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF554236),
              ),
            ),
            const SizedBox(height: 20),
            const CustomLoader(
              size: 50,
              primaryColor: Colors.blue,
              secondaryColor: Colors.red,
              tertiaryColor: Colors.yellow,
            ),
          ],
        ),
      ),
    );
  }
} 