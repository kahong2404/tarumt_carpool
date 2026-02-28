import 'package:flutter/material.dart';

class DvInfoRow {
  final String label;
  final String value;
  const DvInfoRow({required this.label, required this.value});
}

class DvInfoCard extends StatelessWidget {
  final String title;
  final List<DvInfoRow> rows;

  const DvInfoCard({
    super.key,
    required this.title,
    required this.rows,
  });

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
          // 🔹 Card Title (bold black)
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.black, // 🔥 ensure black
            ),
          ),
          const SizedBox(height: 10),

          for (final r in rows) ...[
            // 🔹 Label (Vehicle Model / Plate Number / Color)
            Text(
              r.label,
              style: const TextStyle(
                color: Colors.black,   // 🖤 BLACK
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),

            // 🔹 Value (Actual data → grey)
            Text(
              r.value.isEmpty ? 'Not submitted' : r.value,
              style: const TextStyle(
                color: Colors.black54, // ⚫ GREY
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}