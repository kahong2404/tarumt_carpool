import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class PdfPickerService {
  Future<Uint8List?> pickPdfBytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true, // important for upload + size check
    );

    if (result == null) return null;
    final file = result.files.single;

    // bytes must exist when withData=true
    return file.bytes;
  }

  Future<PlatformFile?> pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null) return null;
    return result.files.single;
  }
}
