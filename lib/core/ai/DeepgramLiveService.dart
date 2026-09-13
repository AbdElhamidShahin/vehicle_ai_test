import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';

class DeepgramLiveService {
  WebSocketChannel? _channel;
  final _audioRecorder = AudioRecorder();

  // Stream لعرض اللوحات المستخرجة لحظياً
  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get onTranscript => _transcriptController.stream;

  /// بدء البث الصوتي المباشر والاتصال بـ Deepgram Nova-2
  Future<void> startStreaming(String apiKey) async {
    if (apiKey.isEmpty) {
      throw StateError('DEEPGRAM_API_KEY غير محدد');
    }

    // رابط الـ WebSocket الرسمي لـ Deepgram Nova-2 مع اللغة العربية
    final url = Uri.parse(
      'wss://api.deepgram.com/v1/listen?model=nova-2&language=ar&encoding=linear16&sample_rate=16000&punctuate=true',
    );

    _channel = WebSocketChannel.connect(
      url,
      protocols: ['token', apiKey],
    );

    // الاستماع للبيانات القادمة من السيرفر
    _channel!.stream.listen(
          (message) {
        _parseTranscript(message);
      },
      onError: (error) {
        print('Deepgram WebSocket Error: $error');
      },
      onDone: () {
        print('Deepgram WebSocket Closed');
      },
    );

    // بدء التقاط الصوت من الميكروفون كـ PCM سريم
    if (await _audioRecorder.hasPermission()) {
      final audioStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      // إرسال الحزم الصوتية أول بأول للسيرفر
      audioStream.listen((data) {
        if (_channel != null) {
          _channel!.sink.add(data);
        }
      });
    }
  }

  void _parseTranscript(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final channel = data['channel'] as Map<String, dynamic>?;
      final alternatives = channel?['alternatives'] as List<dynamic>?;

      if (alternatives != null && alternatives.isNotEmpty) {
        final transcript = alternatives[0]['transcript'] as String? ?? '';
        final isFinal = data['is_final'] as bool? ?? false;

        if (transcript.isNotEmpty && isFinal) {
          _transcriptController.add(transcript.trim());
        }
      }
    } catch (_) {}
  }

  /// إيقاف البث والتسجيل
  Future<void> stopStreaming() async {
    await _audioRecorder.stop();
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    stopStreaming();
    _transcriptController.close();
  }
}