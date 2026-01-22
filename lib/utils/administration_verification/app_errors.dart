import 'app_strings.dart';

class AppErrors {
  static String friendly(Object e) {
    // We keep this module errors simple (no FirebaseAuth here)
    // Driver verification errors mostly come from storage/pickers/repo.
    final msg = e.toString();

    if (msg.contains('file-too-large')) return AppStrings.fileTooLarge;
    if (msg.contains('pdf-only')) return AppStrings.pdfOnly;

    return AppStrings.genericError;
  }

  static List<String> friendlyList(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '').trim();
    if (msg.contains('\n')) {
      return msg
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [friendly(e)];
  }
}
