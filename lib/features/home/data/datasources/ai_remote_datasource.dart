import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/ai_constants.dart';

class AiRemoteDatasource {
  final http.Client _client;
  AiRemoteDatasource({http.Client? client}) : _client = client ?? http.Client();
  Future<Map<String, dynamic>> processAudio(List<int> bytes) async {
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': 'audio/mp4',
                'data': base64Encode(bytes),
              },
            },
            {'text': AiConstants.vehiclePrompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.0,
        'responseMimeType': 'application/json',
      },
    });
    final res = await _client
        .post(
          Uri.parse('${AiConstants.endpoint}?key=${AiConstants.apiKey}'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(minutes: 3));
    if (res.statusCode < 200 || res.statusCode >= 300)
      throw Exception('Gemini API error ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final c = data['candidates'] as List<dynamic>?;
    if (c == null || c.isEmpty)
      throw Exception('لم يتم استلام رد من الذكاء الاصطناعي');
    final content = c.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final raw = parts?.isNotEmpty == true
        ? parts!.first['text'] as String?
        : null;
    var clean = raw?.trim() ?? '{}';
    if (clean.startsWith('```')) {
      clean = clean
          .replaceFirst(RegExp(r'^```json?\s*'), '')
          .replaceFirst(RegExp(r'```\s*$'), '')
          .trim();
    }
    try {
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      return {
        'transcript': raw ?? '',
        'plate_number': '',
        'vehicle_type': '',
        'address': '',
      };
    }
  }

  void dispose() => _client.close();
}
