import 'package:flutter/material.dart';

class PulsingGlowingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const PulsingGlowingIcon({
    Key? key,
    required this.icon,
    required this.color,
    this.size = 24.0,
  }) : super(key: key);

  @override
  State<PulsingGlowingIcon> createState() => _PulsingGlowingIconState();
}

class _PulsingGlowingIconState extends State<PulsingGlowingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.5 * _glowAnimation.value),
                  blurRadius: 8.0 * _glowAnimation.value,
                  spreadRadius: 4.0 * _glowAnimation.value,
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: widget.color,
              size: widget.size,
            ),
          ),
        );
      },
    );
  }
}
