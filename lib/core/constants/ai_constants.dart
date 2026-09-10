class AiConstants {
  AiConstants._();
  static const apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const model = 'gemini-3.5-flash-lite';
  static const endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
  static const vehiclePrompt =
      '''أنت نظام ذكاء اصطناعي متخصص في استخراج وتفريغ بيانات تسجيل السيارات من التسجيلات الصوتية باللهجة المصرية.
استمع بدقة واستخرج البيانات التالية:
1. النص المسموع كاملاً (transcript)
2. رقم اللوحة (plate_number)
3. نوع المركبة (vehicle_type) مثل: ملاكي، نقل، نص نقل، موتوسيكل، إلخ.
4. العنوان أو المكان المنطوق (address)

أجب بـ JSON فقط بهذا الشكل بدون أي نص إضافي أو Markdown:
{"transcript": "...", "plate_number": "...", "vehicle_type": "...", "address": "..."}''';
}
