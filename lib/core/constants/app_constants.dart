class AppConstants {
  AppConstants._();

  // ── Deepgram — Real-time STT ──────────────────────────────────────────────
  static const deepgramApiKey = String.fromEnvironment(
    'DEEPGRAM_API_KEY',
    defaultValue: '', // ← مفتاحك هنا
  );

  // ── Gemini — استخراج البيانات من النص ────────────────────────────────────
  // ✅ حط مفتاح Gemini هنا أو مرره عن طريق --dart-define=GEMINI_API_KEY=xxx
  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '', // ← ADD YOUR GEMINI KEY HERE
  );


  static const geminiModel = 'gemini-3.5-flash-lite';

  static const audioMimeType = 'audio/mp4';
}
