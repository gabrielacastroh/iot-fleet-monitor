/// VDET-3's default history range, port of `DEFAULT_RANGE_DAYS`
/// (`frontend/src/lib/fleet.ts:69`).
const defaultRangeDays = 7;

/// A UTC date range for `GET /telemetry/{id}/history`.
class DateRange {
  const DateRange({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime endDate;
}

/// Port of `rangeFromDays` (`frontend/src/lib/fleet.ts:78-84`): a range
/// ending now, [days] back. The end is snapped UP to the next whole
/// minute so the same logical range doesn't mint a new value (and a new
/// query key) on every render; rounding up means the snap can never cut
/// off a reading that just arrived. [now] is injectable for deterministic
/// tests.
DateRange rangeFromDays(int days, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  const oneMinuteMs = 60000;
  final endMillis =
      (reference.millisecondsSinceEpoch / oneMinuteMs).ceil() * oneMinuteMs;
  final endDate = DateTime.fromMillisecondsSinceEpoch(endMillis, isUtc: true);
  final startDate = endDate.subtract(Duration(days: days));
  return DateRange(startDate: startDate, endDate: endDate);
}
