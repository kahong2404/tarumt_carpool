import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class DriverPresenceService {
  DriverPresenceService({required this.onLocation});

  final void Function(LatLng latLng) onLocation;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Location _location = Location();

  StreamSubscription<LocationData>? _sub;

  DateTime? _lastEmitAt;   // ✅ last time we updated UI + wrote firestore
  LatLng? _lastEmitted;    // ✅ last location used

  // ✅ tune these
  static const int _minSecondsBetweenEmits = 5;     // UI + firestore min interval
  static const double _minMetersBetweenEmits = 15; // UI + firestore min distance

  Future<void> start() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // ✅ ensure permission (if deniedForever, request won't show again)
    final currentPerm = await _location.hasPermission();
    if (currentPerm == PermissionStatus.deniedForever) {
      // Can't show dialog again. Ask user to enable in Settings.
      return;
    }

    final perm = await _location.requestPermission();
    if (perm != PermissionStatus.granted &&
        perm != PermissionStatus.grantedLimited) {
      return;
    }

    // ✅ ensure location service ON
    final serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      final enabledNow = await _location.requestService();
      if (!enabledNow) return;
    }

    // ✅ reduce spam (better battery + smoother UI)
    await _location.changeSettings(
      interval: 3000,      // was 1000
      distanceFilter: 15,  // was 5
      accuracy: LocationAccuracy.high,
    );

    // ✅ mark online (once)
    await _db.collection('driverStatus').doc(user.uid).set({
      'driverId': user.uid,
      'isOnline': true,
      'isAvailable': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ✅ stream location
    _sub = _location.onLocationChanged.listen((loc) async {
      final lat = loc.latitude;
      final lng = loc.longitude;
      if (lat == null || lng == null) return;

      final now = DateTime.now();
      final current = LatLng(lat, lng);

      // ✅ throttle by time
      if (_lastEmitAt != null &&
          now.difference(_lastEmitAt!).inSeconds < _minSecondsBetweenEmits) {
        return;
      }

      // ✅ throttle by distance
      if (_lastEmitted != null) {
        final meters = _distanceMeters(_lastEmitted!, current);
        if (meters < _minMetersBetweenEmits) return;
      }

      _lastEmitAt = now;
      _lastEmitted = current;

      // ✅ update UI only when accepted (prevents "keep finding location")
      onLocation(current);

      final u = _auth.currentUser;
      if (u == null) return;

      // ✅ write to Firestore (same throttle rules)
      await _db.collection('driverStatus').doc(u.uid).set({
        'driverId': u.uid,
        'isOnline': true,
        'isAvailable': true,
        'currentGeo': GeoPoint(lat, lng),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> stop() async {
    final user = _auth.currentUser;

    await _sub?.cancel();
    _sub = null;

    // mark offline
    if (user != null) {
      await _db.collection('driverStatus').doc(user.uid).set({
        'isOnline': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ✅ Correct Haversine distance (meters)
  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;

    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);

    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);

    final h = (sinDLat * sinDLat) +
        (sinDLng * sinDLng) * (math.cos(lat1) * math.cos(lat2));

    final c = 2 * math.asin(math.sqrt(h));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * math.pi / 180.0;
}