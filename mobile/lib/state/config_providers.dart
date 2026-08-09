import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/config/app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.resolve());

/// PROF-1's app-version diagnostics row. A `FutureProvider` (not read
/// synchronously) because `PackageInfo.fromPlatform()` is itself async.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);
