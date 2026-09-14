import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class DeepgramLiveService {
  DeepgramLiveService({required this.apiKey});

  final String apiKey;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;

  final _ctrl = StreamController<DeepgramTranscript>.broadcast();
  Stream<DeepgramTranscript> get onTranscript => _ctrl.stream;

  bool _running = false;
  bool get isRunning => _running;

  Timer? _keepAliveTimer;

  static const _keyterms = <String>[
    'ألف', 'الف', 'باء', 'با', 'بي', 'تاء', 'تا', 'ثاء', 'ثا',
    'جيم', 'جي', 'حاء', 'حا', 'خاء', 'خا', 'دال', 'دا', 'ذال', 'ذا',
    'راء', 'را', 'راس', 'زاي', 'زي', 'سين', 'سي', 'شين', 'شي',
    'صاد', 'صا', 'ضاد', 'ضا', 'طاء', 'طا', 'ظاء', 'ظا', 'عين', 'عي',
    'غين', 'غي', 'فاء', 'فا', 'قاف', 'قا', 'كاف', 'كا', 'لام', 'لا',
    'ميم', 'مي', 'نون', 'نو', 'هاء', 'ها', 'واو', 'وا', 'ياء', 'يا',
    'صفر', 'واحد', 'اتنين', 'اثنين', 'تلاتة', 'ثلاثة', 'أربعة', 'اربعة',
    'خمسة', 'ستة', 'سبعة', 'تمانية', 'ثمانية', 'تسعة',
  ];

  Future<void> start() async {
    if (_running) return;
    if (apiKey.isEmpty) throw StateError('Deepgram API key فارغ');
    if (!await _recorder.hasPermission()) {
      throw StateError('صلاحية الميكروفون مرفوضة');
    }

    final keytermQuery = _keyterms
        .map((term) => 'keyterm=${Uri.encodeQueryComponent(term)}')
        .join('&');

    final uri = Uri.parse(
      'wss://api.deepgram.com/v1/listen'
      '?model=nova-3'
      '&language=ar-EG'
      '&encoding=linear16'
      '&sample_rate=16000'
      '&channels=1'
      '&interim_results=true'
      '&endpointing=300'
      '&punctuate=false'
      '&smart_format=false'
      '&$keytermQuery',
    );

    try {
      _channel = WebSocketChannel.connect(uri, protocols: ['token', apiKey]);
      await _channel!.ready;

      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onError: (e) {
          if (!_ctrl.isClosed) _ctrl.addError(e);
        },
        onDone: _onWsDone,
        cancelOnError: false,
      );
    } catch (e) {
      _running = false;
      rethrow;
    }

    final audioStream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _audioSub = audioStream.listen((Uint8List chunk) {
      try {
        _channel?.sink.add(chunk);
      } catch (_) {}
    }, cancelOnError: false);

    _keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'KeepAlive'}));
      } catch (_) {}
    });

    _running = true;
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;

    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;

    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}

    // Ask Deepgram to flush buffered audio before closing the socket. This is
    // important for the very last plate in a recording.
    try {
      _channel?.sink.add(jsonEncode({'type': 'Finalize'}));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } catch (_) {}

    try {
      _channel?.sink.add(jsonEncode({'type': 'CloseStream'}));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    } catch (_) {}

    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _onWsMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['type'] == 'Metadata') return;
      if (data['type'] == 'SpeechStarted') return;
      if (data['type'] == 'UtteranceEnd') return;

      final channel = data['channel'] as Map<String, dynamic>?;
      final alts = channel?['alternatives'] as List<dynamic>?;
      if (alts == null || alts.isEmpty) return;

      final firstAlt = alts.first as Map<String, dynamic>;
      final text = (firstAlt['transcript'] as String? ?? '').trim();
      final isFinal = data['is_final'] as bool? ?? false;
      final speechFinal = data['speech_final'] as bool? ?? false;
      final confidence = (firstAlt['confidence'] as num?)?.toDouble();

      if (text.isEmpty) return;
      if (!_ctrl.isClosed) {
        _ctrl.add(
          DeepgramTranscript(
            text: text,
            isFinal: isFinal,
            speechFinal: speechFinal,
            confidence: confidence,
          ),
        );
      }
    } catch (_) {}
  }

  void _onWsDone() {
    _running = false;
  }

  Future<void> dispose() async {
    await stop();
    if (!_ctrl.isClosed) await _ctrl.close();
    _recorder.dispose();
  }
}

class DeepgramTranscript {
  const DeepgramTranscript({
    required this.text,
    required this.isFinal,
    this.speechFinal = false,
    this.confidence,
  });

  final String text;
  final bool isFinal;
  final bool speechFinal;
  final double? confidence;
}
