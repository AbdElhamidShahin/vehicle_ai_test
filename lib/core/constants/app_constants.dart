class AppConstants {
  AppConstants._();

  // ── API Keys ──────────────────────────────────────────────────────────────
  // Pass via: flutter run --dart-define=GROQ_API_KEY=gsk_xxx --dart-define=GEMINI_API_KEY=AIza_xxx

  static const groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // ── Models ────────────────────────────────────────────────────────────────
  // STT: Groq Whisper — اختار turbo أو large-v3 للتجربة
  static const groqModelTurbo   = 'whisper-large-v3-turbo'; // $0.04/hr  ⚡
  static const groqModelLarge   = 'whisper-large-v3';       // $0.111/hr 🎯
  static const activeGroqModel  = groqModelLarge;           // ← غيّر هنا للتجربة

  // Extraction: Gemini Flash Lite
  static const geminiModel = 'gemini-3.5-flash-lite';

  // ── Recording ─────────────────────────────────────────────────────────────
  // كل كام ثانية نبعت chunk لـ Groq (الأقل = أسرع في الظهور، الأكثر = أدق)
  static const chunkDurationSeconds = 6;

  static const audioMimeType = 'audio/mp4';
}
