String formatCompactTime(int? milliseconds) {
  if (milliseconds == null) return '';
  final now = DateTime.now();
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final diff = now.difference(date);

  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[date.month - 1];
  if (date.year == now.year) {
    return '$month ${date.day}';
  }
  return '$month ${date.day}, ${date.year}';
}
