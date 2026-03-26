import 'package:intl/intl.dart';

/// Today as 'YYYY-MM-DD' string.
String todayISO() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Format a date string for display (e.g. 'Mar 26').
String formatDateDisplay(String iso) {
  final dt = DateTime.parse(iso);
  return DateFormat('MMM d').format(dt);
}

/// Format a full date (e.g. 'Wednesday, March 26').
String formatDateFull(String iso) {
  final dt = DateTime.parse(iso);
  return DateFormat('EEEE, MMMM d').format(dt);
}

/// Format a number with up to [decimals] places, stripping trailing zeros.
String formatNum(double value, {int decimals = 1}) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(decimals);
}

/// Clamp a value between 0 and [max], returning 0 if max is 0 or null.
double safeProgress(double actual, double? goal) {
  if (goal == null || goal <= 0) return 0;
  return (actual / goal).clamp(0.0, 1.0);
}

/// ISO week range string e.g. 'Mar 24 – Mar 30'.
String weekRangeLabel(String anyDateInWeek) {
  final dt = DateTime.parse(anyDateInWeek);
  final mon = dt.subtract(Duration(days: dt.weekday - 1));
  final sun = mon.add(const Duration(days: 6));
  return '${DateFormat('MMM d').format(mon)} – ${DateFormat('MMM d').format(sun)}';
}

/// Returns the 7 ISO date strings for the week containing [anyDate].
List<String> weekDates(String anyDate) {
  final dt = DateTime.parse(anyDate);
  final mon = dt.subtract(Duration(days: dt.weekday - 1));
  return List.generate(7, (i) {
    final d = mon.add(Duration(days: i));
    return DateFormat('yyyy-MM-dd').format(d);
  });
}
