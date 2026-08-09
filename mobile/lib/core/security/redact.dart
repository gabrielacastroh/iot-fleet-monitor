/// Redaction for the debug-only `LogInterceptor`. Never logged, in any
/// build: the JWT (whole or partial), passwords, the WebSocket URL's token
/// query param, and the `Authorization` header value.
final List<RegExp> _sensitivePatterns = [
  RegExp(r'(Authorization:\s*Bearer\s+)\S+', caseSensitive: false),
  RegExp(r'("password"\s*:\s*")[^"]*(")'),
  RegExp(r'(token=)[^&\s"]+'),
];

String redactSensitive(String input) {
  var output = input;
  output = output.replaceAllMapped(
    _sensitivePatterns[0],
    (m) => '${m.group(1)}[REDACTED]',
  );
  output = output.replaceAllMapped(
    _sensitivePatterns[1],
    (m) => '${m.group(1)}[REDACTED]${m.group(2)}',
  );
  output = output.replaceAllMapped(
    _sensitivePatterns[2],
    (m) => '${m.group(1)}[REDACTED]',
  );
  return output;
}
