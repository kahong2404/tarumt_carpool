import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tarumt_carpool/models/driver_offer.dart';
import 'package:tarumt_carpool/repositories/driver_offer_repository.dart';
import 'package:tarumt_carpool/services/google_direction_service.dart';
import 'package:tarumt_carpool/widgets/LocationSearch/location_select_screen.dart';
import 'package:tarumt_carpool/widgets/layout/app_scaffold.dart';

class EditPostScreenRides extends StatefulWidget {
  final String offerId;

  const EditPostScreenRides({
    super.key,
    required this.offerId,
  });

  @override
  State<EditPostScreenRides> createState() => _EditPostScreenRidesState();
}

class _EditPostScreenRidesState extends State<EditPostScreenRides> {
  final _pickupCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController();
  final _fareCtrl = TextEditingController();

  static const _googleApiKey = 'AIzaSyDcyTxJYf48_3WSEYGWb9sF03NiWvTqTMA';
  late final _dir = GoogleDirectionsService(_googleApiKey);
  bool _calculating = false;

  final DriverOfferRepository _repo = DriverOfferRepository();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  LatLng? _pickupLatLng;
  LatLng? _destLatLng;

  double? _distanceKm;
  double? _computedFare;

  DriverOffer? _offer;
  bool _loading = true;
  bool _saving = false;

  // =========================
  // Pricing config — must match PostRides
  // =========================
  static const double _baseFare = 2.00;
  static const double _ratePerKm = 0.80;
  static const double _minFare = 3.00;
  static const double _maxFare = 50.00;

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  double _calcFare(double km) {
    final raw = _baseFare + (_ratePerKm * km);
    final withMin = raw < _minFare ? _minFare : raw;
    final capped = withMin > _maxFare ? _maxFare : withMin;
    return double.parse(capped.toStringAsFixed(2));
  }

  Future<void> _recalcFareIfPossible() async {
    if (_pickupLatLng == null || _destLatLng == null) return;
    if (_calculating) return;

    setState(() => _calculating = true);

    try {
      final km = await _dir.getDrivingDistanceKm(
        origin: _pickupLatLng!,
        destination: _destLatLng!,
      );

      final fare = _calcFare(km);

      if (!mounted) return;
      setState(() {
        _distanceKm = km;
        _computedFare = fare;
        _fareCtrl.text = 'RM ${fare.toStringAsFixed(2)}';
      });
    } catch (e) {
      if (!mounted) return;
      _snack('Distance calculation failed');
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<void> _loadOffer() async {
    try {
      final offer = await _repo.getById(widget.offerId);
      if (offer == null) {
        _snack('Offer not found');
        if (mounted) Navigator.pop(context);
        return;
      }

      _offer = offer;

      _pickupCtrl.text = offer.pickup;
      _destinationCtrl.text = offer.destination;
      _seatsCtrl.text = offer.seatsAvailable.toString();

      // ✅ pre-fill existing fare
      _computedFare = offer.fare;
      _fareCtrl.text = 'RM ${offer.fare.toStringAsFixed(2)}';

      // ✅ pre-fill existing geo so recalc works immediately
      _pickupLatLng = LatLng(
        offer.pickupGeo.latitude,
        offer.pickupGeo.longitude,
      );
      _destLatLng = LatLng(
        offer.destinationGeo.latitude,
        offer.destinationGeo.longitude,
      );

      _selectedDate = DateTime(
        offer.rideDateTime.year,
        offer.rideDateTime.month,
        offer.rideDateTime.day,
      );
      _selectedTime = TimeOfDay(
        hour: offer.rideDateTime.hour,
        minute: offer.rideDateTime.minute,
      );

      _dateCtrl.text = _fmtDate(_selectedDate!);
      _timeCtrl.text = _fmtTime(_selectedTime!);

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack('Failed to load offer: $e');
    }
  }

  // =========================
  // Select Pickup (map)
  // =========================
  Future<void> _selectStartPoint() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSelectScreen(
          mode: LocationSelectMode.pickup,
          initialTarget: _pickupLatLng ?? const LatLng(3.2149, 101.7291),
          autoMoveToMyLocation: false,
          customMarkerTitle: 'Start',
          customButtonText: 'Set Starting Point',
          customResultKey: 'start',
          customCurrentLocationSnippet: 'My current location',
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _pickupLatLng = LatLng(
        (result['lat'] as num).toDouble(),
        (result['lng'] as num).toDouble(),
      );
      final address = (result['address'] ?? '').toString().trim();
      _pickupCtrl.text = address.isEmpty ? 'Selected location' : address;
    });

    _recalcFareIfPossible();
  }

