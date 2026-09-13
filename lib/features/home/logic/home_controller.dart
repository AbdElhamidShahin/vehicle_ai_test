import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/ai/DeepgramLiveService.dart';
import '../data/models/vehicle_result.dart';
import '../data/repositories/vehicle_repository.dart';
/// ─────────────────────────────────────────────────────────────────────────────
/// HomeController — يربط DeepgramLiveService + VehicleRepository بالـ UI
/// ─────────────────────────────────────────────────────────────────────────────
class HomeController extends ChangeNotifier {

  // ── Keys (ضعهما في app_constants أو من بيئة آمنة) ──────────────────────────
  static const _deepgramKey = '';

  // ── Services ───────────────────────────────────────────────────────────────
  late final DeepgramLiveService _deepgram;
  late final VehicleRepository   _repo;
  StreamSubscription<VehicleResult>?  _plateSub;
  StreamSubscription<DeepgramTranscript>? _interimSub;

  HomeController() {
    _deepgram = DeepgramLiveService(apiKey: _deepgramKey);
    _repo     = VehicleRepository(deepgram: _deepgram);
  }

  // ── State ──────────────────────────────────────────────────────────────────
  final history = <VehicleResult>[];
  bool   isRecording   = false;
  String status        = 'جاهز للتسجيل';
  String liveText      = '';   // نص interim يظهر وأنت بتتكلم
  int    seconds       = 0;

  Timer? _clock;

  String get timeFormatted =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
          '${(seconds % 60).toString().padLeft(2, '0')}';

  // ── GPS (يُضبط من الخارج بعد جلب الموقع) ─────────────────────────────────
  void setLocation(double lat, double lng) {
    _repo.latitude  = lat;
    _repo.longitude = lng;
  }

  // ── start ──────────────────────────────────────────────────────────────────
  Future<void> startRecording() async {
    if (isRecording) return;

    liveText = '';
    seconds  = 0;
    _repo.resetBuffer();

    // 1. فتح Deepgram WebSocket + بدء الميكروفون
    await _deepgram.start();

    // 2. اشترك في النص الـ interim (للعرض الفوري)
    _interimSub = _deepgram.onTranscript.listen((t) {
      liveText = t.isFinal ? '' : t.text;  // الـ interim يتعرض، الـ final يتمسح
      notifyListeners();
    });

    // 3. اشترك في اللوحات المكتملة (3 حروف + 4 أرقام)
    _plateSub = _repo.plateStream.listen((result) {
      history.insert(0, result);
      liveText = '';
      status   = '✅ لوحة ${result.plateNumber} — ${history.length} إجمالاً';
      notifyListeners();
    });

    // 4. عداد الوقت
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      seconds++;
      notifyListeners();
    });

    isRecording = true;
    status      = '🎙️ جاري التسجيل...';
    notifyListeners();
  }

  // ── stop ───────────────────────────────────────────────────────────────────
  Future<void> stopRecording() async {
    if (!isRecording) return;

    _clock?.cancel();
    await _interimSub?.cancel();
    await _plateSub?.cancel();
    await _deepgram.stop();

    isRecording = false;
    liveText    = '';
    status      = history.isEmpty
        ? '⚠️ لم يُتعرف على أي لوحة'
        : '✅ انتهى — ${history.length} لوحة';
    notifyListeners();
  }

  // ── edit / delete ──────────────────────────────────────────────────────────
  void deleteItem(String id) {
    history.removeWhere((e) => e.id == id);
    status = 'تم الحذف';
    notifyListeners();
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
    status = 'تم التعديل';
    notifyListeners();
  }

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