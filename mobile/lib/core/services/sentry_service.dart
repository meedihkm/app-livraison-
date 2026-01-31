import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryService {
  static const String _dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '', // À remplir ou passer en build-arg
  );

  /// Initialise Sentry et lance l'application
  static Future<void> init(Future<void> Function() appRunner) async {
    if (_dsn.isEmpty && kReleaseMode) {
      debugPrint('⚠️ SENTRY_DSN non configuré - Le monitoring sera désactivé');
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = _dsn;
        options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
        options.enableAutoPerformanceTracing = true;
        options.attachStacktrace = true;
        
        // Environnement (dev ou prod)
        options.environment = kReleaseMode ? 'production' : 'development';
        
        // Filtrage des informations sensibles
        options.beforeSend = (SentryEvent event, Hint hint) {
          // Filtrer les événements si nécessaire
          return event;
        };
      },
      appRunner: appRunner,
    );
  }

  /// Log une erreur manuellement
  static Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    dynamic hint,
  }) async {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: hint,
    );
  }

  /// Log un message
  static Future<void> captureMessage(
    String message, {
    SentryLevel? level,
  }) async {
    await Sentry.captureMessage(
      message,
      level: level,
    );
  }

  /// Ajoute des infos contextuelles sur l'utilisateur
  static void setUser(String id, {String? email, String? username}) {
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: id,
        email: email,
        username: username,
      ));
    });
  }

  /// Efface les infos utilisateur (logout)
  static void clearUser() {
    Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }

  /// Ajoute un breadcrumb (trace de navigation ou action)
  static void addBreadcrumb({
    required String message,
    String? category,
    SentryLevel? level,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category,
      level: level,
      data: data,
    ));
  }
}
