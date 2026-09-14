import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/ai/whisper_on_device_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/internet_service.dart';
import '../../../core/services/map_service.dart';
import '../../home/data/datasources/export_datasource.dart';
import '../../home/data/models/vehicle_result.dart';
import '../../home/data/repositories/vehicle_repository.dart';

class HomeController extends ChangeNotifier {
  final WhisperOnDeviceService _whisper;
  final VehicleRepository      _repo;
  final LocationService        _location;
  final MapService             _map;
  final InternetService        _internet;
  final ExportDatasource       _export;

  HomeController({
    WhisperOnDeviceService? whisper,
    VehicleRepository?      repo,
    LocationService?        location,
    MapService?             map,
    InternetService?        internet,
    ExportDatasource?       export,
  })  : _whisper  = whisper  ?? WhisperOnDeviceService(),
        _repo     = repo     ?? VehicleRepository(),
        _location = location ?? LocationService(),
        _map      = map      ?? MapService(),
        _internet = internet ?? InternetService(),
        _export   = export   ?? ExportDatasource() {
    _initWhisper();
  }

  // ── State ──────────────────────────────────────────────────────────────────
  final history        = <VehicleResult>[];
  bool isRecording     = false;
  bool isDownloading   = false;
  bool isModelReady    = false;
  bool isProcessing    = false;
  double downloadProgress = 0;
  String downloadLabel    = '';
  String status           = 'جاري التهيئة...';
  String liveTranscript   = '';
  String partialTranscript = '';
  int seconds = 0;

  double? _latitude;
  double? _longitude;
  Timer?  _elapsedTimer;

  String get timeFormatted =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> _initWhisper() async {
    _whisper.onStateChanged = _onWhisperState;
    _whisper.onPartialResult = (text) {
      partialTranscript = text;
      notifyListeners();
    };
    _whisper.onFinalResult = _onFinalTranscript;

    await _whisper.initialize();

    if (_whisper.state == WhisperState.ready) {
      isModelReady = true;
      _setStatus('✅ الموديل جاهز — ابدأ التسجيل');
    } else {
      _setStatus('📥 يحتاج تحميل الموديل (${AppConstants.whisperModelSizeMB}MB)');
    }
  }

  // ── Download Model ─────────────────────────────────────────────────────────
  Future<void> downloadModel() async {
    if (!await _internet.hasInternet()) {
      _setStatus('⚠️ تحتاج إنترنت لتحميل الموديل (مرة واحدة فقط)');
      return;
    }

    isDownloading = true;
    _setStatus('📥 جاري تحميل الموديل...');

    try {
      await _whisper.downloadModels(
        onProgress: (progress, label) {
          downloadProgress = progress;
          downloadLabel    = label;
          notifyListeners();
        },
      );
      isModelReady  = true;
      isDownloading = false;
      _setStatus('✅ تم التحميل — ابدأ التسجيل');
    } catch (e) {
      isDownloading = false;
      _setStatus('❌ فشل التحميل — تحقق من الإنترنت');
    }
  }

  // ── Recording ──────────────────────────────────────────────────────────────
  Future<void> startRecording() async {
    if (!isModelReady) { await downloadModel(); return; }

    _fetchLocation();
    _repo.resetSession();
    liveTranscript    = '';
    partialTranscript = '';
    seconds           = 0;
    isRecording       = true;

    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) { seconds++; notifyListeners(); },
    );

    await _whisper.startListening();
    _setStatus('🎙️ يسمع ويحوّل... (offline)');
  }

  Future<void> stopRecording() async {
    _elapsedTimer?.cancel();
    await _whisper.stopListening();
    isRecording = false;
    _setStatus(history.isEmpty
        ? '⚠️ لم يتم التعرف على أي لوحة'
        : '✅ تم — ${history.length} سيارة');
  }

  // ── Whisper Callbacks ──────────────────────────────────────────────────────
  void _onWhisperState(WhisperState s) {
    notifyListeners();
  }

  Future<void> _onFinalTranscript(String transcript) async {
    liveTranscript    = transcript;
    partialTranscript = '';
    isProcessing      = true;
    notifyListeners();

    try {
      final results = await _repo.processTranscript(
        transcript: transcript,
        latitude:   _latitude,
        longitude:  _longitude,
      );

      if (results.isNotEmpty) {
        history.insertAll(0, results);
        if (isRecording) {
          _setStatus('🎙️ آخر لوحة: ${results.first.plateNumber}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Extract error: $e');
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  // ── Location ───────────────────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    try {
      final r  = await _location.getCurrentLocation();
      _latitude  = r.latitude;
      _longitude = r.longitude;
    } catch (_) {}
  }

  // ── Edit / Delete ──────────────────────────────────────────────────────────
  void deleteItem(String id) {
    history.removeWhere((e) => e.id == id);
    _setStatus('تم الحذف');
  }

  void updateItem(VehicleResult item, {
    required String plateNumber,
    required String vehicleType,
    required String address,
  }) {
    item.plateNumber = plateNumber.trim();
    item.vehicleType = vehicleType.trim();
    item.address     = address.trim();
    item.status      = item.plateNumber.isEmpty ? 'needs_review' : 'ok';
    item.confidence  = 'high';
    _setStatus('✅ تم التعديل');
  }

  // ── Export / Map ───────────────────────────────────────────────────────────
  Future<bool> openMap(String url) => _map.open(url);

  Future<void> exportToExcel() async {
    if (history.isEmpty) { _setStatus('لا توجد بيانات'); return; }
    try {
      await _export.exportVehicles(history);
      _setStatus('✅ تم التصدير');
    } catch (_) { _setStatus('❌ فشل التصدير'); }
  }

  void _setStatus(String s) { status = s; notifyListeners(); }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _whisper.dispose();
    super.dispose();
  }
}
