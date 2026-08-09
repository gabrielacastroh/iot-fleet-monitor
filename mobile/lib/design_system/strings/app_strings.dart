import '../../core/error/failure.dart';

/// Every user-visible string in the app lives here — the one file allowed
/// to contain Spanish literals.
class AppStrings {
  const AppStrings._();

  // Auth (mobile-auth-session spec)
  static const invalidCredentialsMessage =
      'Credenciales inválidas. Verifica tus datos e inténtalo de nuevo.';
  static const networkErrorMessage =
      'No pudimos conectar con el servidor. Inténtalo de nuevo en unos segundos.';
  static const showPasswordLabel = 'Mostrar contraseña';
  static const hidePasswordLabel = 'Ocultar contraseña';
  static const sessionExpiredMessage =
      'Tu sesión expiró. Inicia sesión de nuevo.';
  static const emailAlreadyRegisteredMessage =
      'Ese email ya está registrado.'; // mobile-authored

  // Role gating (mobile-navigation-shell spec)
  static const alertsAdminOnlyMessage = 'Alertas · solo administradores';
  static const forbiddenMessage =
      'No tienes permisos para ver esto.'; // mobile-authored

  // Alerts (mobile-alerts spec)
  static const resolveFailedMessage =
      'No pudimos resolver la alerta. Inténtalo de nuevo.'; // mobile-authored
  static const resolveRequiresConnectionMessage =
      'Necesitas conexión para resolver una alerta.';
  static const resolveAlertLabel = 'Resolver alerta'; // mobile-authored
  static const alertResolvedLabel = 'Resuelta'; // mobile-authored

  // Alerts list/detail (mobile-alerts spec, continued)
  static const alertsTitle = 'Alertas'; // mobile-authored (nav label)
  static const alertNotificationTitle =
      'Alerta de flota'; // mobile-authored, system notification title
  /// Composed by the screen reader after the destination's own "Alertas"
  /// label, so it deliberately does not repeat the word.
  static String openAlertsBadgeLabel(int count) => count == 1
      ? '1 pendiente'
      : '$count pendientes'; // mobile-authored
  static const alertsSubtitle =
      'Monitorea y gestiona las alertas de tu flota.'; // mobile-authored
  static const alertsSortLabel = 'Ordenar'; // mobile-authored
  static const alertsSortNewest = 'Más recientes'; // mobile-authored
  static const alertsSortOldest = 'Más antiguas'; // mobile-authored
  static String alertsPendingSectionTitle(int count) =>
      'Alertas pendientes ($count)'; // mobile-authored
  static const alertsResolvedSectionTitle =
      'Alertas resueltas'; // mobile-authored
  static const alertsAllSectionTitle = 'Todas las alertas'; // mobile-authored
  static const alertsTabPending = 'Pendientes'; // ported (AlertsPage.tsx)
  static const alertsTabResolved = 'Resueltas'; // ported (AlertsPage.tsx)
  static const alertsTabAll = 'Todas'; // ported (AlertsPage.tsx)
  static const alertsEmptyPendingTitle =
      'Sin alertas pendientes'; // mobile-authored
  static const alertsEmptyPendingBody =
      'No hay alertas abiertas en este momento.'; // mobile-authored
  static const alertsEmptyResolvedTitle =
      'Sin alertas resueltas'; // mobile-authored
  static const alertsEmptyResolvedBody =
      'Todavía no se resolvió ninguna alerta.'; // mobile-authored
  static const alertsEmptyAllTitle = 'Sin alertas'; // mobile-authored
  static const alertsEmptyAllBody =
      'No hay alertas registradas.'; // mobile-authored
  static const alertDetailTitle = 'Detalle de alerta'; // mobile-authored
  static const alertNotFoundTitle = 'Alerta no encontrada'; // mobile-authored
  static const alertNotFoundBody =
      'No pudimos encontrar esta alerta.'; // mobile-authored
  static const alertsViewAllLabel = 'Ver todas las alertas'; // mobile-authored

  // Vehicle detail (mobile-vehicles spec)
  static const noReadingsInRangeMessage =
      'Sin lecturas en el rango seleccionado.'; // mobile-authored
  static const neverReportedMessage =
      'Este vehículo no reportó telemetría todavía.'; // mobile-authored

