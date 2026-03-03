import 'package:flutter/material.dart';
import 'package:tarumt_carpool/widgets/primary_text_field.dart';

class SeatRequestDialog extends StatefulWidget {
  const SeatRequestDialog({super.key});

  @override
  State<SeatRequestDialog> createState() => _SeatRequestDialogState();
}

class _SeatRequestDialogState extends State<SeatRequestDialog> {
  final _controller = TextEditingController();
  String? _error;

  void _confirm() {
    final text = _controller.text.trim();
    final seats = int.tryParse(text);

    if (seats == null) {
      setState(() => _error = 'Please enter a number');
      return;
    }

    if (seats < 1 || seats > 4) {
      setState(() => _error = 'Seat must be between 1 and 4');
      return;
    }

    Navigator.pop(context, seats);
  }

  @override
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Number of Seats'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrimaryTextField(
            controller: _controller,
            label: 'Seats',
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Enter seats (1–4)',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _confirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
