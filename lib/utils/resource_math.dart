int applyResourceDelta({
  required int current,
  required int maximum,
  required int delta,
}) {
  final safeMaximum = maximum < 0 ? 0 : maximum;
  return (current + delta).clamp(0, safeMaximum).toInt();
}
