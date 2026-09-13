import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/internet_service.dart';
import '../../../core/services/map_service.dart';
import '../../home/data/datasources/export_datasource.dart';
import '../../home/data/models/vehicle_result.dart';
import '../../home/data/repositories/vehicle_repository.dart';

class HomeController extends ChangeNotifier {
  final AudioService _audio;
  final LocationService _location;
  final MapService _map;
  final InternetService _internet;
  final ExportDatasource _export;
  final VehicleRepository _repo;

  HomeController({
    AudioService? audio,
    LocationService? location,
    MapService? map,
    InternetService? internet,
    ExportDatasource? export,
    VehicleRepository? repo,
  })  : _audio = audio ?? AudioService(),
        _location = location ?? LocationService(),
        _map = map ?? MapService(),
        _internet = internet ?? InternetService(),
        _export = export ?? ExportDatasource(),
        _repo = repo ?? VehicleRepository(audioService: audio ?? AudioService());

  // ── State ─────────────────────────────────────────────────────────────────
  final history = <VehicleResult>[];
  bool isRecording = false;
  bool isProcessing = false; // chunk يتعالج في الخلفية
  String status = 'جاهز للتسجيل';
  String liveTranscript = ''; // آخر نص ظهر من Groq
  int seconds = 0;

  // ── Internal ──────────────────────────────────────────────────────────────
  Timer? _elapsedTimer;  // عداد الوقت
  Timer? _chunkTimer;    // rotate chunk كل X ثواني
  double? _latitude;
  double? _longitude;
  int _activeChunks = 0; // عدد الـ chunks اللي بتتعالج دلوقتي

  String get timeFormatted =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
          '${(seconds % 60).toString().padLeft(2, '0')}';

  String get currentModel => AppConstants.activeGroqModel ==
      AppConstants.groqModelTurbo
      ? '⚡ Turbo'
      : '🎯 Large v3';

  // ── Recording ─────────────────────────────────────────────────────────────
  Future<void> startRecording() async {
    try {
      if (!await _internet.hasInternet()) {
        status = '⚠️ لا يوجد اتصال بالإنترنت';
        notifyListeners();
        return;
      }
      if (!await _audio.hasPermission()) {
        status = '🎙️ يجب السماح للتطبيق باستخدام الميكروفون';
        notifyListeners();
        return;
      }

      // جيب الموقع في الخلفية مع بدء التسجيل
      _fetchLocation();

      await _audio.start();
      _repo.resetContext();
      liveTranscript = '';
      seconds = 0;
      isRecording = true;
      status = '🎙️ جاري التسجيل... ($currentModel)';

      // عداد الوقت كل ثانية
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        seconds++;
        notifyListeners();
      });

      // chunk timer — rotate كل CHUNK_DURATION ثواني
      _chunkTimer = Timer.periodic(
        Duration(seconds: AppConstants.chunkDurationSeconds),
            (_) => _rotateAndProcess(),
      );

      notifyListeners();
    } catch (e) {
      status = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    _chunkTimer?.cancel();
    _elapsedTimer?.cancel();

    isRecording = false;
    status = '⏳ جاري معالجة آخر جزء...';
    notifyListeners();

    try {
      // وقّف التسجيل وعالج آخر chunk
      final lastPath = await _audio.stop();
      if (lastPath != null) {
        await _processChunk(lastPath);
      }
    } catch (e) {
      // متوقف حتى لو فيه error في آخر chunk
    }

    status = history.isEmpty
        ? '⚠️ لم يتم التعرف على أي لوحة'
        : '✅ تم الانتهاء — ${history.length} سيارة';
    notifyListeners();
  }

  // ── Chunk processing ──────────────────────────────────────────────────────

  /// وقّف الـ chunk الحالي، ابدأ جديد، عالج القديم في الخلفية
  Future<void> _rotateAndProcess() async {
    if (!isRecording) return;
    try {
      final chunkPath = await _audio.rotateChunk();
      if (chunkPath != null) {
        // معالجة في الخلفية — مش بنستنى عشان التسجيل يكمل
        _processChunk(chunkPath);
      }
    } catch (_) {
      // مشكلة في الـ rotation → نكمل التسجيل بدون وقف
    }
  }

  /// بعت الـ chunk لـ Groq ثم Flash Lite وأضف النتائج للجدول
  Future<void> _processChunk(String chunkPath) async {
    _activeChunks++;
    isProcessing = true;
    notifyListeners();

    try {
      final results = await _repo.processChunk(
        audioPath: chunkPath,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (results.isNotEmpty) {
        // أضف النتائج في أول الجدول
        history.insertAll(0, results);
        liveTranscript = results.first.transcript;
        if (isRecording) {
          status = '🎙️ جاري التسجيل... ($currentModel)  '
              '| آخر لوحة: ${results.first.plateNumber}';
        }
      }
    } catch (e) {
      // chunk فشل → نكمل بدون وقف
      if (kDebugMode) print('Chunk error: $e');
    } finally {
      _activeChunks--;
      if (_activeChunks <= 0) {
        _activeChunks = 0;
        isProcessing = false;
      }
      notifyListeners();
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    try {
      final result = await _location.getCurrentLocation();
      _latitude = result.latitude;
      _longitude = result.longitude;
    } catch (_) {
      // الموقع اختياري — التطبيق يكمل بدونه
    }
  }

  // ── Edit / Delete ─────────────────────────────────────────────────────────
  void deleteItem(String id) {
    history.removeWhere((e) => e.id == id);
    status = 'تم حذف السطر';
    notifyListeners();
  }

  void updateItem(
      VehicleResult item, {
        required String plateNumber,
        required String vehicleType,
        required String address,
      }) {
    item.plateNumber = plateNumber.trim();
    item.vehicleType = vehicleType.trim();
    item.address = address.trim();
    item.status = item.plateNumber.isEmpty ? 'needs_review' : 'ok';
    item.error =
    item.plateNumber.isEmpty ? 'لم يتم التعرف على رقم اللوحة' : null;
    status = 'تم التعديل بنجاح';
    notifyListeners();
  }

  // ── Export / Map ──────────────────────────────────────────────────────────
  Future<bool> openMap(String url) => _map.open(url);

  Future<void> exportToExcel() async {
    if (history.isEmpty) {
      status = 'لا توجد بيانات للتصدير';
      notifyListeners();
      return;
    }
    try {
      await _export.exportVehicles(history);
      status = 'تم التصدير بنجاح';
    } catch (_) {
      status = '❌ فشل التصدير';
    }
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('internet') || text.contains('socket')) {
      return '⚠️ لا يوجد اتصال بالإنترنت';
    }
    if (text.contains('groq') || text.contains('gemini')) {
      return '⚠️ تعذر الاتصال بالـ AI، حاول مرة أخرى';
    }
    return '❌ حدث خطأ، حاول مرة أخرى';
  }

  @override
  void dispose() {
    _chunkTimer?.cancel();
    _elapsedTimer?.cancel();
    _audio.dispose();
    _repo.dispose();
    super.dispose();
  }
}
