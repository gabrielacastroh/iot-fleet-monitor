import 'package:flutter/material.dart';

// ponytail: every range this screen ever needs is "last N days ending now"
// (mirrors rangeFromDays) — a preset segmented control covers VDET-3
// without a full calendar picker's surface for the same handful of values.

/// VDET-3's date-range input: a small "days back from now" preset
/// selector. Re-fires [onChanged] on selection, which the caller uses to
/// re-fetch the history for the new range.
class DateRangeField extends StatelessWidget {
  const DateRangeField({
    required this.selectedDays,
    required this.onChanged,
    super.key,
  });

  final int selectedDays;
  final ValueChanged<int> onChanged;

  static const presets = [7, 30, 90];

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: [
        for (final days in presets)
          ButtonSegment(value: days, label: Text('${days}d')),
      ],
      selected: {selectedDays},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
