import 'package:flutter/material.dart';

class EditableAvatar extends StatelessWidget {
  final String photoUrl;
  final bool uploading;
  final VoidCallback onTap;

  const EditableAvatar({
    super.key,
    required this.photoUrl,
    required this.uploading,
    required this.onTap,
  });

  static const brandBlue = Color(0xFF1E73FF);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        InkWell(
          onTap: uploading ? null : onTap,
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? const Icon(Icons.person, size: 34, color: brandBlue)
                : null,
          ),
        ),

        if (uploading)
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        Positioned(
          right: 0,
          bottom: 0,
          child: InkWell(
            onTap: uploading ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: brandBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.edit, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
