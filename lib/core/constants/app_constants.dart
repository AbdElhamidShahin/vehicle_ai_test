class AppConstants {
  AppConstants._();

  // ── API Keys ──────────────────────────────────────────────────────────────
  static const groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // مفتاح Deepgram للـ Streaming (يمكنك استبداله بمفتاحك الخاص)
  static const deepgramApiKey = String.fromEnvironment(
    'DEEPGRAM_API_KEY',
    defaultValue: 'YOUR_DEEPGRAM_API_KEY_HERE',
  );

  static const audioMimeType = 'audio/mp4';
}