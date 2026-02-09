import 'dart:async';
import 'dart:math' as _math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class DriverPresenceService {
  DriverPresenceService({required this.onLocation});

  final void Function(LatLng latLng) onLocation;

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _location = Location();

  StreamSubscription<LocationData>? _sub;

  DateTime? _lastWriteAt;
  LatLng? _lastWritten;

  static const _minSecondsBetweenWrites = 5;
  static const _minMetersBetweenWrites = 15.0;

  Future<void> start() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final perm = await _location.requestPermission();
    if (perm != PermissionStatus.granted &&
        perm != PermissionStatus.grantedLimited) {
      return;
    }

    final serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      final enabledNow = await _location.requestService();
      if (!enabledNow) return;
    }

    await _location.changeSettings(
      interval: 1000,
      distanceFilter: 5,
    );

    // mark online
    await _db.collection('driverStatus').doc(user.uid).set({
      'driverId': user.uid,
      'isOnline': true,
      'isAvailable': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _sub = _location.onLocationChanged.listen((loc) async {
      final lat = loc.latitude;
      final lng = loc.longitude;
      if (lat == null || lng == null) return;

      final now = DateTime.now();
      final current = LatLng(lat, lng);

      onLocation(current);

      // throttle writes
      if (_lastWriteAt != null &&
          now.difference(_lastWriteAt!).inSeconds < _minSecondsBetweenWrites) {
        return;
      }

      if (_lastWritten != null) {
        final meters = _distanceMeters(_lastWritten!, current);
        if (meters < _minMetersBetweenWrites) return;
      }

      _lastWriteAt = now;
      _lastWritten = current;

      final u = _auth.currentUser;
      if (u == null) return;

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

    // mark offline (optional; for demo you can keep online)
    if (user != null) {
      await _db.collection('driverStatus').doc(user.uid).set({
        'isOnline': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // simple haversine (meters)
  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);

    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final sinDLat = (dLat / 2);
    final sinDLng = (dLng / 2);

    final h = (sinDLat * sinDLat) +
        (sinDLng * sinDLng) * (Math.cos(lat1) * Math.cos(lat2));
    final c = 2 * Math.asin(Math.sqrt(h));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * 3.141592653589793 / 180.0;
}

// Tiny Math helper to avoid importing dart:math name clash
class Math {
  static double sin(double x) => _math.sin(x);
  static double cos(double x) => _math.cos(x);
  static double asin(double x) => _math.asin(x);
  static double sqrt(double x) => _math.sqrt(x);
}
