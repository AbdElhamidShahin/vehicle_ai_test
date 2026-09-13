import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  RecordConfig get _config => const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 64000,
      );

  String _newPath(Directory dir) =>
      '${dir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}.m4a';

  /// بدء التسجيل — بيرجع المسار
  Future<String> start() async {
    final dir = await getTemporaryDirectory();
    final path = _newPath(dir);
    await _recorder.start(_config, path: path);
    return path;
  }

  /// [للـ Live mode] وقّف chunk الحالي وابدأ chunk جديد فوراً.
  /// بيرجع مسار الـ chunk اللي اتوقف عشان نبعته لـ Groq.
  Future<String?> rotateChunk() async {
    final finishedPath = await _recorder.stop();
    // ابدأ chunk جديد فوراً بدون انتظار
    final dir = await getTemporaryDirectory();
    final newPath = _newPath(dir);
    await _recorder.start(_config, path: newPath);
    return finishedPath;
  }

  /// وقّف التسجيل نهائياً — بيرجع مسار آخر chunk
  Future<String?> stop() => _recorder.stop();

  Future<List<int>> readBytes(String path) => File(path).readAsBytes();

  Future<bool> exists(String path) => File(path).exists();

  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  Future<void> dispose() => _recorder.dispose();
}
