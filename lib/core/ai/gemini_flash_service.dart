import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class GeminiFlashService {
  static String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/'
          '${AppConstants.geminiModel}:generateContent'
          '?key=${AppConstants.geminiApiKey}';

  static const _systemInstruction = r'''
أنت نظام متخصص في استخراج أرقام لوحات السيارات المصرية من نصوص منطوقة محوّلة بـ Speech-to-Text.

═══ شكل اللوحة المصرية ═══
• 3 حروف عربية + 4 أرقام
• مثال: "س ن م 1234"

═══ تحويل أسماء الحروف ═══
أ/ألف/الف → أ | ب/باء/بي → ب | ت/تاء → ت | ث/ثاء → ث | ج/جيم → ج
ح/حاء/حا → ح | خ/خاء → خ | د/دال → د | ذ/ذال → ذ | ر/راء/راس → ر
ز/زاي/زي → ز | س/سين → س | ش/شين → ش | ص/صاد/صا → ص | ض/ضاد → ض
ط/طاء → ط | ظ/ظاء → ظ | ع/عين → ع | غ/غين → غ | ف/فاء → ف
ق/قاف → ق | ك/كاف → ك | ل/لام → ل | م/ميم → م | ن/نون → ن
ه/هاء/ها → ه | و/واو → و | ي/ياء/يا → ي

═══ تحويل الأرقام ═══
صفر/زيرو→0 | واحد→1 | اتنين/اثنين/تنين→2 | تلاتة/ثلاثة/تلت→3 | أربعة/اربعة/أربع→4
خمسة/خمس→5 | ستة/ست→6 | سبعة/سبع→7 | تمانية/ثمانية/تمان→8 | تسعة/تسع→9
الأرقام العربية: ١→1 ٢→2 ٣→3 ٤→4 ٥→5 ٦→6 ٧→7 ٨→8 ٩→9 ٠→0

═══ مهم جداً — طريقة قراءة اللوحات ═══
الشخص بيقرأ لوحات متعددة متتالية. النص الواحد قد يحتوي على أكثر من لوحة.
ابحث عن كل تجمّع من (حروف + أرقام) واستخرجه كلوحة مستقلة.

مثال: "حاء واو طاء 4604 حاء ميم نون 5226 راسين واو 281"
→ ح و ط 4604 | ح م ن 5226 | ر ر و 0281

═══ تعامل مع أخطاء الـ STT ═══
الـ Speech-to-Text أحياناً بيكتب أرقام بدل حروف أو العكس:
- "4685" في أول اللوحة = أرقام مكانها حروف → حاول تفسّرها كـ "needs_review"
- حرف + رقم + حرف = خلط → اجمع أقرب تفسير
- تكرار مقطع (مثل "22 46") = قد يكون رقمين منفصلين أو عدد واحد
- الأرقام المتتالية بعد الحروف هي رقم اللوحة

═══ قواعد الاستخراج ═══
✅ استخرج: أي تجمّع واضح من حروف + أرقام (حتى لو ناقص حرف أو رقم)
⚠️ needs_review: لو الحروف أو الأرقام مش مكتملة أو فيه شك
❌ تجاهل: الكلام العادي اللي مش بيشبه لوحة خالص

• الأرقام 4 خانات (لو أكتر خذ أول 4)
• لو نفس اللوحة اتكررت، اكتبها مرة واحدة
• لا تخترع حروف أو أرقام مش موجودة في النص
• أرجع JSON فقط

═══ الشكل المطلوب ═══
{
  "vehicles": [
    {
      "plate_number": "ح و ط 4604",
      "vehicle_type": "",
      "address": "",
      "confidence": "high",
      "status": "ok"
    }
  ]
}

confidence: "high" لو واضح، "low" لو فيه شك
status: "ok" أو "needs_review"
''';

  Future<List<Map<String, dynamic>>> extractVehicles({
    required String transcript,
    String previousContext = '',
  }) async {
    if (AppConstants.geminiApiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY غير محدد');
    }
    if (transcript.trim().isEmpty) return [];
    if (transcript.trim().length < 3) return [];

    final contextNote = previousContext.isNotEmpty
        ? 'نصوص سابقة (لا تعيد استخراج ما فيها):\n"$previousContext"\n\n'
        : '';

    final userText = '${contextNote}النص الجديد للتحليل:\n"$transcript"';

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
        'maxOutputTokens': 2048,
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
          'Gemini Flash error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText =
    (json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ??
        '')
        .trim();

    if (rawText.isEmpty) return [];

    final clean = rawText.replaceAll(RegExp(r'```json|```'), '').trim();

    final decoded = jsonDecode(clean) as Map<String, dynamic>;
    final vehicles = (decoded['vehicles'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return vehicles.where((v) {
      final plate = '${v['plate_number'] ?? ''}'.trim();
      return plate.isNotEmpty && plate.length >= 4;
    }).toList();
  }
}
