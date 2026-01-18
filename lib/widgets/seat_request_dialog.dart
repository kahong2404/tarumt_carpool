import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Number of Seats'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter seats (1–4)',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
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
