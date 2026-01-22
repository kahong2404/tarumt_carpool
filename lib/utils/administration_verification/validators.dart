import 'app_strings.dart';

class Validators {
  static const int maxBytes = 5 * 1024 * 1024; // 5MB

  static List<String> validateForm({
    required String model,
    required String plate,
    required String color,
    required bool hasVehicleImage,
    required bool hasLicensePdf,
    required bool hasInsurancePdf,
  }) {
    final errors = <String>[];

    if (model.trim().isEmpty) errors.add(AppStrings.enterVehicleModel);
    if (plate.trim().isEmpty) errors.add(AppStrings.enterPlateNumber);
    if (color.trim().isEmpty) errors.add(AppStrings.selectColor);

    if (!hasVehicleImage) errors.add(AppStrings.uploadVehicleImage);
    if (!hasLicensePdf) errors.add(AppStrings.uploadLicensePdf);
    if (!hasInsurancePdf) errors.add(AppStrings.uploadInsurancePdf);

    return errors;
  }

  static bool isPdfName(String filename) {
    return filename.toLowerCase().endsWith('.pdf');
  }

  static String? validateFileSize(int bytes) {
    if (bytes > maxBytes) return AppStrings.fileTooLarge;
    return null;
  }
}
