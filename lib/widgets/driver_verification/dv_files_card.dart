import 'package:flutter/material.dart';

class DvFilesCard extends StatelessWidget {
  final String? vehicleUrl;
  final String? licenseUrl;
  final String? insuranceUrl;
  final void Function(String url) onOpen;

  const DvFilesCard({
    super.key,
    required this.vehicleUrl,
    required this.licenseUrl,
    required this.insuranceUrl,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(String title, String? url) {
      final has = (url != null && url.trim().isNotEmpty);
      return Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: has ? () => onOpen(url!) : null,
            child: Text(has ? 'Open' : 'Not uploaded'),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Uploaded Files',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          row('Vehicle Image', vehicleUrl),
          const Divider(height: 16),
          row('License PDF', licenseUrl),
          const Divider(height: 16),
          row('Insurance PDF', insuranceUrl),
        ],
      ),
    );
  }
}
