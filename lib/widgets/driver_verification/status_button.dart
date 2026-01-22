import 'package:flutter/material.dart';

class StatusButton extends StatelessWidget {
  final String status; // not_applied | pending | approved | rejected
  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  const StatusButton({
    super.key,
    required this.status,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  static const _radius = 14.0;

  Color _bgColor() {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFF8E1); // light yellow
      case 'approved':
        return const Color(0xFFE8F5E9); // light green
      case 'rejected':
        return const Color(0xFFFFEBEE); // light red
      default:
        return const Color(0xFF1E73FF); // brand blue
    }
  }

  Color _textColor() {
    switch (status) {
      case 'pending':
        return const Color(0xFFF57F17); // yellow text
      case 'approved':
        return const Color(0xFF2E7D32); // green text
      case 'rejected':
        return const Color(0xFFC62828); // red text
      default:
        return Colors.white;
    }
  }

  Color _borderColor() {
    switch (status) {
      case 'pending':
        return const Color(0xFFF57F17).withOpacity(0.35);
      case 'approved':
        return const Color(0xFF2E7D32).withOpacity(0.35);
      case 'rejected':
        return const Color(0xFFC62828).withOpacity(0.35);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _bgColor(),
          disabledBackgroundColor: _bgColor(),
          foregroundColor: _textColor(),
          disabledForegroundColor: _textColor().withOpacity(0.65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
            side: BorderSide(color: _borderColor()),
          ),
        ),
        child: loading
            ? SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(_textColor()),
          ),
        )
            : Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: _textColor(),
          ),
        ),
      ),
    );
  }
}
