import 'package:flutter/material.dart';

class ReviewCommentBox extends StatelessWidget {
  final String text;
  final Color borderColor;
  final double borderWidth;

  const ReviewCommentBox({
    super.key,
    required this.text,
    required this.borderColor,
    this.borderWidth = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    final t = text.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Text(
        t.isEmpty ? '-' : t,
        style: const TextStyle(height: 1.3, color: Colors.black87),
      ),
    );
  }
}
