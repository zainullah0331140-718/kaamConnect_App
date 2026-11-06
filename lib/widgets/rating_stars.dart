import 'package:flutter/material.dart';
import '../core/constants.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final int? reviewCount;
  final double size;
  final bool showText;

  const RatingStars({
    super.key,
    required this.rating,
    this.reviewCount,
    this.size = 16,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            IconData icon;
            if (rating >= starIndex) {
              icon = Icons.star_rounded;
            } else if (rating >= starIndex - 0.5) {
              icon = Icons.star_half_rounded;
            } else {
              icon = Icons.star_outline_rounded;
            }
            return Icon(
              icon,
              size: size,
              color: AppConstants.secondaryColor,
            );
          }),
        ),
        if (showText) ...[
          const SizedBox(width: 4),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : 'New',
            style: TextStyle(
              fontSize: size * 0.85,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          if (reviewCount != null && reviewCount! > 0) ...[
            Text(
              ' ($reviewCount)',
              style: TextStyle(
                fontSize: size * 0.75,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
