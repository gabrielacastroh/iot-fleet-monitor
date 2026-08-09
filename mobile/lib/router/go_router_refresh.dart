import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/session.dart';
import '../state/session_provider.dart';

/// Bridges [sessionProvider] state changes into the `Listenable` GoRouter's
/// `refreshListenable` expects (design §7) — re-evaluates `redirect` on
/// every session change (login, logout, restore, forced teardown).
class SessionRefreshListenable extends ChangeNotifier {
  SessionRefreshListenable(Ref ref) {
    final subscription = ref.listen<AsyncValue<Session?>>(
      sessionProvider,
      (_, _) => notifyListeners(),
    );
    ref.onDispose(subscription.close);
  }
}
