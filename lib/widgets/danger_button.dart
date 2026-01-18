import 'package:flutter/material.dart';

class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  const DangerButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  static const Color _dangerRed = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _dangerRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _dangerRed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
