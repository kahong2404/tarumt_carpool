import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final VoidCallback onProfileTap;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.onProfileTap,
  });

  static const brandBlue = Color(0xFF1E73FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: const BoxDecoration(
        color: brandBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withOpacity(0.9),
            backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                ? NetworkImage(photoUrl!)
                : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? const Icon(Icons.person, color: brandBlue)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: onProfileTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: brandBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Profile'),
          ),
        ],
      ),
    );
  }
}
