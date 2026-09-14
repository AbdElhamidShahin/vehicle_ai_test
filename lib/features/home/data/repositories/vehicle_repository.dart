import '../models/vehicle_result.dart';
import '../../../../core/ai/gemini_flash_service.dart';

/// بيأخد النص من whisper.cpp ويبعته لـ Flash Lite ويرجع اللوحات
class VehicleRepository {
  final GeminiFlashService _gemini;

  final _transcriptBuffer = <String>[];
  final _seenPlates       = <String>{};
  String lastTranscript   = '';

  VehicleRepository({GeminiFlashService? gemini})
      : _gemini = gemini ?? GeminiFlashService();

  /// بياخد نص من whisper ويرجع اللوحات المستخرجة
  Future<List<VehicleResult>> processTranscript({
    required String transcript,
    required double? latitude,
    required double? longitude,
  }) async {
    lastTranscript = transcript;
    if (transcript.trim().isEmpty) return [];

    final context = _transcriptBuffer.length >= 2
        ? _transcriptBuffer.sublist(_transcriptBuffer.length - 2).join(' ')
        : _transcriptBuffer.join(' ');

    final extracted = await _gemini.extractVehicles(
      transcript: transcript,
      previousContext: context,
    );

    _transcriptBuffer.add(transcript);
    if (_transcriptBuffer.length > 5) _transcriptBuffer.removeAt(0);

    if (extracted.isEmpty) return [];

    final now  = DateTime.now();
    final date = _fmt(now, date: true);
    final time = _fmt(now, date: false);

    final results = <VehicleResult>[];
    for (final v in extracted) {
      final r = VehicleResult.fromExtracted(
        v,
        transcript: transcript,
        date: date,
        time: time,
        latitude: latitude,
        longitude: longitude,
      );
      if (r.plateNumber.isEmpty) continue;
      final key = r.plateNumber.replaceAll(' ', '');
      if (_seenPlates.contains(key)) continue;
      _seenPlates.add(key);
      results.add(r);
    }
    return results;
  }

  void resetSession() {
    _transcriptBuffer.clear();
    _seenPlates.clear();
    lastTranscript = '';
  }

  String _fmt(DateTime d, {required bool date}) => date
      ? '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
      : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
