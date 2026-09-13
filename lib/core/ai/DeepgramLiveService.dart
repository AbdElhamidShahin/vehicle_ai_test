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

  Future<void> start() async {
    if (_running) return;
    if (apiKey.isEmpty) throw StateError('Deepgram API key فارغ');
    if (!await _recorder.hasPermission()) {
      throw StateError('صلاحية الميكروفون مرفوضة');
    }

    // ✅ web_socket_channel بيتعامل مع wss:// صح على Android
    // بنبني الـ URI بـ Uri.parse على string ثابتة — مش Uri() constructor
    final uri = Uri.parse(
      'wss://api.deepgram.com/v1/listen'
          '?model=nova-2'
          '&language=ar'
          '&encoding=linear16'
          '&sample_rate=16000'
          '&channels=1'
          '&interim_results=true'
          '&endpointing=300'
          '&punctuate=false',
    );

    try {
      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['token', apiKey],
      );

      await _channel!.ready;

      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onError: (e) { if (!_ctrl.isClosed) _ctrl.addError(e); },
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

    _audioSub = audioStream.listen(
          (Uint8List chunk) {
        try { _channel?.sink.add(chunk); } catch (_) {}
      },
      cancelOnError: false,
    );

    _keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      try { _channel?.sink.add(jsonEncode({'type': 'KeepAlive'})); } catch (_) {}
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
    try { await _recorder.stop(); } catch (_) {}

    try {
      _channel?.sink.add(jsonEncode({'type': 'CloseStream'}));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } catch (_) {}

    await _wsSub?.cancel();
    _wsSub = null;
    try { await _channel?.sink.close(); } catch (_) {}
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

      final text = (alts[0]['transcript'] as String? ?? '').trim();
      final isFinal = data['is_final'] as bool? ?? false;
      final speechFinal = data['speech_final'] as bool? ?? false;

      if (text.isEmpty) return;
      if (!_ctrl.isClosed) {
        _ctrl.add(DeepgramTranscript(
          text: text,
          isFinal: isFinal,
          speechFinal: speechFinal,
        ));
      }
    } catch (_) {}
  }

  void _onWsDone() { _running = false; }

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
  });
  final String text;
  final bool isFinal;
  final bool speechFinal;
}