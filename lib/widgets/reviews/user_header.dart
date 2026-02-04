import 'package:flutter/material.dart';

class UserHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const UserHeader({super.key, required this.name, required this.photoUrl});

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.black12,
          backgroundImage: (photoUrl != null && photoUrl!.trim().isNotEmpty)
              ? NetworkImage(photoUrl!.trim())
              : null,
          child: (photoUrl == null || photoUrl!.trim().isEmpty)
              ? Text(initials, style: const TextStyle(fontWeight: FontWeight.w900))
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ],
    );
  }
}
