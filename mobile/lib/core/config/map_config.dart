/// The OSM tile source shared by every `flutter_map` instance in the app
/// (`RouteMap`, `MapScreen`). OSM's public tile server usage policy
/// requires a real `User-Agent` — set via [osmUserAgentPackageName], the
/// app's real bundle id (`android/app/build.gradle.kts`,
/// `ios/Runner.xcodeproj`). A production deployment needs its own tile
/// source; this is not solved here (design §12/§13, see mobile/README.md).
const osmTileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const osmUserAgentPackageName = 'com.iotfleetmonitor.mobile';
