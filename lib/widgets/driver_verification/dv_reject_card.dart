import 'package:flutter/material.dart';

class DvRejectCard extends StatelessWidget {
  final String reason;
  const DvRejectCard({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rejected Reason',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            reason,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
