import 'package:flutter/material.dart';

class ErrorText extends StatelessWidget {
  final String message;
  const ErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
