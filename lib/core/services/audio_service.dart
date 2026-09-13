import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();

  // 16kHz mono — أنسب سعر sampling لـ Whisper
  final _config = const RecordConfig(
    encoder: AudioEncoder.aacLc,
    sampleRate: 16000,
    numChannels: 1,
    bitRate: 64000,
  );

  Future<bool> hasPermission() => _recorder.hasPermission();

  String _newPath(Directory dir) =>
      '${dir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}.m4a';

  Future<String> start() async {
    final dir = await getTemporaryDirectory();
    final path = _newPath(dir);
    await _recorder.start(_config, path: path);
    return path;
  }

  /// وقّف الـ chunk الحالي وابدأ واحد جديد فوراً
  Future<String?> rotateChunk() async {
    final finished = await _recorder.stop();
    final dir = await getTemporaryDirectory();
    await _recorder.start(_config, path: _newPath(dir));
    return finished;
  }

  Future<String?> stop() => _recorder.stop();

  Future<List<int>> readBytes(String path) => File(path).readAsBytes();

  Future<void> delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> dispose() => _recorder.dispose();
}
