import 'package:flutter/material.dart';
import 'dart:math' as math;

class CustomLoader extends StatefulWidget {
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;

  const CustomLoader({
    Key? key,
    this.size = 30.0,
    this.primaryColor = const Color(0xFF554236),
    this.secondaryColor = const Color(0xFFF77825),
    this.tertiaryColor = const Color(0xFF60B99A),
  }) : super(key: key);

  @override
  State<CustomLoader> createState() => _CustomLoaderState();
}

class _CustomLoaderState extends State<CustomLoader>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pseudoController1;
  late AnimationController _pseudoController2;

  late Animation<double> _mainRotation;
  late Animation<double> _pseudo1Rotation;
  late Animation<double> _pseudo2Rotation;

  @override
  void initState() {
    super.initState();

    // Main rotation animation (0 to 90 degrees)
    _mainController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _mainRotation = Tween<double>(
      begin: 0,
      end: math.pi / 2, // 90 degrees in radians
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.linear,
    ));

    // Pseudo-element 1 animation (30 degrees)
    _pseudoController1 = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _pseudo1Rotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: math.pi / 6, // 30 degrees in radians
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: math.pi / 6,
          end: 0,
        ),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _pseudoController1,
      curve: Curves.linear,
    ));

    // Pseudo-element 2 animation (60 degrees)
    _pseudoController2 = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _pseudo2Rotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: math.pi / 3, // 60 degrees in radians
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: math.pi / 3,
          end: 0,
        ),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _pseudoController2,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pseudoController1.dispose();
    _pseudoController2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _mainController,
          _pseudoController1,
          _pseudoController2,
        ]),
        builder: (context, child) {
          return Transform.rotate(
            angle: _mainRotation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main square (background)
                Container(
                  width: widget.size,
                  height: widget.size,
                  color: widget.primaryColor,
                ),
                // Pseudo-element 1 (orange) - same size as main, but with different rotation
                Transform.rotate(
                  angle: _pseudo1Rotation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    color: widget.secondaryColor,
                  ),
                ),
                // Pseudo-element 2 (green) - same size as main, but with different rotation
                Transform.rotate(
                  angle: _pseudo2Rotation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    color: widget.tertiaryColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 