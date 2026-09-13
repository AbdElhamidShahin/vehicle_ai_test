class AppConstants {
  AppConstants._();

  // ── API Keys ───────────────────────────────────────────────────────────────
  static const groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );
  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // ── STT Models ─────────────────────────────────────────────────────────────
  static const groqModelTurbo = 'whisper-large-v3-turbo'; // $0.04/hr  ⚡
  static const groqModelLarge = 'whisper-large-v3';       // $0.111/hr 🎯 أدق للعربي
  static const activeGroqModel = groqModelLarge;          // ← Large v3 افتراضي

  // ── LLM Model ──────────────────────────────────────────────────────────────
  static const geminiModel = 'gemini-3.5-flash-lite';

  // ── Recording ──────────────────────────────────────────────────────────────
  // 4 ثواني = ~1-2 لوحة لكل chunk → استجابة أسرع
  static const chunkDurationSeconds = 4;
  static const audioMimeType = 'audio/mp4';
}
