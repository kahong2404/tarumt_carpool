import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tarumt_carpool/utils/geo_utils.dart';

class DriverLiveLocationService {
  DriverLiveLocationService(this.rideId);

  final String rideId;

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _location = Location();

  StreamSubscription<LocationData>? _sub;

  DateTime? _lastWriteAt;
  LatLng? _lastWrittenLatLng;

  static const _minSecondsBetweenWrites = 3;
  static const _minMetersBetweenWrites = 8.0;

  Future<void> start() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final perm = await _location.requestPermission();
    if (perm != PermissionStatus.granted &&
        perm != PermissionStatus.grantedLimited) {
      return;
    }

    await _location.changeSettings(
      interval: 1000,      // still receive often
      distanceFilter: 5,   // OS-level hint
    );

    _sub = _location.onLocationChanged.listen((loc) {
      final lat = loc.latitude;
      final lng = loc.longitude;
      if (lat == null || lng == null) return;

      final now = DateTime.now();
      final current = LatLng(lat, lng);

      // ⏱ time throttle
      if (_lastWriteAt != null &&
          now.difference(_lastWriteAt!).inSeconds <
              _minSecondsBetweenWrites) {
        return;
      }

      // 📏 distance throttle
      if (_lastWrittenLatLng != null) {
        final meters =
        distanceMeters(_lastWrittenLatLng!, current);
        if (meters < _minMetersBetweenWrites) {
          return;
        }
      }

      // ✅ write to Firestore
      _db.collection('rides').doc(rideId).update({
        'driverLiveLocation': GeoPoint(lat, lng),
        'driverLiveUpdatedAt': FieldValue.serverTimestamp(),
      });

      _lastWriteAt = now;
      _lastWrittenLatLng = current;
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
