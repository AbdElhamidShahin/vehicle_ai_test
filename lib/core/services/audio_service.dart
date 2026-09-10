import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  Future<bool> hasPermission() => _recorder.hasPermission();
  Future<String> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/vehicle_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: path,
    );
    return path;
  }

  Future<String?> stop() => _recorder.stop();
  Future<List<int>> readBytes(String path) => File(path).readAsBytes();
  Future<bool> exists(String path) => File(path).exists();
  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  Future<void> dispose() => _recorder.dispose();
}
