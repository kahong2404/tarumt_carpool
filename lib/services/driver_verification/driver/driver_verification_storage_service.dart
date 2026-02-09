import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class DriverVerificationStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Reference _ref(String userId, String filename) {
    return _storage.ref('driver_verifications/$userId/$filename');
  }

  Future<String> uploadVehicleImage({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final filename = contentType.contains('png') ? 'vehicle.png' : 'vehicle.jpg';
    final ref = _ref(userId, filename);

    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return task.ref.getDownloadURL();
  }

  Future<String> uploadLicensePdf({
    required String userId,
    required Uint8List bytes,
  }) async {
    final ref = _ref(userId, 'license.pdf');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    return task.ref.getDownloadURL();
  }

  Future<String> uploadInsurancePdf({
    required String userId,
    required Uint8List bytes,
  }) async {
    final ref = _ref(userId, 'insurance.pdf');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    return task.ref.getDownloadURL();
  }
}
