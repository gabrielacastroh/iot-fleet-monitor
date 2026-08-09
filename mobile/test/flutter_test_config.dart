import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// `main.dart` initializes the `es` locale before the app ever builds, so
/// every widget that formats a date assumes it is loaded. Widget tests
/// bypass `main`, and until this ran per-file each new date-formatting call
/// site broke unrelated tests with `LocaleDataException`. Flutter picks this
/// file up automatically for every test under `test/`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting('es');
  await testMain();
}
