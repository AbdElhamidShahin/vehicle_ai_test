import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import 'vehicle_ai_service.dart';

/// Temporary AI provider used for Firebase AI Logic / Gemini testing.
///
/// This class intentionally implements the same interface as the future
/// Cloud Function provider so the rest of the Flutter app does not care
/// which AI provider is being used.
class FirebaseAiLogicVehicleAiService implements VehicleAiService {
  FirebaseAiLogicVehicleAiService({
    String model = 'gemini-3.5-flash-lite',
  }) : _model = FirebaseAI.googleAI().generativeModel(
          model: model,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: Schema.object(
              properties: {
                'success': Schema.boolean(),
                'transcript': Schema.string(),
                'plate_number': Schema.string(),
                'vehicle_type': Schema.string(),
                'address': Schema.string(),
              },
            ),
          ),
          systemInstruction: Content.system(_systemInstruction),
        );

  static const _systemInstruction = '''
أنت نظام استخراج بيانات سيارات من تسجيل صوتي باللغة العربية المصرية.

المطلوب:
1. استمع للتسجيل كاملًا.
2. اكتب النص المنطوق كما فهمته في transcript.
3. استخرج رقم اللوحة في plate_number.
4. استخرج نوع السيارة في vehicle_type.
5. استخرج المكان/العنوان الذي ذكره المستخدم في address.
6. ترتيب الكلام في التسجيل قد يكون عشوائيًا، فلا تعتمد على ترتيب ثابت.
7. لا تخترع أي معلومة غير موجودة في التسجيل.
8. إذا لم يذكر المستخدم قيمة لحقل، أرجع نصًا فارغًا لهذا الحقل.
9. حافظ قدر الإمكان على أرقام وحروف اللوحة كما نطقها المستخدم.
10. success تكون true إذا أمكن تحليل التسجيل، حتى لو كان أحد الحقول فارغًا.
11. أرجع JSON فقط طبقًا للـ schema المطلوب.

مثال:
"مرس 1234 نقل جراج 1"
=> plate_number="مرس 1234", vehicle_type="نقل", address="جراج 1"
''';

  final GenerativeModel _model;

  @override
  Future<Map<String, dynamic>> processAudio({
    required List<int> audioBytes,
    required String mimeType,
  }) async {
    final audioPart = InlineDataPart(
      mimeType,
      Uint8List.fromList(audioBytes),
    );

    final prompt = TextPart('''
حلل التسجيل الصوتي المرفق واستخرج بيانات السيارة منه.
إذا كانت هناك كلمات غير واضحة، لا تخترعها. استخدم النص الأقرب لما سمعته،
واترك الحقل فارغًا إذا لم تتمكن من استخراجه بثقة.
''');

    final response = await _model.generateContent([
      Content.multi([prompt, audioPart]),
    ]);

    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Firebase AI Logic returned an empty response.');
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('AI response is not a JSON object.');
    }

    return decoded;
  }
}
