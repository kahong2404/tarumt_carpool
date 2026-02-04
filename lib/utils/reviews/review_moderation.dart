class ReviewModeration {
  static const badWords = <String>[
    'xxx',
    'idiot',
    'stupid',
    'hate',
    'worst',
    'dumb',
  ];

  static ({bool suspicious, String reason}) detect({
    required int ratingScore,
    required String comment,
  }) {
    final t = comment.toLowerCase().trim();

    final hit = badWords.firstWhere(
          (w) => t.contains(w),
      orElse: () => '',
    );

    if (hit.isNotEmpty) {
      return (suspicious: true, reason: 'offensive_language');
    }

    if (ratingScore <= 1 && t.length >= 30) {
      return (suspicious: true, reason: 'extreme_negative_review');
    }

    return (suspicious: false, reason: 'clean');
  }
}
