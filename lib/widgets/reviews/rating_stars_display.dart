import 'package:flutter/material.dart';

class RatingStarsDisplay extends StatelessWidget {
  final double value; // e.g. 3.5
  final double size;

  const RatingStarsDisplay({
    super.key,
    required this.value,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    final fullStars = value.floor(); // 3
    final hasHalfStar = (value - fullStars) >= 0.5; // true if .5
    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Full stars
        for (int i = 0; i < fullStars; i++)
          Icon(Icons.star, color: Colors.amber, size: size),

        // Half star
        if (hasHalfStar)
          Icon(Icons.star_half, color: Colors.amber, size: size),

        // Empty stars
        for (int i = 0; i < emptyStars; i++)
          Icon(Icons.star_border, color: Colors.amber, size: size),
      ],
    );
  }
}