  // =========================
  // Select Destination (map)
  // =========================
  Future<void> _selectDestination() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSelectScreen(
          mode: LocationSelectMode.dropoff,
          initialTarget: _destLatLng ?? _pickupLatLng ?? const LatLng(3.2149, 101.7291),
          autoMoveToMyLocation: false,
          customMarkerTitle: 'Destination',
          customButtonText: 'Set Destination',
          customResultKey: 'destination',
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _destLatLng = LatLng(
        (result['lat'] as num).toDouble(),
        (result['lng'] as num).toDouble(),
      );
      final address = (result['address'] ?? '').toString().trim();
      _destinationCtrl.text = address.isEmpty ? 'Selected location' : address;
    });

    _recalcFareIfPossible();
  }

  Future<void> _saveChanges() async {
    if (_offer == null) return;

    final pickup = _pickupCtrl.text.trim();
    final dest = _destinationCtrl.text.trim();

    if (pickup.isEmpty || _pickupLatLng == null) {
      return _snack('Please select starting point.');
    }
    if (dest.isEmpty || _destLatLng == null) {
      return _snack('Please select destination.');
    }
    if (_selectedDate == null) return _snack('Please select date.');
    if (_selectedTime == null) return _snack('Please select time.');

    final seats = int.tryParse(_seatsCtrl.text.trim());
    if (seats == null || seats <= 0) {
      return _snack('Seats must be a number > 0.');
    }

    if (_computedFare == null) {
      return _snack('Please select pickup & destination to calculate fare.');
    }

    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (dt.isBefore(DateTime.now())) {
      return _snack('Selected date/time is in the past.');
    }

    setState(() => _saving = true);

    try {
      final updated = _offer!.copyWith(
        pickup: pickup,
        destination: dest,
        pickupGeo: GeoPoint(_pickupLatLng!.latitude, _pickupLatLng!.longitude),
        destinationGeo: GeoPoint(_destLatLng!.latitude, _destLatLng!.longitude),
        rideDateTime: dt,
        seatsAvailable: seats,
        fare: _computedFare!,
      );

      await _repo.update(updated);

      _snack('Updated successfully!');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack('Update failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = const Color(0xFF1E73FF);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'Edit Post',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Your Ride',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Update your ride details so riders can see the latest information.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 18),

            // ✅ Pickup — tap to select on map
            TextField(
              controller: _pickupCtrl,
              readOnly: true,
              decoration: _dec(
                'Starting Point',
                Icons.location_on_outlined,
                hint: 'Tap to select starting point',
              ),
              onTap: _saving ? null : _selectStartPoint,
            ),
            const SizedBox(height: 12),

            // ✅ Destination — tap to select on map
            TextField(
              controller: _destinationCtrl,
              readOnly: true,
              decoration: _dec(
                'Destination',
                Icons.flag_outlined,
                hint: 'Tap to select destination',
              ),
              onTap: _saving ? null : _selectDestination,
            ),
            const SizedBox(height: 12),

            // Date + Time
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateCtrl,
                    readOnly: true,
                    decoration: _dec('Date', Icons.calendar_month_outlined),
                    onTap: _saving
                        ? null
                        : () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                        initialDate: _selectedDate ?? DateTime.now(),
                      );
                      if (picked != null) {
                        _selectedDate = picked;
                        _dateCtrl.text = _fmtDate(picked);
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
                    onTap: _saving
                        ? null
                        : () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? TimeOfDay.now(),
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

            // Seats
            TextField(
              controller: _seatsCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('Seats Available', Icons.event_seat_outlined),
            ),
            const SizedBox(height: 12),

            // ✅ Fare — read only, auto-calculated
            TextField(
              controller: _fareCtrl,
              readOnly: true,
              decoration: _dec(
                'Ride Fare per Person (Auto)',
                Icons.attach_money_outlined,
                hint: 'Select pickup & destination',
              ),
            ),

            if (_distanceKm != null) ...[
              const SizedBox(height: 8),
              Text(
                'Distance: ${_distanceKm!.toStringAsFixed(1)} km',
                style: const TextStyle(color: Colors.black54),
              ),
            ],

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
                      'Tip: Keep your details accurate to avoid last-minute confusion.',
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
                onPressed: _saving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B6CFF),
                ),
                child: _saving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}