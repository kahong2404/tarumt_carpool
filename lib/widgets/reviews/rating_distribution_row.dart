import 'package:flutter/material.dart';

class RatingDistributionRow extends StatelessWidget {
  final int star; // 5..1
  final int count;
  final int total;

  /// ⭐ allow caller to control bar color (default = primary blue)
  final Color barColor;

  const RatingDistributionRow({
    super.key,
    required this.star,
    required this.count,
    required this.total,
    this.barColor = const Color(0xFF1E73FF), // default primary
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '$star',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.star, color: Colors.amber, size: 16),
          const SizedBox(width: 8),

          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                backgroundColor: Colors.black12,

                // ✅ primary color bar
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),

          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
