class RatingSummary {
  final double avg;
  final int count;
  final Map<int, int> breakdown; // 1..5

  const RatingSummary({
    required this.avg,
    required this.count,
    required this.breakdown,
  });
}

class RatingSummaryService {
  RatingSummary build(List<int> stars) {
    final breakdown = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    if (stars.isEmpty) {
      return const RatingSummary(avg: 0, count: 0, breakdown: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0});
    }

    var sum = 0;
    for (final s in stars) {
      final v = s.clamp(1, 5);
      breakdown[v] = (breakdown[v] ?? 0) + 1;
      sum += v;
    }

    final avg = sum / stars.length;
    return RatingSummary(avg: avg, count: stars.length, breakdown: breakdown);
  }
}
