import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class GeminiFlashService {
  static String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${AppConstants.geminiModel}:generateContent'
      '?key=${AppConstants.geminiApiKey}';

  static const _systemInstruction = r'''
أنت نظام متخصص في استخراج وتصحيح أرقام لوحات السيارات المصرية من نصوص منطوقة.

═══ شكل اللوحة المصرية الصحيح ═══
• 3 حروف عربية + 4 أرقام إنجليزية
• مثال صحيح: "أ ب ج 1234"

═══ قواعد تصحيح الحروف ═══
لو الحرف مكتوب باسمه، حوّله للحرف نفسه:
ألف/اﻟﻒ→أ | باء/بي→ب | تاء→ت | ثاء→ث | جيم→ج
حاء→ح | خاء→خ | دال→د | ذال→ذ | راء→ر
زاي/زي→ز | سين→س | شين→ش | صاد→ص | ضاد→ض
طاء→ط | ظاء→ظ | عين→ع | غين→غ | فاء→ف
قاف→ق | كاف→ك | لام→ل | ميم→م | نون→ن
هاء→ه | واو→و | ياء/يا→ي

═══ قواعد تصحيح الأرقام ═══
واحد→1 | اتنين/اثنين→2 | تلاتة/ثلاثة→3 | أربعة→4
خمسة→5 | ستة→6 | سبعة→7 | تمانية/ثمانية→8 | تسعة→9
الأرقام العربية: ١→1 ٢→2 ٣→3 ٤→4 ٥→5 ٦→6 ٧→7 ٨→8 ٩→9 ٠→0

═══ قواعد التحقق ═══
✅ استخرج اللوحة لو: 3 حروف + 4 أرقام
⚠️ needs_review لو: حروف ناقصة أو أرقام ناقصة
❌ تجاهل لو: كلام عادي مش رقم لوحة

═══ قواعد مهمة ═══
• الأرقام دايماً 4 خانات (لو 6 أرقام خذ أول 4 فقط)
• لو نفس اللوحة اتكررت → اكتبها مرة واحدة
• لا تخترع معلومات
• أرجع JSON فقط

{
  "vehicles": [
    {
      "plate_number": "أ ب ج 1234",
      "vehicle_type": "",
      "address": "",
      "confidence": "high",
      "status": "ok"
    }
  ]
}
''';

  Future<List<Map<String, dynamic>>> extractVehicles({
    required String transcript,
    String previousContext = '',
  }) async {
    if (AppConstants.geminiApiKey.isEmpty) throw StateError('GEMINI_API_KEY غير محدد');
    if (transcript.trim().length < 3) return [];

    final contextNote = previousContext.isNotEmpty
        ? 'نصوص سابقة (لا تعيد استخراجها):\n"$previousContext"\n\n'
        : '';

    final body = jsonEncode({
      'system_instruction': {'parts': [{'text': _systemInstruction}]},
      'contents': [{'parts': [{'text': '${contextNote}النص:\n"$transcript"'}]}],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0,
        'maxOutputTokens': 1024,
      },
    });

    final response = await http
        .post(Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Gemini error ${response.statusCode}: ${response.body}');
    }

    final json    = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = (json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '').trim();
    if (rawText.isEmpty) return [];

    final clean   = rawText.replaceAll(RegExp(r'```json|```'), '').trim();
    final decoded = jsonDecode(clean) as Map<String, dynamic>;
    final vehicles = (decoded['vehicles'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return vehicles.where((v) {
      final plate = '${v['plate_number'] ?? ''}'.trim();
      return plate.isNotEmpty && plate.length >= 4;
    }).toList();
  }
}
