import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:tarumt_carpool/repositories/user_repository.dart';
import 'package:tarumt_carpool/services/review/review_service.dart';
import 'package:tarumt_carpool/widgets/primary_button.dart';

// split review widgets
import 'package:tarumt_carpool/widgets/reviews/review_white_card.dart';
import 'package:tarumt_carpool/widgets/reviews/user_header.dart';
import 'package:tarumt_carpool/widgets/reviews/star_picker.dart';

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

  //This function returns a Stream that provides driver info (name + photo) for UI header.
  Stream<_DriverHeaderVM> _streamDriverHeader() {
    final rideRef = _db.collection('rides').doc(widget.rideId);   //Gets reference to ride document: /rides/{rideId}.

    return rideRef.snapshots().asyncMap((snap) async {       //snapshots() = listen to ride doc in real-time.asyncMap because inside you will call another async function (get user doc).
//If ride doc not found → return default header.
      if (!snap.exists) {
        return const _DriverHeaderVM(name: 'Driver', photoUrl: null);
      }

      final ride = snap.data() ?? {};
      final driverId = (ride['driverID'] ?? '').toString().trim();

      if (driverId.isEmpty) {
        return const _DriverHeaderVM(name: 'Driver', photoUrl: null);
      }

      final user = await _userRepo.getUserDocMap(driverId);
      return _DriverHeaderVM(
        name: (user?['name'] ?? 'Driver').toString(),
        photoUrl: (user?['photoUrl'] ?? '').toString().trim().isEmpty
            ? null
            : user!['photoUrl'].toString(),
      );
    });
  }

  Future<void> _submit() async {
    setState(() => _loading = true);

    try {
      final result = await _reviewService.submitRiderReview(
        rideId: widget.rideId,
        ratingScore: _stars,
        commentText: _commentCtrl.text.trim(),
      );

      if (!mounted) return;

      final message = result.suspicious
          ? 'Review submitted\n'
          'Some language in your review requires a quick admin check.\n'
          'Your review will appear once approved.'
          : 'Review submitted';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
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
      backgroundColor: primary,
      appBar: AppBar(
        title: const Text('Review and Rating'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ReviewWhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<_DriverHeaderVM>(
                  stream: _streamDriverHeader(),
                  builder: (context, snap) {
                    final vm = snap.data ??
                        const _DriverHeaderVM(
                          name: 'Driver',
                          photoUrl: null,
                        );
                    return UserHeader(name: vm.name, photoUrl: vm.photoUrl);
                  },
                ),
                const SizedBox(height: 14),

                StarPicker(
                  value: _stars,
                  onChanged: (v) => setState(() => _stars = v),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _commentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write your review ...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primary, width: 2),
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
