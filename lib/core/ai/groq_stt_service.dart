import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// يبعت chunk صوتي لـ Groq Whisper ويرجع النص العربي
class GroqSttService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';

  /// [audioBytes] : بايتات ملف m4a
  /// بيرجع النص العربي أو String فاضي لو مفيش كلام
  Future<String> transcribe(List<int> audioBytes) async {
    final apiKey = AppConstants.groqApiKey;
    if (apiKey.isEmpty) throw StateError('GROQ_API_KEY غير محدد');

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model']    = AppConstants.activeGroqModel
      ..fields['language'] = 'ar'
      // الـ prompt بيساعد Whisper يتوقع أرقام اللوحات المصرية
      ..fields['prompt']   =
          'أرقام لوحات سيارات مصرية، حروف عربية وأرقام. مثال: أ ب ج ١٢٣٤'
      ..fields['response_format'] = 'json'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'chunk.m4a',
      ));

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('Groq STT error ${streamed.statusCode}: $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final text = (json['text'] as String? ?? '').trim();
    return text;
  }
}
