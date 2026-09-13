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
  final AudioService      _audio;
  final LocationService   _location;
  final MapService        _map;
  final InternetService   _internet;
  final ExportDatasource  _export;
  final VehicleRepository _repo;

  HomeController({
    AudioService?      audio,
    LocationService?   location,
    MapService?        map,
    InternetService?   internet,
    ExportDatasource?  export,
    VehicleRepository? repo,
  })  : _audio    = audio    ?? AudioService(),
        _location = location ?? LocationService(),
        _map      = map      ?? MapService(),
        _internet = internet ?? InternetService(),
        _export   = export   ?? ExportDatasource(),
        _repo     = repo     ?? VehicleRepository(
            audioService: audio ?? AudioService());

  // ── State ──────────────────────────────────────────────────────────────────
  final history   = <VehicleResult>[];
  bool isRecording  = false;
  bool isProcessing = false;
  String status       = 'جاهز للتسجيل';
  String liveTranscript = '';
  int seconds = 0;

  // ── Internal ───────────────────────────────────────────────────────────────
  Timer? _elapsedTimer;
  Timer? _chunkTimer;
  double? _latitude;
  double? _longitude;
  int _activeChunks = 0;

  String get timeFormatted =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
          '${(seconds % 60).toString().padLeft(2, '0')}';

  String get activeModel =>
      AppConstants.activeGroqModel == AppConstants.groqModelTurbo
          ? '⚡ Turbo'
          : '🎯 Large v3';

  // ── Recording ──────────────────────────────────────────────────────────────
  Future<void> startRecording() async {
    try {
      if (!await _internet.hasInternet()) {
        _setStatus('⚠️ لا يوجد اتصال بالإنترنت');
        return;
      }
      if (!await _audio.hasPermission()) {
        _setStatus('🎙️ يجب السماح للتطبيق باستخدام الميكروفون');
        return;
      }

      _fetchLocation();
      await _audio.start();
      _repo.resetSession();

      liveTranscript = '';
      seconds       = 0;
      isRecording   = true;
      _setStatus('🎙️ جاري التسجيل... ($activeModel)');

      _elapsedTimer = Timer.periodic(
        const Duration(seconds: 1),
            (_) { seconds++; notifyListeners(); },
      );

      _chunkTimer = Timer.periodic(
        Duration(seconds: AppConstants.chunkDurationSeconds),
            (_) => _rotateAndProcess(),
      );
    } catch (e) {
      _setStatus(_friendlyError(e));
    }
  }

  Future<void> stopRecording() async {
    _chunkTimer?.cancel();
    _elapsedTimer?.cancel();
    isRecording = false;
    _setStatus('⏳ جاري معالجة آخر جزء...');

    try {
      final lastPath = await _audio.stop();
      if (lastPath != null) await _processChunk(lastPath);
    } catch (_) {}

    _setStatus(history.isEmpty
        ? '⚠️ لم يتم التعرف على أي لوحة'
        : '✅ تم — ${history.length} سيارة مسجلة');
  }

  // ── Chunk logic ────────────────────────────────────────────────────────────
  Future<void> _rotateAndProcess() async {
    if (!isRecording) return;
    try {
      final path = await _audio.rotateChunk();
      if (path != null) _processChunk(path); // بدون await — التسجيل يكمل
    } catch (e) {
      if (kDebugMode) print('Rotate error: $e');
    }
  }

  Future<void> _processChunk(String chunkPath) async {
    _activeChunks++;
    isProcessing = true;
    notifyListeners();

    try {
      final results = await _repo.processChunk(
        audioPath: chunkPath,
        latitude:  _latitude,
        longitude: _longitude,
      );

      // حدّث آخر نص من Groq
      if (_repo.lastTranscript.isNotEmpty) {
        liveTranscript = _repo.lastTranscript;
      }

      if (results.isNotEmpty) {
        history.insertAll(0, results);
        if (isRecording) {
          _setStatus(
            '🎙️ ($activeModel) | آخر لوحة: ${results.first.plateNumber}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Chunk error: $e');
      if (isRecording) {
        _setStatus('⚠️ خطأ في معالجة الصوت: ${_friendlyError(e)}');
      }
    } finally {
      _activeChunks = (_activeChunks - 1).clamp(0, 99);
      isProcessing  = _activeChunks > 0;
      notifyListeners();
    }
  }

  // ── Location ───────────────────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    try {
      final r = await _location.getCurrentLocation();
      _latitude  = r.latitude;
      _longitude = r.longitude;
    } catch (_) {}
  }

  // ── Edit / Delete ──────────────────────────────────────────────────────────
  void deleteItem(String id) {
    history.removeWhere((e) => e.id == id);
    _setStatus('تم حذف السطر');
  }

  void updateItem(
      VehicleResult item, {
        required String plateNumber,
        required String vehicleType,
        required String address,
      }) {
    item.plateNumber = plateNumber.trim();
    item.vehicleType = vehicleType.trim();
    item.address     = address.trim();
    item.status      = item.plateNumber.isEmpty ? 'needs_review' : 'ok';
    item.confidence  = 'high'; // بعد التعديل اليدوي = موثوق
    _setStatus('✅ تم التعديل');
  }

  // ── Export / Map ───────────────────────────────────────────────────────────
  Future<bool> openMap(String url) => _map.open(url);

  Future<void> exportToExcel() async {
    if (history.isEmpty) { _setStatus('لا توجد بيانات'); return; }
    try {
      await _export.exportVehicles(history);
      _setStatus('✅ تم التصدير');
    } catch (_) {
      _setStatus('❌ فشل التصدير');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _setStatus(String s) { status = s; notifyListeners(); }

  String _friendlyError(Object e) {
    final t = e.toString().toLowerCase();
    if (t.contains('socket') || t.contains('network')) {
      return '⚠️ لا يوجد اتصال بالإنترنت';
    }
    if (t.contains('groq')) return '⚠️ خطأ في Groq';
    if (t.contains('gemini')) return '⚠️ خطأ في Gemini';
    if (t.contains('timeout')) return '⚠️ انتهت مهلة الاتصال';
    return '❌ حدث خطأ';
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
