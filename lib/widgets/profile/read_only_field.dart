import 'package:flutter/material.dart';
import '../primary_text_field.dart';

class ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const ReadOnlyField({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: PrimaryTextField(
        controller: TextEditingController(text: value),
        label: label,
      ),
    );
  }
}
