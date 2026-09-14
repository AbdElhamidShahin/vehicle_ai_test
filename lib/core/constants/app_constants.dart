class AppConstants {
  AppConstants._();

  // ── Gemini API Key (الوحيد المتبقي) ──────────────────────────────────────
  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // ── Gemini Model ──────────────────────────────────────────────────────────
  static const geminiModel = 'gemini-3.5-flash-lite';

  // ── Whisper.cpp Models ────────────────────────────────────────────────────
  // small  → 466MB  — موصى بيه للبداية (سريع + دقة كويسة)
  // medium → 1.5GB  — أدق للعربي لو الجهاز قوي
  static const whisperModelUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin';
  static const whisperModelName = 'ggml-small.bin';
  static const whisperModelSizeMB = 466;

  // VAD Model (صغير ~10MB — بيكشف الصوت البشري تلقائياً)
  static const vadModelUrl =
      'https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v6.2.0.bin';
  static const vadModelName = 'ggml-silero-v6.2.0.bin';

  // Whisper prompt — أمثلة بنفس نمط كلام العامل
  static const whisperPrompt =
      'أ ب ج 1234. ر س م 5678. ك ل م 9012. ه و ي 3456. ط ن ب 8745.';
}
