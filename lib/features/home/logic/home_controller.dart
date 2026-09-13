// lib/features/home/logic/home_controller.dart
//
// ✅ الإصلاحات:
//   1. استدعاء _repo.initialize() بعد _deepgram.start() مباشرةً
//   2. الـ _interimSub بيستمع للـ interim فقط (مش isFinal) للعرض في الـ UI
//   3. الـ _plateSub بيستمع لـ _repo.plateStream (StreamController حقيقي)
//   4. liveText بيتمسح لما تيجي لوحة مكتملة
//   5. الـ API key بييجي من AppConstants بدل hardcoded string فارغ

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
    // ✅ الـ API key من AppConstants (مش hardcoded)
    _deepgram = DeepgramLiveService(apiKey: AppConstants.deepgramApiKey);
    _repo     = VehicleRepository(deepgram: _deepgram);
  }

  // ── State ──────────────────────────────────────────────────────────────────
  final history = <VehicleResult>[];
  bool   isRecording  = false;
  bool   isProcessing = false; // للتوافق مع RecorderCard الموجود
  String status       = 'جاهز للتسجيل';
  String liveText     = '';   // النص الـ interim يظهر وأنت بتتكلم
  String liveTranscript = ''; // للتوافق مع RecorderCard القديم
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
      // 1. فتح الـ WebSocket + بدء الميكروفون
      await _deepgram.start();

      // ✅ 2. بعد ما الـ service اشتغل، نربط الـ repository بالـ stream
      _repo.initialize();

      // 3. اشترك في النص الـ interim (للعرض الفوري في الـ UI)
      _interimSub = _deepgram.onTranscript.listen((t) {
        if (!t.isFinal) {
          // ✅ بس الـ interim يظهر — الـ final بيتعالج في الـ repository
          liveText      = t.text;
          liveTranscript = t.text; // للتوافق مع RecorderCard
          notifyListeners();
        } else {
          // لما تيجي نتيجة final، امسح الـ live text (اللوحة هتظهر في الـ history)
          liveText      = '';
          liveTranscript = '';
          notifyListeners();
        }
      });

      // 4. اشترك في اللوحات المكتملة
      _plateSub = _repo.plateStream.listen((result) {
        history.insert(0, result);
        liveText      = '';
        liveTranscript = '';
        status = '✅ لوحة ${result.plateNumber} — ${history.length} إجمالاً';
        notifyListeners();
      });

      // 5. عداد الوقت
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

    await _plateSub?.cancel();
    _plateSub = null;

    await _deepgram.stop();

    isRecording   = false;
    isProcessing  = false;
    liveText      = '';
    liveTranscript = '';
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

  // ── Export (للتوافق مع HistorySection) ────────────────────────────────────
  Future<void> exportToExcel() async {
    // TODO: اربطه بـ export_datasource.dart
  }

  Future<bool> openMap(String url) async {
    // TODO: استخدم url_launcher
    return false;
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