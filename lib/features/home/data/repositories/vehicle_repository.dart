// lib/features/home/data/repositories/vehicle_repository.dart
//
// ✅ الإصلاحات:
//   1. Queue بدل skip — مفيش chunk بيتضيع
//   2. كل final transcript بيتبعت لـ Gemini مستقل (مش بس speechFinal)
//      — لإن speechFinal ممكن تيجي مرة واحدة لكل اللوحات مع بعض
//   3. الـ buffer بيتمسح بعد كل final للتقليل من التراكم

import 'dart:async';
import '../../../../core/ai/DeepgramLiveService.dart';
import '../../../../core/ai/gemini_flash_service.dart';
import '../models/vehicle_result.dart';

class VehicleRepository {
  VehicleRepository({required this.deepgram});

  final DeepgramLiveService deepgram;
  final _gemini = GeminiFlashService();

  final _plateCtrl = StreamController<VehicleResult>.broadcast();
  Stream<VehicleResult> get plateStream => _plateCtrl.stream;

  StreamSubscription<DeepgramTranscript>? _transcriptSub;

  // ✅ Queue بدل _isFlushing flag
  final _queue = <String>[];
  bool _isProcessing = false;

  // Buffer للـ interim finals قبل speechFinal
  final StringBuffer _buf = StringBuffer();

  // عدد finals المتراكمة (لو وصلت حد معين نبعت حتى لو مفيش speechFinal)
  int _finalCount = 0;
  static const int _maxFinalsBeforeFlush = 3; // ابعت كل 3 finals

  double? latitude;
  double? longitude;

  // ── initialize ────────────────────────────────────────────────────────────
  void initialize() {
    _transcriptSub?.cancel();
    print('🟢 [REPO] initialize()');

    _transcriptSub = deepgram.onTranscript.listen((t) {
      print('📡 [DG] final=${t.isFinal} sf=${t.speechFinal} → "${t.text}"');

      if (!t.isFinal) return;

      if (t.text.isNotEmpty) {
        if (_buf.isNotEmpty) _buf.write(' ');
        _buf.write(t.text);
        _finalCount++;
        print('📝 [BUF] (finals=$_finalCount) "${_buf}"');
      }

      // ✅ ابعت لـ Gemini في حالتين:
      // 1. speechFinal (صمت مكتمل)
      // 2. تراكم عدد كبير من finals (لو الشخص بيتكلم بدون توقف)
      if (t.speechFinal || _finalCount >= _maxFinalsBeforeFlush) {
        if (t.speechFinal) {
          print('🔔 [SF] → enqueue');
        } else {
          print('🔔 [MAX_FINALS=$_finalCount] → enqueue مبكر');
        }
        _enqueue();
      }
    }, onError: (e) => print('❌ [DG ERROR] $e'));
  }

  // ── Enqueue ───────────────────────────────────────────────────────────────
  void _enqueue() {
    final raw = _buf.toString().trim();
    _buf.clear();
    _finalCount = 0;

    if (raw.isEmpty) {
      print('⚠️ [ENQUEUE] فاضي — skip');
      return;
    }

    _queue.add(raw);
    print('📋 [QUEUE] أضاف: "$raw" | الطول: ${_queue.length}');
    _processNext();
  }

  // ── processNext ───────────────────────────────────────────────────────────
  void _processNext() {
    if (_isProcessing) {
      print('⏳ [QUEUE] Gemini شغال — هينتظر');
      return;
    }
    if (_queue.isEmpty) return;

    final chunk = _queue.removeAt(0);
    _isProcessing = true;
    print('🚀 [GEMINI] بنبعت: "$chunk" | متبقي في القايمة: ${_queue.length}');

    _extractAndEmit(chunk).whenComplete(() {
      _isProcessing = false;
      print('✅ [GEMINI] انتهى — بيشيك القايمة');
      _processNext();
    });
  }

  // ── استدعاء GeminiFlashService ────────────────────────────────────────────
  Future<void> _extractAndEmit(String transcript) async {
    try {
      final vehicles = await _gemini.extractVehicles(transcript: transcript);
      print('🔢 [GEMINI] عدد اللوحات: ${vehicles.length}');

      for (final v in vehicles) {
        final plate = (v['plate_number'] as String? ?? '').trim();
        print('🎉 [OK] لوحة: "$plate" | confidence: ${v['confidence']} | status: ${v['status']}');
        if (!_plateCtrl.isClosed) {
          _plateCtrl.add(_build(v, transcript));
        }
      }
    } catch (e) {
      print('❌ [GEMINI] exception: $e');
    }
  }

  // ── بناء VehicleResult ─────────────────────────────────────────────────────
  VehicleResult _build(Map<String, dynamic> v, String transcript) {
    final plate = (v['plate_number'] as String? ?? '').trim();
    final status = (v['status'] as String? ?? 'ok');
    final now = DateTime.now();

    return VehicleResult(
      id: '${now.microsecondsSinceEpoch}_$plate',
      transcript: transcript,
      plateNumber: plate,
      vehicleType: (v['vehicle_type'] as String? ?? '').trim(),
      address: (v['address'] as String? ?? '').trim(),
      latitude: latitude,
      longitude: longitude,
      mapLink: (latitude != null && longitude != null)
          ? 'https://www.google.com/maps?q=$latitude,$longitude'
          : '',
      date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      status: status,
      error: status == 'needs_review' ? 'تحتاج مراجعة' : null,
    );
  }

  // ── Reset & Dispose ───────────────────────────────────────────────────────
  void resetBuffer() {
    _buf.clear();
    _queue.clear();
    _isProcessing = false;
    _finalCount = 0;
    print('🔄 [REPO] resetBuffer()');
  }

  // ✅ فضفض أي كلام متبقي في البافر بعد stop (مش استنى speechFinal)
  void flushRemaining() {
    if (_buf.isNotEmpty) {
      print('🔔 [FLUSH_REMAINING] → enqueue ما تبقى في البافر');
      _enqueue();
    }
  }

  // ✅ استنى لحد ما القايمة تخلص تماماً
  Future<void> waitForQueue() async {
    if (!_isProcessing && _queue.isEmpty) return;
    print('⏳ [WAIT] استنى القايمة تخلص...');
    // Poll كل 100ms لحد ما يخلص
    while (_isProcessing || _queue.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    print('✅ [WAIT] القايمة خلصت');
  }

  Future<void> dispose() async {
    await _transcriptSub?.cancel();
    _transcriptSub = null;
    _buf.clear();
    _queue.clear();
    await _plateCtrl.close();
    print('🔴 [REPO] disposed');
  }
}