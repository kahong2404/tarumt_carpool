import 'package:flutter/material.dart';

class DriverVerificationFilterBar extends StatefulWidget {
  final String status;          // pending/approved/rejected/all
  final bool descending;        // true = latest first

  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onSortChanged;

  final ValueChanged<String> onSearchuserId;
  final VoidCallback onClearSearch;

  const DriverVerificationFilterBar({
    super.key,
    required this.status,
    required this.descending,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onSearchuserId,
    required this.onClearSearch,
  });

  @override
  State<DriverVerificationFilterBar> createState() =>
      _DriverVerificationFilterBarState();
}

class _DriverVerificationFilterBarState extends State<DriverVerificationFilterBar> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by Staff ID (exact)',
                    filled: true,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (v) => widget.onSearchuserId(v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  _searchCtrl.clear();
                  widget.onClearSearch();
                },
                icon: const Icon(Icons.clear),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: widget.status,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                    DropdownMenuItem(value: 'all', child: Text('All')),
                  ],
                  onChanged: (v) => widget.onStatusChanged(v ?? 'pending'),
                  decoration: const InputDecoration(
                    labelText: 'Status',
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
