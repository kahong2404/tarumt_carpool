import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tarumt_carpool/models/driver_verification_application.dart';
import 'package:tarumt_carpool/services/driver_verification/admin/driver_verification_review_service.dart';

import 'driver_verification_detail_page.dart';

class DriverVerificationListPage extends StatefulWidget {
  const DriverVerificationListPage({super.key});

  @override
  State<DriverVerificationListPage> createState() =>
      _DriverVerificationListPageState();
}

class _DriverVerificationListPageState extends State<DriverVerificationListPage> {
  static const brandBlue = Color(0xFF1E73FF);

  final _svc = DriverVerificationReviewService();
  final _searchCtrl = TextEditingController();

  String _status = 'all'; // all/pending/approved/rejected
  bool _descending = true; // latest first
  String _searchStaffId = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _searchStaffId.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        title: const Text('Driver Verification List'),
      ),
      body: Column(
        children: [
          _buildTopFilters(),
          Expanded(
            child: searching ? _buildSearchStream() : _buildListStream(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search by Staff ID (exact)',
                    filled: true,
                    fillColor: const Color(0xFFF2F4F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (v) => setState(() => _searchStaffId = v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchStaffId = '');
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
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'approved', child: Text('Approved')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<bool>(
                  value: _descending,
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Latest first')),
                    DropdownMenuItem(value: false, child: Text('Oldest first')),
                  ],
                  onChanged: (v) => setState(() => _descending = v ?? true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListStream() {
    return StreamBuilder<List<DriverVerificationApplication>>(
      stream: _svc.streamApplications(status: _status, descending: _descending),
      builder: (context, snap) {
        if (snap.hasError) return _errorBox(snap.error.toString());
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? [];
        if (items.isEmpty) return const Center(child: Text('No applications.'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final app = items[i];
            return _AdminCard(
              app: app,
              onTap: () => _openDetail(app.staffId),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchStream() {
    final staffId = _searchStaffId.trim();

    return StreamBuilder<DriverVerificationApplication?>(
      stream: _svc.streamApplication(staffId),
      builder: (context, snap) {
        if (snap.hasError) return _errorBox(snap.error.toString());
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final app = snap.data;
        if (app == null) return const Center(child: Text('No application found.'));

        if (_status != 'all' && app.profile.status != _status) {
          return const Center(child: Text('No application matches status filter.'));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _AdminCard(app: app, onTap: () => _openDetail(app.staffId)),
          ],
        );
      },
    );
  }

  Widget _errorBox(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $msg', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  void _openDetail(String staffId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverVerificationDetailPage(staffId: staffId),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final DriverVerificationApplication app;
  final VoidCallback onTap;

  const _AdminCard({required this.app, required this.onTap});

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFFFB300);
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'rejected':
        return const Color(0xFFC62828);
      default:
        return Colors.black45;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = app.profile.status;
    final c = _statusColor(status);

    // ✅ CORRECT DATE: prefer updatedAt (admin reviewed), fallback submittedAt (first submit)
    final dt = (app.updatedAt ?? app.submittedAt)?.toDate().toLocal();
    final dateText = dt == null ? '-' : DateFormat('dd MMM yyyy').format(dt);
    final timeText = dt == null ? '-' : DateFormat('hh:mm a').format(dt);

    // ✅ CORRECT FIELD: DriverVerificationProfile uses vehicleModel
    final vehicleModel = app.profile.vehicleModel.trim().isEmpty
        ? 'Unknown Vehicle'
        : app.profile.vehicleModel.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 4),
              color: Color(0x14000000),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicleModel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Staff ID: ${app.staffId}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$dateText • $timeText',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.withOpacity(0.25)),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(color: c, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E73FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Review'),
            ),
          ],
        ),
      ),
    );
  }
}
