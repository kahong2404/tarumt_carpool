import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class PickedBytes {
  final Uint8List bytes;
  final String name;
  final int sizeBytes;

  PickedBytes({
    required this.bytes,
    required this.name,
    required this.sizeBytes,
  });
}

class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  Future<PickedBytes?> pickVehicleImage({required ImageSource source}) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final size = bytes.length;

    return PickedBytes(
      bytes: bytes,
      name: file.name,
      sizeBytes: size,
    );
  }
}
