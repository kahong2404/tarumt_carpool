import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:tarumt_carpool/repositories/user_repository.dart';
import 'package:tarumt_carpool/services/review/review_service.dart';
import 'package:tarumt_carpool/widgets/primary_button.dart';
import 'package:tarumt_carpool/widgets/reviews/review_widgets.dart';

class RiderSubmitReviewScreen extends StatefulWidget {
  final String rideId;
  const RiderSubmitReviewScreen({super.key, required this.rideId});

  @override
  State<RiderSubmitReviewScreen> createState() => _RiderSubmitReviewScreenState();
}

class _RiderSubmitReviewScreenState extends State<RiderSubmitReviewScreen> {
  static const primary = Color(0xFF1E73FF);

  final _reviewService = ReviewService();
  final _userRepo = UserRepository();
  final _db = FirebaseFirestore.instance;

  final _commentCtrl = TextEditingController();
  int _stars = 5;
  bool _loading = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Stream<_DriverHeaderVM> _streamDriverHeader() {
    final rideRef = _db.collection('rides').doc(widget.rideId);

    return rideRef.snapshots().asyncMap((rideSnap) async {
      if (!rideSnap.exists) {
        return const _DriverHeaderVM(name: 'Driver', photoUrl: null);
      }

      final ride = rideSnap.data() ?? <String, dynamic>{};
      final driverId = (ride['driverID'] ?? '').toString().trim();

      if (driverId.isEmpty) {
        return const _DriverHeaderVM(name: 'Driver', photoUrl: null);
      }

      final userMap = await _userRepo.getUserDocMap(driverId);
      final name = (userMap?['name'] ?? 'Driver').toString();
      final photoUrl = userMap?['photoUrl']?.toString();

      return _DriverHeaderVM(
        name: name,
        photoUrl: (photoUrl != null && photoUrl.trim().isNotEmpty) ? photoUrl.trim() : null,
      );
    });
  }

  Future<void> _submit() async {
    final comment = _commentCtrl.text.trim();

    setState(() => _loading = true);
    try {
      await _reviewService.submitRiderReview(
        rideId: widget.rideId,
        ratingScore: _stars,
        commentText: comment,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: primary,
      appBar: AppBar(
        title: const Text('Review and Rating'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: ReviewWhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<_DriverHeaderVM>(
                  stream: _streamDriverHeader(),
                  builder: (context, snap) {
                    final vm = snap.data ?? const _DriverHeaderVM(name: 'Driver', photoUrl: null);
                    return UserHeader(name: vm.name, photoUrl: vm.photoUrl);
                  },
                ),
                const SizedBox(height: 14),
                StarPicker(
                  value: _stars,
                  onChanged: (v) => setState(() => _stars = v),
                  centered: true,
                  size: 28,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write your review ...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primary, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primary, width: 1.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primary, width: 2.2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Submit Review',
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverHeaderVM {
  final String name;
  final String? photoUrl;
  const _DriverHeaderVM({required this.name, required this.photoUrl});
}
