import 'package:flutter/material.dart';

class ReviewWhiteCard extends StatelessWidget {
  final Widget child;
  const ReviewWhiteCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}

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

class StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final bool centered;
  final double size;

  const StarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.centered = true,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: List.generate(5, (i) {
        final star = i + 1;
        return IconButton(
          onPressed: () => onChanged(star),
          icon: Icon(
            star <= value ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
        );
      }),
    );
  }
}