  // Vehicles list (mobile-vehicles spec)
  static const vehiclesTitle = 'Vehículos'; // mobile-authored (nav label)
  static const vehiclesSubtitle =
      'Monitorea el estado de tu flota en tiempo real.'; // mobile-authored
  static String vehiclesCountLabel(int count) =>
      count == 1 ? '1 vehículo' : '$count vehículos'; // mobile-authored
  static const vehiclesSortLabel = 'Ordenar'; // mobile-authored
  static const vehiclesSortByName = 'Nombre'; // mobile-authored
  static const vehiclesSortByStatus = 'Estado'; // mobile-authored
  static const vehiclesSortByRecent = 'Actividad'; // mobile-authored
  static const vehiclesFuelLabel = 'Combustible'; // mobile-authored
  static const vehiclesSpeedLabel = 'Velocidad'; // mobile-authored
  static const vehiclesSearchHint =
      'Buscar dispositivo, vehículo o placa…'; // ported (DevicesPage.tsx)
  static const vehiclesSearchLabel =
      'Buscar dispositivos'; // ported (DevicesPage.tsx)
  static const vehiclesTabAll = 'Todos'; // ported (DevicesPage.tsx)
  static const vehiclesNoMatchesTitle = 'Sin resultados'; // ported
  static const vehiclesNoMatchesBody =
      'Ningún vehículo coincide con la búsqueda o el filtro aplicado.'; // ported
  static const vehiclesClearFiltersLabel = 'Limpiar filtros'; // ported
  static const vehiclesEmptyFleetTitle =
      'Todavía no hay dispositivos'; // ported
  static const vehiclesEmptyFleetBody =
      'No hay vehículos registrados en la flota.'; // mobile-authored (mobile has no device CRUD)

  // Vehicle detail (mobile-vehicles spec, continued)
  static const vehicleNotFoundTitle =
      'Vehículo no encontrado'; // mobile-authored
  static const vehicleNotFoundBody =
      'No encontramos este vehículo en tu flota.'; // mobile-authored
  static const vehicleAlertsEmptyBody =
      'Este vehículo no tiene alertas registradas.'; // mobile-authored
  static const alertsAdminOnlyBody =
      'Esta sección requiere una cuenta de administrador.'; // mobile-authored
  static const vehicleLastUpdateLabel =
      'Última actualización'; // mobile-authored
  static const vehicleSinceLastSignalLabel =
      'Desde última señal'; // mobile-authored
  static const vehicleTemperatureLabel = 'Temperatura'; // mobile-authored
  static const telemetrySectionTitle = 'Telemetría'; // mobile-authored
  static const activeAlertsSectionTitle = 'Alertas activas'; // mobile-authored
  static String alertsViewAllCountLabel(int count) =>
      'Ver todas ($count)'; // mobile-authored
  static String chartAverageLabel(String value) =>
      'Promedio: $value'; // mobile-authored
  static String chartMaxLabel(String value) => 'Máx: $value'; // mobile-authored
  static String chartMinLabel(String value) => 'Mín: $value'; // mobile-authored
  static const chartSpeedTitle = 'Velocidad (km/h)'; // mobile-authored
  static const chartFuelTitle = 'Combustible (%)'; // mobile-authored
  static const chartTemperatureTitle = 'Temperatura (°C)'; // mobile-authored
  static const telemetryEmptyTitle = 'Sin lecturas'; // mobile-authored
  static const routeMapTitle = 'Recorrido'; // mobile-authored
  static const routeMapEmptyBody =
      'Sin ubicaciones en el rango seleccionado.'; // mobile-authored

