// import 'package:firebase_database/firebase_database.dart';
//
// /// RTDB CRUD service for DriverOffer table (based on your ERD)
// ///
// /// Structure:
// /// /DriverOffer/{offerID}
// /// /UserDriverOffer/{driverID}/{offerID} = true
// class DriverOfferRtdbService {
//   DriverOfferRtdbService({FirebaseDatabase? db})
//       : _db = (db ?? FirebaseDatabase.instance).ref();
//
//   final DatabaseReference _db;
//
//   DatabaseReference get _offerTable => _db.child('DriverOffer');
//   DatabaseReference _userOfferIndex(String driverID) =>
//       _db.child('UserDriverOffer').child(driverID);
//
//   /// CREATE (push offerID)
//   /// - availableSeats defaults to totalSeats (common behavior)
//   Future<String> createDriverOffer({
//     required String driverID,
//     required String origin,
//     required String destination,
//     required String rideDate, // e.g. "06/01/2026"
//     required String rideTime, // e.g. "3:30 PM"
//     required int totalSeats,
//     int? availableSeats,
//     String offerStatus = 'open', // open/closed/cancelled
//   }) async {
//     final newRef = _offerTable.push();
//     final offerID = newRef.key;
//     if (offerID == null) throw Exception('Failed to generate offerID');
//
//     final data = <String, dynamic>{
//       'offerID': offerID,
//       'origin': origin.trim(),
//       'destination': destination.trim(),
//       'rideDate': rideDate.trim(),
//       'rideTime': rideTime.trim(),
//       'totalSeats': totalSeats,
//       'availableSeats': availableSeats ?? totalSeats,
//       'offerStatus': offerStatus,
//       'createdAt': ServerValue.timestamp,
//       'driverID': driverID,
//     };
//
//     // Atomic update to "table" + "index"
//     final updates = <String, dynamic>{
//       'DriverOffer/$offerID': data,
//       'UserDriverOffer/$driverID/$offerID': true,
//     };
//
//     await _db.update(updates);
//     return offerID;
//   }
//
//   /// READ (single offer once)
//   Future<Map<String, dynamic>?> getDriverOfferById(String offerID) async {
//     final snap = await _offerTable.child(offerID).get();
//     if (!snap.exists) return null;
//
//     final v = snap.value;
//     if (v is Map) return Map<String, dynamic>.from(v as Map);
//     return null;
//   }
//
//   /// READ (stream all offers)
//   /// Optional filter by offerStatus (e.g. "open")
//   Stream<List<Map<String, dynamic>>> streamAllDriverOffers({String? status}) {
//     return _offerTable.onValue.map((event) {
//       final v = event.snapshot.value;
//       if (v is! Map) return <Map<String, dynamic>>[];
//
//       final list = v.values
//           .whereType<Map>()
//           .map((e) => Map<String, dynamic>.from(e))
//           .toList();
//
//       // newest first
//       list.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
//
//       if (status == null) return list;
//       return list.where((e) => (e['offerStatus'] ?? '') == status).toList();
//     });
//   }
//
//   /// READ (stream offers by driver using index)
//   Stream<List<Map<String, dynamic>>> streamOffersByDriver(String driverID) {
//     final idxRef = _userOfferIndex(driverID);
//
//     return idxRef.onValue.asyncMap((idxEvent) async {
//       final idx = idxEvent.snapshot.value;
//       if (idx is! Map) return <Map<String, dynamic>>[];
//
//       final offerIDs = idx.keys.map((k) => k.toString()).toSet();
//
//       final offersSnap = await _offerTable.get();
//       final offersVal = offersSnap.value;
//       if (offersVal is! Map) return <Map<String, dynamic>>[];
//
//       final results = <Map<String, dynamic>>[];
//       for (final entry in offersVal.entries) {
//         final id = entry.key.toString();
//         if (!offerIDs.contains(id)) continue;
//
//         final row = entry.value;
//         if (row is Map) results.add(Map<String, dynamic>.from(row));
//       }
//
//       results.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
//       return results;
//     });
//   }
//
//   /// UPDATE (partial fields)
//   /// Example:
//   /// updateDriverOffer(offerID, {'availableSeats': 2, 'offerStatus': 'open'});
//   Future<void> updateDriverOffer(String offerID, Map<String, dynamic> patch) async {
//     final safe = Map<String, dynamic>.from(patch);
//
//     // Keep fields aligned to your ERD
//     safe.remove('offerID');   // prevent changing PK
//     safe.remove('driverID');  // prevent changing FK (optional)
//
//     await _offerTable.child(offerID).update(safe);
//   }
//
//   /// DELETE
//   Future<void> deleteDriverOffer({
//     required String offerID,
//     required String driverID,
//   }) async {
//     final updates = <String, dynamic>{
//       'DriverOffer/$offerID': null,
//       'UserDriverOffer/$driverID/$offerID': null,
//     };
//     await _db.update(updates);
//   }
//
//   /// Convenience helpers for status
//   Future<void> setOfferStatus(String offerID, String status) =>
//       updateDriverOffer(offerID, {'offerStatus': status});
//
//   Future<void> decreaseAvailableSeats(String offerID, int newAvailable) =>
//       updateDriverOffer(offerID, {'availableSeats': newAvailable});
// }
