import 'package:flutter/material.dart';
import 'package:tarumt_carpool/models/driver_offer.dart';
import 'package:tarumt_carpool/repositories/rides_offer_repository.dart';

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

  final DriverOfferRepository _repo = DriverOfferRepository();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _loading = false;

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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _postRide() async {
    final pickup = _pickupCtrl.text.trim();
    final dest = _destinationCtrl.text.trim();

    if (pickup.isEmpty) return _snack("Please enter pickup location.");
    if (dest.isEmpty) return _snack("Please enter destination.");
    if (_selectedDate == null) return _snack("Please select date.");
    if (_selectedTime == null) return _snack("Please select time.");

    final seats = int.tryParse(_seatsCtrl.text.trim());
    if (seats == null || seats <= 0) return _snack("Seats must be a number > 0.");

    final fareText = _fareCtrl.text.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final fare = double.tryParse(fareText);
    if (fare == null || fare < 0) return _snack("Fare must be a valid number (e.g. 5.00).");

    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (dt.isBefore(DateTime.now())) {
      return _snack("Selected date/time is in the past.");
    }

    setState(() => _loading = true);

    try {
      final offer = DriverOffer(
        driverId: '', // Repository will replace with current user uid
        pickup: pickup,
        destination: dest,
        rideDateTime: dt,
        seatsAvailable: seats,
        fare: fare,
      );

      final id = await _repo.create(offer);
      _snack("Posted successfully! ID: $id");

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack("Failed to post ride: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              decoration: _dec(
                'Pick Up Location',
                Icons.location_on_outlined,
                hint: 'Enter pickup location',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _destinationCtrl,
              decoration: _dec(
                'Destination',
                Icons.flag_outlined,
                hint: 'Enter destination',
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateCtrl,
                    readOnly: true,
                    decoration: _dec('Date', Icons.calendar_month_outlined),
                    onTap: _loading
                        ? null
                        : () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: DateTime.now(),
                      );
                      if (picked != null) {
                        _selectedDate = picked;
                        _dateCtrl.text = '${picked.day}/${picked.month}/${picked.year}';
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _timeCtrl,
                    readOnly: true,
                    decoration: _dec('Time', Icons.access_time_outlined),
                    onTap: _loading
                        ? null
                        : () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        _selectedTime = picked;
                        _timeCtrl.text = picked.format(context);
                        setState(() {});
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec('Ride Fare', Icons.attach_money_outlined, hint: 'RM 0.00'),
            ),
            const SizedBox(height: 14),

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

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _postRide,
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2B6CFF)),
                child: _loading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text(
                  'Post Your Ride',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
