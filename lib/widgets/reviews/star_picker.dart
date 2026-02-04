import 'package:flutter/material.dart';

class StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final bool centered;
  final double size;

  const StarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.centered = true,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: List.generate(5, (i) {
        final star = i + 1;
        return IconButton(
          onPressed: () => onChanged(star),
          icon: Icon(
            star <= value ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
        );
      }),
    );
  }
}