  // Map (mobile-map spec)
  static const mapTitle = 'Mapa'; // mobile-authored (nav label)
  static const mapEmptyTitle = 'Sin ubicaciones'; // mobile-authored
  static const mapEmptyBody =
      'Ningún vehículo reportó ubicación todavía.'; // mobile-authored
  static const mapViewDetailLabel = 'Ver vehículo'; // mobile-authored
  static const mapSearchHint =
      'Buscar vehículo, placa o dispositivo…'; // mobile-authored
  static const mapSearchLabel = 'Buscar vehículos en el mapa'; // mobile-authored
  static const mapFiltersLabel = 'Filtros'; // mobile-authored
  static const mapFiltersSheetTitle = 'Filtrar por estado'; // mobile-authored
  static const mapRecenterLabel = 'Centrar en la flota'; // mobile-authored
  static const mapZoomInLabel = 'Acercar'; // mobile-authored
  static const mapZoomOutLabel = 'Alejar'; // mobile-authored
  static const mapLocationLabel = 'Ubicación'; // mobile-authored
  static const mapSheetExpandLabel = 'Ver más datos'; // mobile-authored
  static const mapSheetCollapseLabel = 'Ver menos datos'; // mobile-authored
  static const mapSheetCloseLabel = 'Cerrar'; // mobile-authored

