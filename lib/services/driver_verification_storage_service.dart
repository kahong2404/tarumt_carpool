import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class DriverVerificationStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Reference _ref(String staffId, String filename) {
    return _storage.ref('driver_verifications/$staffId/$filename');
  }

  Future<String> uploadVehicleImage({
    required String staffId,
    required Uint8List bytes,
  }) async {
    final ref = _ref(staffId, 'vehicle.jpg');

    final task = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=3600',
      ),
    );

    return task.ref.getDownloadURL();
  }

  Future<String> uploadLicensePdf({
    required String staffId,
    required Uint8List bytes,
  }) async {
    final ref = _ref(staffId, 'license.pdf');

    final task = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        cacheControl: 'public,max-age=3600',
      ),
    );

    return task.ref.getDownloadURL();
  }

  Future<String> uploadInsurancePdf({
    required String staffId,
    required Uint8List bytes,
  }) async {
    final ref = _ref(staffId, 'insurance.pdf');

    final task = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        cacheControl: 'public,max-age=3600',
      ),
    );

    return task.ref.getDownloadURL();
  }
}
