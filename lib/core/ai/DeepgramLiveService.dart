import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';

class DeepgramLiveService {
  DeepgramLiveService({required this.apiKey});

  final String apiKey;

  WebSocket? _ws;
  StreamSubscription? _wsSub;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;

  final _ctrl = StreamController<DeepgramTranscript>.broadcast();
  Stream<DeepgramTranscript> get onTranscript => _ctrl.stream;

  bool _running = false;
  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    if (apiKey.isEmpty) throw StateError('Deepgram API key is empty');

    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission denied');
    }

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
      // 💡 الحل المعتمد في المنصات التي ترفض الـ Headers المخصصة:
      // تمرير المفتاح عبر الـ protocols (Sec-WebSocket-Protocol)
      _ws = await WebSocket.connect(
        uri.toString(),
        protocols: ['token', apiKey],
      );

      _wsSub = _ws!.listen(
        _onWsMessage,
        onError: (e) => _ctrl.addError(e),
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
        if (_ws != null && _ws!.readyState == WebSocket.open) {
          _ws!.add(chunk);
        }
      },
      onError: (e) => _ctrl.addError(e),
      cancelOnError: false,
    );

    _running = true;
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;

    await _audioSub?.cancel();
    _audioSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}

    try {
      if (_ws != null && _ws!.readyState == WebSocket.open) {
        _ws!.add(jsonEncode({'type': 'CloseStream'}));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } catch (_) {}

    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
  }

  void _onWsMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['type'] == 'Metadata') return;

      final channel = data['channel'] as Map<String, dynamic>?;
      final alts = channel?['alternatives'] as List<dynamic>?;
      if (alts == null || alts.isEmpty) return;

      final text = (alts[0]['transcript'] as String? ?? '').trim();
      final isFinal = data['is_final'] as bool? ?? false;

      if (text.isEmpty) return;

      _ctrl.add(DeepgramTranscript(text: text, isFinal: isFinal));
    } catch (_) {}
  }

  void _onWsDone() {
    _running = false;
  }

  Future<void> dispose() async {
    await stop();
    await _ctrl.close();
    _recorder.dispose();
  }
}

class DeepgramTranscript {
  const DeepgramTranscript({required this.text, required this.isFinal});
  final String text;
  final bool isFinal;
}