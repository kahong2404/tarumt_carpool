import 'package:flutter/material.dart';
import 'package:tarumt_carpool/rides/post_rides_service.dart';

class PostRides extends StatefulWidget {
  const PostRides({super.key});

  @override
  State<PostRides> createState() => _PostRides();
}

class _PostRides extends State<PostRides> {
  final _pickupCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController();
  final _fareCtrl = TextEditingController();

  // final _service = DriverOfferRtdbService();
  // bool _loading = false;


  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destinationCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _seatsCtrl.dispose();
    _fareCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final blue = const Color(0xFF1E73FF);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Create Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Post Your Ride',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Share your journey and help others reach their destination',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _pickupCtrl,
              decoration: _dec('Pick Up Location', Icons.location_on_outlined,
                  hint: 'Enter pickup location'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _destinationCtrl,
              decoration: _dec('Destination', Icons.flag_outlined,
                  hint: 'Enter destination'),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateCtrl,
                    readOnly: true,
                    decoration:
                    _dec('Date', Icons.calendar_month_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: DateTime.now(),
                      );
                      if (picked != null) {
                        _dateCtrl.text =
                        '${picked.day}/${picked.month}/${picked.year}';
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _timeCtrl,
                    readOnly: true,
                    decoration:
                    _dec('Time', Icons.access_time_outlined),
                    onTap: () async {
                      final picked =
                      await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (picked != null) {
                        _timeCtrl.text = picked.format(context);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _seatsCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('Seats Available', Icons.event_seat_outlined),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _fareCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration:
              _dec('Ride Fare', Icons.attach_money_outlined, hint: 'RM 0.00'),
            ),
            const SizedBox(height: 14),

            // Tip box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: blue.withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Set a fair price and be punctual to build a good reputation with passengers!',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Post Ride Offer
            SizedBox(
              width: double.infinity,
              height: 48,
            //   child: ElevatedButton(
            //     onPressed: _loading ? null : () async {
            //       // 1. Basic validation
            //       if (_pickupCtrl.text.isEmpty ||
            //           _destinationCtrl.text.isEmpty ||
            //           _dateCtrl.text.isEmpty ||
            //           _timeCtrl.text.isEmpty ||
            //           _seatsCtrl.text.isEmpty) {
            //         ScaffoldMessenger.of(context).showSnackBar(
            //           const SnackBar(content: Text('Please fill in all fields')),
            //         );
            //         return;
            //       }
            //
            //       final totalSeats = int.tryParse(_seatsCtrl.text);
            //       if (totalSeats == null || totalSeats <= 0) {
            //         ScaffoldMessenger.of(context).showSnackBar(
            //           const SnackBar(content: Text('Invalid seats number')),
            //         );
            //         return;
            //       }
            //
            //       // 🔑 Replace with your real logged-in driver ID
            //       final driverID = 'CURRENT_DRIVER_UID';
            //
            //       try {
            //         setState(() => _loading = true);
            //
            //         final offerID = await _service.createDriverOffer(
            //           driverID: driverID,
            //           origin: _pickupCtrl.text,
            //           destination: _destinationCtrl.text,
            //           rideDate: _dateCtrl.text,
            //           rideTime: _timeCtrl.text,
            //           totalSeats: totalSeats,
            //         );
            //
            //         if (!mounted) return;
            //
            //         ScaffoldMessenger.of(context).showSnackBar(
            //           const SnackBar(content: Text('Ride offer posted successfully')),
            //         );
            //
            //         Navigator.pop(context); // go back after success
            //       } catch (e) {
            //         ScaffoldMessenger.of(context).showSnackBar(
            //           SnackBar(content: Text('Failed to post ride: $e')),
            //         );
            //       } finally {
            //         if (mounted) setState(() => _loading = false);
            //       }
            //     },
            //
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: blue,
            //     ),
            //     child: _loading
            //         ? const CircularProgressIndicator(color: Colors.white)
            //         : const Text(
            //       'Post Ride Offer',
            //       style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            //     ),
            //   ),
            ),
            const SizedBox(height: 10),

            // Cancel
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
