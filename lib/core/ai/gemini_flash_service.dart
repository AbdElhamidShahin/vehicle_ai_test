import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// يبعت النص العربي لـ Gemini Flash Lite ويستخرج منه قايمة العربيات
class GeminiFlashService {
  static String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${AppConstants.geminiModel}:generateContent'
      '?key=${AppConstants.geminiApiKey}';

  static const _systemInstruction = '''
أنت نظام استخراج بيانات مركبات من نص عربي مصري منطوق.

القواعد:
1. استخرج كل سيارة ذُكرت في النص في عنصر منفصل.
2. plate_number: رقم اللوحة كما نُطق (حروف + أرقام) — إلزامي.
3. vehicle_type: نوع السيارة إن ذُكر، وإلا أرجع نصًا فارغًا.
4. address: المكان إن ذُكر، وإلا أرجع نصًا فارغًا.
5. لا تخترع أي معلومة غير موجودة في النص.
6. لو النص لا يحتوي على أي لوحة، أرجع vehicles فارغة [].
7. أرجع JSON فقط بدون أي شرح.

مثال:
النص: "أ ب ج ١٢٣٤ تويوتا كامري... د هـ و ٥٦٧٨ نقل شارع الجيش"
الإجابة:
{
  "vehicles": [
    {"plate_number": "أ ب ج ١٢٣٤", "vehicle_type": "تويوتا كامري", "address": ""},
    {"plate_number": "د هـ و ٥٦٧٨", "vehicle_type": "نقل", "address": "شارع الجيش"}
  ]
}
''';

  /// [transcript]      : النص من Groq
  /// [previousContext] : آخر 2-3 جمل من chunks السابقة (اختياري، بيساعد على تجنب التكرار)
  Future<List<Map<String, dynamic>>> extractVehicles({
    required String transcript,
    String previousContext = '',
  }) async {
    if (AppConstants.geminiApiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY غير محدد');
    }
    if (transcript.isEmpty) return [];

    final contextNote = previousContext.isNotEmpty
        ? 'السياق السابق (لا تعيد استخراج ما استُخرج منه):\n"$previousContext"\n\n'
        : '';

    final userText = '${contextNote}النص الجديد:\n"$transcript"';

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _systemInstruction}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': userText}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0,
        'maxOutputTokens': 512,
      },
    });

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Gemini Flash error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (json['candidates']?[0]?['content']?['parts']?[0]?['text']
            as String? ??
        '').trim();

    if (text.isEmpty) return [];

    // تنظيف لو في ```json وعلامات زيادة
    final clean = text
        .replaceAll(RegExp(r'```json|```'), '')
        .trim();

    final decoded = jsonDecode(clean) as Map<String, dynamic>;
    final vehicles = decoded['vehicles'] as List<dynamic>? ?? [];
    return vehicles.cast<Map<String, dynamic>>();
  }
}
