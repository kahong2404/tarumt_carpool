import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/driver_offer.dart';

class DriverOfferRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DriverOfferRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('driver_offers');

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    return uid;
  }

  // ------------------------
  // CREATE (returns created offerId)
  // ------------------------
  Future<String> create(DriverOffer offer) async {
    final uid = _requireUid();

    // ensure owner is current user
    final fixedOffer = offer.copyWith(driverId: uid);

    final docRef = await _col.add(fixedOffer.toMapForCreate());
    await docRef.update({'offerId': docRef.id}); // optional
    return docRef.id;
  }

  // ------------------------
  // READ: stream open offers
  // ------------------------
  Stream<List<DriverOffer>> streamOpenOffers() {
    return _col
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DriverOffer.fromDoc).toList());
  }

  // READ: stream current user's offers
  Stream<List<DriverOffer>> streamMine() {
    final uid = _requireUid();
    return _col
        .where('driverId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DriverOffer.fromDoc).toList());
  }

  // READ: get one by id (once)
  Future<DriverOffer?> getById(String offerId) async {
    final doc = await _col.doc(offerId).get();
    if (!doc.exists) return null;
    return DriverOffer.fromDoc(doc);
  }

  // ------------------------
  // UPDATE (full update using DriverOffer object)
  // ------------------------
  Future<void> update(DriverOffer offer) async {
    final uid = _requireUid();
    final id = offer.offerId;
    if (id == null || id.isEmpty) throw Exception('offerId is required to update');

    // Ownership check
    final existing = await _col.doc(id).get();
    if (!existing.exists) throw Exception('Offer not found');
    final data = existing.data();
    if (data == null || data['driverId'] != uid) {
      throw Exception('Not allowed: you are not the owner of this offer');
    }

    await _col.doc(id).update(offer.toMapForUpdate());
  }

  // ------------------------
  // PATCH UPDATE (only update some fields)
  // ------------------------
  Future<void> patch(
      String offerId, {
        String? pickup,
        String? destination,
        DateTime? rideDateTime,
        int? seatsAvailable,
        double? fare,
        DriverOfferStatus? status,
      }) async {
    final uid = _requireUid();

    final existing = await _col.doc(offerId).get();
    if (!existing.exists) throw Exception('Offer not found');
    final data = existing.data();
    if (data == null || data['driverId'] != uid) {
      throw Exception('Not allowed: you are not the owner of this offer');
    }

    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (pickup != null) updates['pickup'] = pickup.trim();
    if (destination != null) updates['destination'] = destination.trim();
    if (rideDateTime != null) updates['rideDateTime'] = Timestamp.fromDate(rideDateTime);
    if (seatsAvailable != null) updates['seatsAvailable'] = seatsAvailable;
    if (fare != null) updates['fare'] = fare;
    if (status != null) updates['status'] = statusToString(status);

    await _col.doc(offerId).update(updates);
  }

  // ------------------------
  // DELETE
  // ------------------------
  Future<void> delete(String offerId) async {
    final uid = _requireUid();

    final doc = await _col.doc(offerId).get();
    if (!doc.exists) return;
    final data = doc.data();
    if (data == null || data['driverId'] != uid) {
      throw Exception('Not allowed: you are not the owner of this offer');
    }

    await _col.doc(offerId).delete();
  }

  // Optional: Soft delete
  Future<void> cancel(String offerId) async {
    await patch(offerId, status: DriverOfferStatus.cancelled);
  }
}