  /// The sheet's position line. No reverse geocoding exists in this app, so
  /// the coordinates are shown as they arrived — never a guessed city name.
  static String mapCoordinatesLabel(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  /// Semantics label for a clustered map marker (density fallback — see
  /// `marker_clustering.dart`), read instead of a per-vehicle label since
  /// the badge represents a group, not one vehicle.
  static String mapClusterSemanticsLabel(int count) =>
      '$count vehículos agrupados en esta zona. Toca para acercar.'; // mobile-authored

  // Dashboard (mobile-fleet-overview spec)
  static const dashboardTitle = 'Panel'; // mobile-authored (nav/AppBar label)
  static const dashboardSubtitle =
      'Resumen de tu flota en tiempo real'; // mobile-authored
  static const dashboardNotificationsLabel =
      'Ver alertas'; // mobile-authored, semantics label for the bell action
  static const kpiOnlineNowLabel = 'En línea ahora'; // mobile-authored
  static const seeAllLabel = 'Ver todo'; // mobile-authored
  static String seeAllCountLabel(int count) =>
      'Ver todos ($count)'; // mobile-authored
  static const dashboardEmptyFleetTitle =
      'Todavía no hay dispositivos'; // mobile-authored, mirrors vehiclesEmptyFleetTitle
  static const dashboardEmptyFleetBody =
      'No hay vehículos registrados en la flota.'; // mobile-authored, mirrors vehiclesEmptyFleetBody
  static const kpiActiveVehiclesLabel = 'Vehículos activos'; // mobile-authored
  static const kpiAverageFuelLabel = 'Combustible promedio'; // mobile-authored
  static const kpiAverageTemperatureLabel =
      'Temperatura promedio'; // mobile-authored
  static const kpiOpenAlertsLabel = 'Alertas abiertas'; // mobile-authored
  static const kpiNoDataValue = '—'; // mobile-authored, no reading yet
  static const problemVehiclesSectionTitle =
      'Vehículos con problemas'; // mobile-authored

  // Realtime (mobile-realtime-telemetry spec)
  static const liveFeedSectionTitle = 'Actividad reciente'; // mobile-authored
  static const fleetMetricsSectionTitle =
      'Métricas de la flota'; // mobile-authored
  static const liveFeedEmptyTitle = 'Sin actividad'; // mobile-authored
  static const liveFeedEmptyBody =
      'Todavía no llegó telemetría en esta sesión.'; // mobile-authored
  static const openAlertsSectionTitle =
      'Alertas recientes'; // mobile-authored, distinct from kpiOpenAlertsLabel to avoid duplicate on-screen text
  static const openAlertsEmptyBody =
      'No hay alertas abiertas.'; // mobile-authored

  // Profile (mobile-profile spec)
  static const profileTitle = 'Perfil'; // mobile-authored (nav label)
  static const profileRoleAdmin = 'Administrador'; // mobile-authored
  static const profileRoleUser = 'Usuario'; // mobile-authored
  static const profileReadOnlyMessage =
      'Tu perfil es de solo lectura. Todavía no se puede editar desde la app.'; // mobile-authored (design §13, no PATCH /auth/me)
  static const profileLogoutLabel = 'Cerrar sesión'; // mobile-authored
  static const profileDiagnosticsTitle = 'Diagnóstico'; // mobile-authored
  static const profileConnectionOnline = 'Conectado'; // mobile-authored
  static const profileConnectionOffline = 'Sin conexión'; // mobile-authored
  static const profileServerLabel = 'Servidor'; // mobile-authored
  static const profileSubtitle =
      'Gestiona tu cuenta y preferencias.'; // mobile-authored
  static const profilePermissionsLabel = 'Permisos'; // mobile-authored
  static const profileReadOnlyTitle = 'Solo lectura'; // mobile-authored
  static const profileConnectionLabel =
      'Estado de conexión'; // mobile-authored
  // WS connection state (distinct signal from device connectivity above —
  // see diagnostics_card.dart's two rows).
  static const profileWsConnectionLabel =
      'Conexión en tiempo real'; // mobile-authored
  static const profileWsConnectionOpen = 'Conectado'; // mobile-authored
  static const profileWsConnectionConnecting =
      'Conectando…'; // mobile-authored
  static const profileWsConnectionReconnecting =
      'Reconectando…'; // mobile-authored
  // Deliberately not "Sin conexión" (same wording as profileConnectionOffline
  // above) — the two rows measure different things, and identical text on
  // both would read as a duplicate, not a second signal.
  static const profileWsConnectionClosed = 'Desconectado'; // mobile-authored
  static const profileVersionLabel = 'Versión de la app'; // mobile-authored
  static const profileCopyServerLabel =
      'Copiar dirección del servidor'; // mobile-authored
  static const profileServerCopiedMessage =
      'Dirección del servidor copiada.'; // mobile-authored
  static const profileDiagnosticsExpandLabel =
      'Mostrar diagnóstico'; // mobile-authored
  static const profileDiagnosticsCollapseLabel =
      'Ocultar diagnóstico'; // mobile-authored
  static const profileAdminBadgeLabel =
      'Cuenta con permisos de administrador'; // mobile-authored

  /// PROF-1's app version diagnostics row: "Versión 1.0.0 (3)".
  static String profileAppVersion(String version, String buildNumber) =>
      'Versión $version ($buildNumber)';

  // Responsive two-pane (mobile-design-system spec, RESP-1)
  static const vehiclesSelectPromptTitle =
      'Elige un vehículo'; // mobile-authored
  static const vehiclesSelectPromptBody =
      'Selecciona un vehículo de la lista para ver su detalle.'; // mobile-authored
  static const alertsSelectPromptTitle = 'Elige una alerta'; // mobile-authored
  static const alertsSelectPromptBody =
      'Selecciona una alerta de la lista para ver su detalle.'; // mobile-authored

  // Offline (mobile-offline-cache spec)
  static const offlineBadgeMessage = 'Sin conexión';
  static const offlineNoCacheMessage =
      'Sin conexión y sin datos guardados.'; // mobile-authored

  /// OFF-4: "Sin conexión · datos de hace {timeAgo}"
  static String stalenessMessage(String timeAgo) =>
      'Sin conexión · datos de hace $timeAgo';

  // Generic failure copy (design §3.3) — used when there is no server detail
  // to prefer, or for failure kinds whose detail is not user-facing.
  static const serverErrorMessage =
      'El servidor no responde. Inténtalo en unos segundos.';
  static const unknownErrorMessage =
      'Algo salió mal. Inténtalo de nuevo.'; // mobile-authored
  static const notFoundMessage =
      'No encontramos lo que buscabas.'; // mobile-authored

  /// Presentation never string-matches a [Failure]; this is the single
  /// place a [Failure] becomes Spanish copy. Prefers the server's `detail`
  /// for [ConflictFailure]/[ValidationFailure] (already Spanish, meaningful
  /// to the user); every other kind uses canned copy.
  static String failureMessage(Failure failure) {
    return switch (failure) {
      ConflictFailure(:final detail) => detail ?? emailAlreadyRegisteredMessage,
      ValidationFailure(:final detail) =>
        detail ?? 'Revisa los datos ingresados.',
      NetworkFailure() => networkErrorMessage,
      ServerFailure() => serverErrorMessage,
      UnauthorizedFailure() => sessionExpiredMessage,
      ForbiddenFailure() => forbiddenMessage,
      NotFoundFailure() => notFoundMessage,
      UnknownFailure() => unknownErrorMessage,
    };
  }
}
