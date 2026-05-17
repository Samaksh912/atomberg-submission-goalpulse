/// Application‑level configuration.
///
/// Values that change per environment (dev / staging / prod) are injected via
/// `--dart-define` flags at build time, e.g.:
///
/// ```bash
/// flutter run -d chrome --dart-define=API_BASE_URL=https://api.goalpulse.io/v1
/// ```
class AppConfig {
  AppConfig._();

  /// Base URL for the GoalPulse REST API.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/v1',
  );

  /// Human‑readable product name.
  static const String appName = 'GoalPulse';

  /// Semantic version for the frontend build.
  static const String appVersion = '1.0.0';
}
