import 'package:flutter/material.dart';

class DriverReviewFilterBar extends StatefulWidget {
  /// "all", "5", "4", "3", "2", "1"
  final String starFilter;

  /// true = latest first
  final bool descending;

  final ValueChanged<String> onStarChanged;
  final ValueChanged<bool> onSortChanged;

  const DriverReviewFilterBar({
    super.key,
    required this.starFilter,
    required this.descending,
    required this.onStarChanged,
    required this.onSortChanged,
  });

  @override
  State<DriverReviewFilterBar> createState() => _DriverReviewFilterBarState();
}

class _DriverReviewFilterBarState extends State<DriverReviewFilterBar> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: widget.starFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All stars')),
                    DropdownMenuItem(value: '5', child: Text('5 ★')),
                    DropdownMenuItem(value: '4', child: Text('4 ★')),
                    DropdownMenuItem(value: '3', child: Text('3 ★')),
                    DropdownMenuItem(value: '2', child: Text('2 ★')),
                    DropdownMenuItem(value: '1', child: Text('1 ★')),
                  ],
                  onChanged: (v) => widget.onStarChanged(v ?? 'all'),
                  decoration: const InputDecoration(
                    labelText: 'Star',
                    filled: true,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<bool>(
                  value: widget.descending,
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Latest first')),
                    DropdownMenuItem(value: false, child: Text('Oldest first')),
                  ],
                  onChanged: (v) => widget.onSortChanged(v ?? true),
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    filled: true,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
