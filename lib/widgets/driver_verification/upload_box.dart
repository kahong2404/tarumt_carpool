import 'package:flutter/material.dart';

class UploadBox extends StatelessWidget {
  final String title;

  /// What to show when not uploaded yet (e.g. "PDF only (max 5MB)")
  final String hint;

  /// Selected filename (e.g. "license.pdf") - optional
  final String? fileName;

  /// Uploaded URL (download URL). If exists, we show clickable filename + Open button.
  final String? fileUrl;

  /// If true and fileUrl exists, show a small thumbnail preview (image only).
  final bool showImagePreview;

  /// If true, show a PDF icon badge (for PDFs)
  final bool showPdfIcon;

  /// selected = already uploaded (has URL)
  final bool selected;

  /// if uploading, disable select/open + show "Uploading..."
  final bool uploading;

  final VoidCallback onPick;

  /// Usually: () => _openUrl(fileUrl!)
  final VoidCallback? onOpen;

  const UploadBox({
    super.key,
    required this.title,
    required this.hint,
    required this.selected,
    required this.uploading,
    required this.onPick,
    this.fileName,
    this.fileUrl,
    this.onOpen,
    this.showImagePreview = false,
    this.showPdfIcon = false,
  });

  static const brandBlue = Color(0xFF1E73FF);

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? brandBlue : Colors.black12;

    final bool hasUrl = (fileUrl != null && fileUrl!.trim().isNotEmpty);
    final bool canOpen = hasUrl && onOpen != null && !uploading;

    Widget _pdfBadge() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE), // light red
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFC62828).withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.picture_as_pdf_outlined, size: 16, color: Color(0xFFC62828)),
            SizedBox(width: 4),
            Text(
              'PDF',
              style: TextStyle(
                color: Color(0xFFC62828),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    Widget subtitleWidget() {
      if (uploading) {
        return Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Uploading...', style: TextStyle(color: Colors.black54)),
          ],
        );
      }

      if (hasUrl) {
        final display = (fileName != null && fileName!.trim().isNotEmpty)
            ? fileName!.trim()
            : 'Open file';

        return Row(
          children: [
            if (showPdfIcon) ...[
              _pdfBadge(),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: InkWell(
                onTap: canOpen ? onOpen : null,
                child: Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: canOpen ? brandBlue : Colors.black54,
                    decoration:
                    canOpen ? TextDecoration.underline : TextDecoration.none,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      // not uploaded yet
      return Row(
        children: [
          if (showPdfIcon) ...[
            _pdfBadge(),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(hint, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      );
    }

    Widget? previewRow() {
      if (!showImagePreview) return null;
      if (!hasUrl) return null;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: canOpen ? onOpen : null,
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 96,
                height: 72,
                color: const Color(0xFFF2F2F2),
                child: Image.network(
                  fileUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) {
                    return const Center(
                      child: Icon(Icons.broken_image_outlined, size: 30),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preview',
                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: canOpen ? onOpen : null,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View full image'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    foregroundColor: brandBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final preview = previewRow();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          subtitleWidget(),

          if (preview != null) ...[
            const SizedBox(height: 12),
            preview,
          ],

          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: uploading ? null : onPick,
                child: Text(hasUrl ? 'Replace' : 'Select'),
              ),
              if (hasUrl)
                TextButton(
                  onPressed: canOpen ? onOpen : null,
                  child: const Text('Open'),
                ),
              const Spacer(),
              if (uploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  hasUrl ? Icons.check_circle : Icons.upload_file,
                  color: hasUrl ? brandBlue : Colors.black45,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
