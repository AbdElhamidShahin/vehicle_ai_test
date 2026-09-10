import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/ai/cloud_function_ai_service.dart';
import '../../../core/ai/firebase_ai_logic_vehicle_ai_service.dart';
import '../../../core/ai/vehicle_ai_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/internet_service.dart';
import '../../../core/services/map_service.dart';
import '../data/datasources/export_datasource.dart';
import '../data/models/vehicle_result.dart';
import '../data/repositories/vehicle_repository.dart';

class HomeController extends ChangeNotifier {
  late final AudioService _audio;
  late final LocationService _location;
  late final MapService _map;
  late final InternetService _internet;
  late final ExportDatasource _export;
  late final VehicleRepository _repo;

  HomeController({
    AudioService? audio,
    LocationService? location,
    MapService? map,
    InternetService? internet,
    ExportDatasource? export,
    VehicleAiService? ai,
  }) {
    _audio = audio ?? AudioService();
    _location = location ?? LocationService();
    _map = map ?? MapService();
    _internet = internet ?? InternetService();
    _export = export ?? ExportDatasource();
    _repo = VehicleRepository(
      audioService: _audio,
      aiService: ai ?? _createAiService(),
    );
  }

  VehicleAiService _createAiService() {
    // Temporary testing path: Firebase AI Logic -> Gemini 3.5 Flash-Lite.
    // When AI_FUNCTION_URL is supplied, the production Cloud Function path wins.
    if (AppConstants.aiFunctionUrl.isNotEmpty) {
      return CloudFunctionAiService(
        endpoint: Uri.parse(AppConstants.aiFunctionUrl),
      );
    }
    return FirebaseAiLogicVehicleAiService();
  }

  final history = <VehicleResult>[];
  Timer? _timer;
  int seconds = 0;
  bool isRecording = false;
  bool isProcessing = false;
  String status = 'جاهز للتسجيل';
  String? _audioPath;
  Future<LocationResult>? _locationFuture;

  String get timeFormatted =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  Future<void> startRecording() async {
    try {
      if (!await _internet.hasInternet()) {
        status = '⚠️ لا يوجد اتصال بالإنترنت، اتصل بالإنترنت وحاول مرة أخرى';
        notifyListeners();
        return;
      }
      if (!await _audio.hasPermission()) {
        status = '🎙️ يجب السماح للتطبيق باستخدام الميكروفون';
        notifyListeners();
        return;
      }

      // Start location lookup at the same time as recording.
      _locationFuture = _location.getCurrentLocation();
      final path = await _audio.start();

      _timer?.cancel();
      seconds = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        seconds++;
        notifyListeners();
      });

      isRecording = true;
      isProcessing = false;
      _audioPath = path;
      status = '🎙️ جاري تسجيل بيانات السيارة...';
      notifyListeners();
    } catch (e) {
      status = _friendlyError(e);
      _locationFuture = null;
      notifyListeners();
    }
  }

  Future<void> stopAndProcessRecording() async {
    try {
      _timer?.cancel();
      final path = await _audio.stop();
      isRecording = false;
      _audioPath = path ?? _audioPath;
      notifyListeners();
      if (_audioPath != null) await processRecording();
    } catch (e) {
      status = '❌ تعذر إيقاف التسجيل، حاول مرة أخرى';
      notifyListeners();
    }
  }

  Future<void> processRecording() async {
    final path = _audioPath;
    if (path == null || !await _audio.exists(path)) {
      status = '❌ لا يوجد ملف صوتي للمعالجة';
      notifyListeners();
      return;
    }

    isProcessing = true;
    status = '🔄 جاري تحليل التسجيل...';
    notifyListeners();

    try {
      final result = await _repo.processRecording(
        audioPath: path,
        locationFuture: _locationFuture ?? _location.getCurrentLocation(),
      );

      history.insert(0, result);
      await _audio.delete(path);
      _audioPath = null;
      _locationFuture = null;

      status = result.status == 'ok'
          ? '✅ تم تسجيل السيارة بنجاح'
          : '⚠️ لم يتم التعرف على رقم اللوحة، يرجى إعادة التسجيل';
    } on TimeoutException {
      status = '⚠️ انتهت مهلة الاتصال، حاول مرة أخرى';
    } on LocationException catch (e) {
      // Keep the audio when GPS failed so the record is not silently lost.
      status = '📍 ${e.message}';
    } catch (e) {
      status = _friendlyError(e);
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('internet') || text.contains('socket')) {
      return '⚠️ لا يوجد اتصال بالإنترنت، اتصل بالإنترنت وحاول مرة أخرى';
    }
    if (text.contains('backend') || text.contains('ai')) {
      return '⚠️ تعذر تحليل التسجيل، حاول مرة أخرى';
    }
    return '❌ حدث خطأ، حاول مرة أخرى';
  }

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
    item.error = item.plateNumber.isEmpty ? 'لم يتم التعرف على رقم اللوحة' : null;
    status = 'تم التعديل بنجاح';
    notifyListeners();
  }

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
      status = '❌ فشل التصدير، حاول مرة أخرى';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audio.dispose();
    _repo.dispose();
    super.dispose();
  }
}
