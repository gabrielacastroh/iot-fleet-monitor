import 'package:flutter/material.dart';

/// Rendered by `app.dart` while `sessionProvider` is still resolving (cold
/// start: secure storage read -> proactive expiry check -> `GET /auth/me`).
/// Router `redirect` returns `null` during this window so `/login` never
/// flashes before the session is known (design §7).
class BootstrapScreen extends StatelessWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
