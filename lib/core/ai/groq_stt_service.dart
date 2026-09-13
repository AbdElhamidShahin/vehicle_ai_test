import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class GeminiAudioService {
  static String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/'
          '${AppConstants.geminiModel}:generateContent'
          '?key=${AppConstants.geminiApiKey}';

  static const _systemInstruction = r'''
أنت نظام خبير ومقيد بقواعد صارمة جداً لاستخراج أرقام لوحات السيارات المصرية من الصوت.

⚠️ شرط أساسي لا يُستثنى منه نهائياً:
يجب أن تتكون اللوحة المستخرجة بالكامل من:
- بالضبط **3 حروف** (سواء عربية أو إنجليزية).
- وراءها مباشرة **4 أرقام صحيحة**.

لو اللوحة غير مكتملة (أقل من 3 حروف أو أقل/أكثر من 4 أرقام)، أو الصوت مش واخد اللوحة كاملة، أرجِع فوراً قائمة فارغة ولا تألف أي أرقام من عندك:
{"vehicles": []}

الصيغة الصحيحة المطلوبة:
{"vehicles": [{"plate_number": "ر ب ج 183", "vehicle_type": "", "address": ""}]}
''';
  Future<List<Map<String, dynamic>>> extractVehiclesFromAudio({
    required List<int> audioBytes,
    String previousContext = '',
  }) async {
    if (AppConstants.geminiApiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY غيرحدد');
    }
    if (audioBytes.isEmpty) return [];

    final base64Audio = base64Encode(audioBytes);

    final contextNote = previousContext.isNotEmpty
        ? 'السياق الصوتي السابق للتسجيلات القريبة:\n"$previousContext"\n\n'
        : '';

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _systemInstruction}
        ]
      },
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': 'audio/mp4',
                'data': base64Audio,
              }
            },
            {
              'text': '${contextNote}قم بتحويل هذا الصوت الصادر من العامل إلى لوحة سيارة مصرية صحيحة بدقة مطلقة.'
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.0,
        'maxOutputTokens': 1024,
      },
    });

    final response = await http
        .post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json'},
      body: body,
    )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini Audio error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text =
    (json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ??
        '')
        .trim();

    if (text.isEmpty) return [];

    final clean = text.replaceAll(RegExp(r'```json|```'), '').trim();

    try {
      final decoded = jsonDecode(clean) as Map<String, dynamic>;
      final vehicles = decoded['vehicles'] as List<dynamic>? ?? [];

      return vehicles
          .cast<Map<String, dynamic>>()
          .map((v) => {
        ...v,
        'plate_number': _normalizePlate(v['plate_number'] as String? ?? ''),
      })
          .where((v) => (v['plate_number'] as String).isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _normalizePlate(String raw) {
    var result = raw.trim();
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], '$i');
    }
    return result;
  }/// دالة تحقق صارمة: تضمن أن اللوحة تتكون من 3 حروف و 4 أرقام فقط
  String _normalizeAndValidatePlate(String raw) {
    var result = raw.trim();

    // تحويل الأرقام العربية لهندية/إنجليزية
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], '$i');
    }

    // RegEx يفحص الشكل: (3 حروف أو رموز عربية/إنجليزية يعقبها مسافة و 4 أرقام صريحة)
    // مثال مطابق: "ABC 1234" أو "أ ب ج 7851"
    final plateRegex = RegExp(r'^([أ-يA-Za-z\s]{2,8})\s+(\d{4})$');

    // تنظيف المسافات الزائدة
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    if (plateRegex.hasMatch(result)) {
      // لوطابقت الشرط (3 حروف و 4 أرقام تماماً)
      final parts = result.split(' ');
      if (parts.isNotEmpty && RegExp(r'^[a-zA-Z]+$').hasMatch(parts.first)) {
        // لو إنجليزي نخلي الحروف الكبيرة Capital
        parts[0] = parts.first.toUpperCase();
        result = parts.join(' ');
      }
      return result;
    }

    // لو مش مطابقة للشرط (ناقصة أو زايدة) → نرفضها فوراً وترجع فاضية
    return '';
  }
}