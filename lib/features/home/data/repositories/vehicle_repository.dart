// lib/features/home/data/repositories/vehicle_repository.dart
//
// ✅ بيستخدم GeminiFlashService بدل الـ regex
// البافر بيتمسح بعد كل speechFinal دايماً

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
  final StringBuffer _buf = StringBuffer();
  bool _isFlushing = false;

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
        print('📝 [BUF] "${_buf}"');
      }

      if (t.speechFinal) {
        print('🔔 [SF] → flush');
        _flush();
      }
    }, onError: (e) => print('❌ [DG ERROR] $e'));
  }

  // ── Flush — بيتمسح البافر دايماً ─────────────────────────────────────────
  void _flush() {
    final raw = _buf.toString().trim();
    _buf.clear(); // ✅ امسح دايماً أولاً

    if (raw.isEmpty) {
      print('⚠️ [FLUSH] فاضي');
      return;
    }
    if (_isFlushing) {
      print('⚠️ [FLUSH] شغال بالفعل — skip');
      return;
    }

    _isFlushing = true;
    print('🚀 [GEMINI] بنبعت: "$raw"');
    _extractAndEmit(raw).whenComplete(() => _isFlushing = false);
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
    _isFlushing = false;
    print('🔄 [REPO] resetBuffer()');
  }

  Future<void> dispose() async {
    await _transcriptSub?.cancel();
    _transcriptSub = null;
    _buf.clear();
    await _plateCtrl.close();
    print('🔴 [REPO] disposed');
  }
}