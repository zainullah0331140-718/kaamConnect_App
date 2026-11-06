import 'package:flutter/material.dart';
import '../core/constants.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showBorder;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.size = 36.0,
    this.borderRadius = 8.0,
    this.showBorder = false,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(color: AppConstants.primaryColor.withOpacity(0.2), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/logo.jpg',
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppConstants.primaryColor,
            child: Icon(Icons.handyman, color: Colors.white, size: size * 0.55),
          ),
        ),
      ),
    );
  }
}
