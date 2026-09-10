class AppConstants {
  AppConstants._();

  /// Set this later when the Firebase Cloud Function is deployed:
  /// flutter run --dart-define=AI_FUNCTION_URL=https://...
  static const aiFunctionUrl = String.fromEnvironment(
    'AI_FUNCTION_URL',
    defaultValue: '',
  );

  static const audioMimeType = 'audio/mp4';
}
