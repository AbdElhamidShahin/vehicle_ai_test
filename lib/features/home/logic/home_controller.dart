// lib/features/home/logic/home_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/ai/DeepgramLiveService.dart';
import '../../../core/constants/app_constants.dart';
import '../data/models/vehicle_result.dart';
import '../data/repositories/vehicle_repository.dart';

class HomeController extends ChangeNotifier {

  // ── Services ───────────────────────────────────────────────────────────────
  late final DeepgramLiveService _deepgram;
  late final VehicleRepository   _repo;

  StreamSubscription<VehicleResult>?      _plateSub;
  StreamSubscription<DeepgramTranscript>? _interimSub;

  HomeController() {
    _deepgram = DeepgramLiveService(apiKey: AppConstants.deepgramApiKey);
    _repo     = VehicleRepository(deepgram: _deepgram);
  }

  // ── State ──────────────────────────────────────────────────────────────────
  final history = <VehicleResult>[];
  bool   isRecording  = false;
  bool   isProcessing = false;
  String status       = 'جاهز للتسجيل';
  String liveText     = '';
  String liveTranscript = '';
  int    seconds      = 0;

  Timer? _clock;

  String get timeFormatted =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
          '${(seconds % 60).toString().padLeft(2, '0')}';

  // ── GPS ───────────────────────────────────────────────────────────────────
  void setLocation(double lat, double lng) {
    _repo.latitude  = lat;
    _repo.longitude = lng;
  }

  // ── Start ──────────────────────────────────────────────────────────────────
  Future<void> startRecording() async {
    if (isRecording) return;

    liveText      = '';
    liveTranscript = '';
    seconds       = 0;
    _repo.resetBuffer();
    notifyListeners();

    try {
      await _deepgram.start();
      _repo.initialize();

      // اشترك في النص الـ interim
      _interimSub = _deepgram.onTranscript.listen((t) {
        if (!t.isFinal) {
          liveText      = t.text;
          liveTranscript = t.text;
          notifyListeners();
        } else {
          liveText      = '';
          liveTranscript = '';
          notifyListeners();
        }
      });

      // ✅ اشترك في اللوحات — الـ subscription يفضل شغال حتى بعد stop
      _plateSub = _repo.plateStream.listen((result) {
        history.insert(0, result);
        liveText      = '';
        liveTranscript = '';
        status = '✅ لوحة ${result.plateNumber} — ${history.length} إجمالاً';
        notifyListeners();
      });

      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        seconds++;
        notifyListeners();
      });

      isRecording = true;
      status      = '🎙️ جاري التسجيل...';
      notifyListeners();

    } catch (e) {
      status = '❌ خطأ: $e';
      isRecording = false;
      notifyListeners();
      rethrow;
    }
  }

  // ── Stop ───────────────────────────────────────────────────────────────────
  Future<void> stopRecording() async {
    if (!isRecording) return;

    _clock?.cancel();
    _clock = null;

    await _interimSub?.cancel();
    _interimSub = null;

    // ✅ أوقف الميكروفون والـ Deepgram أولاً
    await _deepgram.stop();

    // ✅ فضفض الـ buffer لو فيه كلام لسه ما اتبعتش
    _repo.flushRemaining();

    // ✅ استنى الـ queue تخلص (كل اللوحات المعلقة تتعالج)
    isRecording   = false;
    isProcessing  = true;
    liveText      = '';
    liveTranscript = '';
    status = '⏳ جاري معالجة اللوحات المتبقية...';
    notifyListeners();

    await _repo.waitForQueue();

    // ✅ بعد ما كل حاجة خلصت، الغي الـ subscription
    await _plateSub?.cancel();
    _plateSub = null;

    isProcessing = false;
    status = history.isEmpty
        ? '⚠️ لم يُتعرف على أي لوحة'
        : '✅ انتهى — ${history.length} لوحة';
    notifyListeners();
  }

  // ── Edit / Delete ──────────────────────────────────────────────────────────
  void deleteItem(String id) {
    history.removeWhere((e) => e.id == id);
    status = 'تم الحذف';
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
    item.address     = address.trim();
    item.status      = item.plateNumber.isEmpty ? 'needs_review' : 'ok';
    status = 'تم التعديل';
    notifyListeners();
  }

  Future<void> exportToExcel() async {}

  Future<bool> openMap(String url) async => false;

  @override
  void dispose() {
    _clock?.cancel();
    _interimSub?.cancel();
    _plateSub?.cancel();
    _deepgram.dispose();
    _repo.dispose();
    super.dispose();
  }
}
