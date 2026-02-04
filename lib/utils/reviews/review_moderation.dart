class ReviewModeration {
  static const badWords = <String>[
    'idiot',
    'stupid',
    'hate',
    'worst',
    'dumb',
  ];

  static bool detectSuspicious({
    required String comment,
  }) {
    final t = comment.toLowerCase().trim();

    // 1️⃣ offensive words
    for (final w in badWords) {
      if (t.contains(w)) return true;
    }

    // 2️⃣ repeated characters (xxx, yyy, zzz, hhhhh)
    final repeatRegex = RegExp(r'(.)\1{2,}');
    if (repeatRegex.hasMatch(t)) return true;

    return false;
  }
}
