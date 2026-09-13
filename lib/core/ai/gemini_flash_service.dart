import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// يبعت النص العربي لـ Gemini Flash ويستخرج منه قايمة العربيات
class GeminiFlashService {
  static String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/'
          '${AppConstants.geminiModel}:generateContent'
          '?key=${AppConstants.geminiApiKey}';

  // ─── System Prompt للوحات السعودية ────────────────────────────────────────
  static const _systemInstruction = r'''
أنت نظام خبير في تحويل الكلمات الصوتية المنطوقة باللهجة المصرية (لأحرف وأرقام لوحات سيارات) إلى صيغتها النهائية الصحيحة.

═══ القاعدة الأساسية ═══
العامل ينطق اللوحة بسرعة هكذا: "ميم نون سين واحد اتنين تلاتة أربعة" أو "أيه بي سي خمسة ستة".
مهمتك هي تجميع هذه الحروف والأرقام المتفرقة وإخراجها بالشكل الصحيح:
- الحروف المنطوقة (ميم نون سين أو م ن س) تصبح رمز الحروف.
- الأرقام المنطوقة (واحد اتنين...) تصبح أرقاماً صريحة (1234).

═══ تصحيح الحروف المنطوقة بالحرف ═══
- أحرف عربية: أ (ألف)، ب (باء)، ج (جيم)، د (دال)، ر (رأ)، س (سين)، ص (صاد)، ط (طاء)، ع (عين)، ف (فاء)، ق (قاف)، ك (كاف)، ل (لام)، م (ميم)، ن (نون)، هـ (هاء)، و (واو)، ي (ياء).
- أحرف إنجليزية: إيه/أيه (A)، بي (B)، سي (C)، دي (D)، إف (F)، جي (G)، إتش (H)، كي (K)، إل (L)، إم (M)، إن (N)، آر (R)، إس (S)، تي (T)، إكس (X)، واي (Y)، زد (Z).

═══ الأرقام ═══
صفر=0, واحد=1, اتنين=2, تلاتة=3, أربعة=4, خمسة=5, ستة=6, سبعة=7, تمانية/ثمانية=8, تسعة=9.

═══ المخرجات المطلوبة ═══
أرجع JSON فقط بهذا الشكل بدقة شديدة:
{"vehicles": [{"plate_number": "م ن س 1234", "vehicle_type": "", "address": ""}]}
لو النص فارغ أو غير مف مفهوم، أرجع:
{"vehicles": []}
''';
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
        'maxOutputTokens': 1024,
        'topP': 1,
        'topK': 1,
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
        'plate_number':
        _normalizePlate(v['plate_number'] as String? ?? ''),
      })
          .where((v) => (v['plate_number'] as String).isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// ─── تنظيف اللوحة ─────────────────────────────────────────────────────────
  String _normalizePlate(String raw) {
    var result = raw.trim();

    // تحويل أرقام عربية/هندية لإنجليزية
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], '$i');
    }

    // تأكد إن الحروف الإنجليزية كبيرة دايماً
    // (Gemini أحياناً بيكتبها صغيرة)
    final parts = result.split(' ');
    if (parts.length >= 2) {
      final letters = parts.first;
      // لو الجزء الأول كله حروف لاتينية → حوّلهم uppercase
      if (RegExp(r'^[a-zA-Z]+$').hasMatch(letters)) {
        parts[0] = letters.toUpperCase();
        result = parts.join(' ');
      }
    }

    return result;
  }
}
