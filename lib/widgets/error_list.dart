import 'package:flutter/material.dart';
import 'error_text.dart';

class ErrorList extends StatelessWidget {
  final List<String> errors;
  const ErrorList(this.errors, {super.key});

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();

    final message = errors.map((e) => '• $e').join('\n');
    return ErrorText(message);
  }
}
