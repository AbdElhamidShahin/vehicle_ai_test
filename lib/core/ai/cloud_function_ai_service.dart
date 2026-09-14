import 'dart:convert';
import 'package:http/http.dart' as http;
import 'vehicle_ai_service.dart';

/// Calls our backend Cloud Function.
///
/// No Gemini/Kimi API key belongs in this class or in the Flutter app.
/// The backend decides which AI provider/model is active and always returns
/// the same normalized JSON contract.
class CloudFunctionAiService implements VehicleAiService {
  final http.Client _client;
  final Uri endpoint;

  CloudFunctionAiService({
    required this.endpoint,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> processAudio({
    required List<int> audioBytes,
    required String mimeType,
  }) async {
    if (endpoint.toString().isEmpty) {
      throw StateError('AI backend URL is not configured');
    }

    final response = await _client
        .post(
          endpoint,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'audio_base64': base64Encode(audioBytes),
            'mime_type': mimeType,
          }),
        )
        .timeout(const Duration(minutes: 3));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'AI backend error (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) {
          message = body['error'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI backend returned an invalid response');
    }

    return decoded;
  }

  @override
  void dispose() => _client.close();
}
