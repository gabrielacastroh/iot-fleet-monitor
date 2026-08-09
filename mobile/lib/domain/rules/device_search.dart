import '../models/device.dart';

/// VEH-2 / MAP-4: case- and accent-insensitive substring search over a
/// device's name, `device_code` and plate — the one matching rule the
/// vehicles list and the map both apply, so a query can never mean two
/// different things depending on which screen typed it.
///
/// [query] is taken raw from the field; trimming, lowercasing and folding
/// happen here. An empty query matches everything.
bool deviceMatchesQuery(Device device, String query) {
  final term = foldDiacritics(query.trim().toLowerCase());
  if (term.isEmpty) return true;

  return [
    device.vehicleName,
    device.deviceCode,
    device.plate,
  ].any((field) => foldDiacritics(field.toLowerCase()).contains(term));
}

/// VEH-2's pinned scenario ("camion" matching "Camión 12") needs more than
/// case-insensitivity — Spanish vehicle names commonly carry accents a
/// field search shouldn't require the user to type.
const _diacriticFolds = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
};

String foldDiacritics(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticFolds[char] ?? char);
  }
  return buffer.toString();
}
