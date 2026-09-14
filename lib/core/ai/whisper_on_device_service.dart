import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';
import '../constants/app_constants.dart';

/// حالات الـ service
enum WhisperState {
  idle,         // جاهز
  downloading,  // بيحمّل الموديل
  loading,      // بيحمّل الموديل في الذاكرة
  ready,        // جاهز للتسجيل
  listening,    // بيسمع ويحوّل
  error,        // حصل خطأ
}

class WhisperOnDeviceService {
  final _modelManager = WhisperModelManager();
  final _recorder     = WhisperRecorder();

  WhisperEngine?   _engine;
  WhisperStreamTask? _streamTask;
  StreamSubscription<WhisperStreamUpdate>? _streamSub;

  WhisperState state = WhisperState.idle;
  double downloadProgress = 0;
  String? errorMessage;

  // ── Callbacks ─────────────────────────────────────────────────────────────
  void Function(String text)? onPartialResult;  // نص مؤقت أثناء الكلام
  void Function(String text)? onFinalResult;    // نص نهائي بعد وقفة
  void Function(WhisperState)? onStateChanged;

  // ── Paths ─────────────────────────────────────────────────────────────────
  Future<String> get _modelPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${AppConstants.whisperModelName}';
  }

  Future<String> get _vadModelPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${AppConstants.vadModelName}';
  }

  // ── Model Check ───────────────────────────────────────────────────────────
  Future<bool> isModelDownloaded() async {
    final path = await _modelPath;
    return File(path).exists();
  }

  Future<bool> isVadModelDownloaded() async {
    final path = await _vadModelPath;
    return File(path).exists();
  }

  // ── Custom Stream Downloader (Using http package) ──────────────────────────
  Future<void> _downloadFile(
      String url,
      String destinationPath,
      void Function(double progress) onProgress,
      ) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;

    final file = File(destinationPath);
    final sink = file.openWrite();

    await for (final chunk in response.stream) {
      receivedBytes += chunk.length;
      sink.add(chunk);
      if (totalBytes > 0) {
        onProgress(receivedBytes / totalBytes);
      } else {
        onProgress(0.0);
      }
    }

    await sink.flush();
    await sink.close();
  }

  // ── Download ──────────────────────────────────────────────────────────────
  Future<void> downloadModels({
    void Function(double progress, String label)? onProgress,
  }) async {
    _setState(WhisperState.downloading);

    try {
      // 1. Whisper model (~466MB)
      if (!await isModelDownloaded()) {
        final dest = await _modelPath;
        await _downloadFile(AppConstants.whisperModelUrl, dest, (progress) {
          downloadProgress = progress;
          onProgress?.call(
            downloadProgress,
            'Whisper small (${AppConstants.whisperModelSizeMB}MB)',
          );
        });
      }

      // 2. VAD model (~10MB)
      if (!await isVadModelDownloaded()) {
        final dest = await _vadModelPath;
        await _downloadFile(AppConstants.vadModelUrl, dest, (progress) {
          downloadProgress = progress;
          onProgress?.call(downloadProgress, 'VAD model (10MB)');
        });
      }

      await _loadEngine();
    } catch (e) {
      errorMessage = 'فشل التحميل: $e';
      _setState(WhisperState.error);
      rethrow;
    }
  }

  // ── Load Engine ───────────────────────────────────────────────────────────
  Future<void> _loadEngine() async {
    _setState(WhisperState.loading);
    final path = await _modelPath;
    _engine = await WhisperEngine.load(path);
    _setState(WhisperState.ready);
  }

  Future<void> initialize() async {
    if (await isModelDownloaded() && await isVadModelDownloaded()) {
      await _loadEngine();
    }
    // لو مش محمّل → UI هيطلب التحميل
  }

  // ── Start Live Transcription ───────────────────────────────────────────────
  Future<void> startListening() async {
    if (_engine == null || state != WhisperState.ready) return;

    final vadPath = await _vadModelPath;

    _streamTask = await _engine!.transcribeMicrophone(
      options: TranscribeOptions(
        language: 'ar',
        initialPrompt: AppConstants.whisperPrompt,
        enableVad: true,
        vadModelPath: vadPath,
        temperature: 0,
      ),
    );

    _streamSub = _streamTask!.updates.listen((update) {
      if (update.confirmedText.isNotEmpty) {
        onFinalResult?.call(update.confirmedText.trim());
      }
      if (update.partialText.isNotEmpty) {
        onPartialResult?.call(update.partialText.trim());
      }
    });

    _setState(WhisperState.listening);
  }

  // ── Stop ──────────────────────────────────────────────────────────────────
  Future<void> stopListening() async {
    await _streamSub?.cancel();
    await _streamTask?.stop();
    _streamSub  = null;
    _streamTask = null;
    _setState(WhisperState.ready);
  }

  void _setState(WhisperState s) {
    state = s;
    onStateChanged?.call(s);
  }

  Future<void> dispose() async {
    await stopListening();
    _engine?.dispose();
  }
}