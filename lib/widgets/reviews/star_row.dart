import 'package:flutter/material.dart';

class StarRow extends StatelessWidget {
  final int value;
  final double size;

  const StarRow({
    super.key,
    required this.value,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 5);
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = (i + 1) <= v;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }
}
