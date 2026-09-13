import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class GroqSttService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';

  // الـ prompt بيساعد Whisper يتوقع شكل الكلام قبل ما يسمعه
  static const _platePrompt =
      'تسجيل أرقام لوحات سيارات مصرية. '
      'كل لوحة: ثلاثة حروف عربية ثم أربعة أرقام. '
      'الحروف المستخدمة: أ ب ت ث ج ح خ د ذ ر ز س ش ص ض ط ظ ع غ ف ق ك ل م ن ه و ي. '
      'أمثلة: أ ب ج 1234 - ر س م 5678 - ك ل م 9012 - ه و ي 3456. '
      'العامل يقول الحروف منفصلة ثم الأرقام بسرعة.';

  Future<String> transcribe(List<int> audioBytes) async {
    if (AppConstants.groqApiKey.isEmpty) {
      throw StateError('GROQ_API_KEY غير محدد');
    }

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..headers['Authorization'] = 'Bearer ${AppConstants.groqApiKey}'
      ..fields['model']           = AppConstants.activeGroqModel
      ..fields['language']        = 'ar'
      ..fields['prompt']          = _platePrompt
      ..fields['response_format'] = 'json'
      ..fields['temperature']     = '0' // أكتر ثبات في النتائج
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'chunk.m4a',
      ));

    final streamed = await request.send().timeout(const Duration(seconds: 20));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('Groq error ${streamed.statusCode}: $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['text'] as String? ?? '').trim();
  }
}
