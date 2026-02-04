import 'package:flutter/material.dart';

class RatingStarsDisplay extends StatelessWidget {
  final double value; // 0..5
  final double size;

  const RatingStarsDisplay({
    super.key,
    required this.value,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = (i + 1) <= v.round();
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }
}
