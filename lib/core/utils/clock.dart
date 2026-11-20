import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injectable "now" so date-based features (daily challenge, streak) can be
/// tested at any date. Production uses the device's local time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Local calendar day as `yyyy-mm-dd` (the key daily data is stored under).
String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// Whole days between two local calendar days (b − a), ignoring the time
/// of day and daylight-saving shifts.
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Parses a [dayKey] back into a date (null if malformed).
DateTime? parseDayKey(String? key) {
  if (key == null) return null;
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Time left until the next local midnight.
Duration untilMidnight(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1).difference(now);
