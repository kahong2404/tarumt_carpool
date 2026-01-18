import 'dart:async';
import 'package:flutter/material.dart';

class LocationSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onClear;
  final ValueChanged<String> onChangedDebounced;

  const LocationSearchBar({
    super.key,
    required this.controller,
    required this.loading,
    required this.onBack,
    required this.onClear,
    required this.onChangedDebounced,
  });

  static Timer? _debounce;

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      onChangedDebounced(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: "Search location",
                  border: InputBorder.none,
                ),
                onChanged: (text) {
                  // force parent rebuild for suffix icon by notifying parent with debounced call
                  _onChanged(text);
                },
              ),
            ),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (hasText)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClear,
              )
            else
              const Icon(Icons.search),
          ],
        ),
      ),
    );
  }
}
