import '../models/vehicle_result.dart';
import '../../../../core/ai/groq_stt_service.dart';
import '../../../../core/ai/gemini_flash_service.dart';
import '../../../../core/services/audio_service.dart';

class VehicleRepository {
  final AudioService audioService;
  final GroqSttService groqService;
  final GeminiFlashService geminiService;

  // آخر 3 transcripts كـ context لـ Flash Lite
  final _transcriptBuffer = <String>[];

  // اللوحات اللي اتسجلت في الجلسة دي — لمنع التكرار
  final _seenPlates = <String>{};

  // آخر transcript جاي من Groq — للعرض في الـ UI
  String lastTranscript = '';

  VehicleRepository({
    required this.audioService,
    GroqSttService? groq,
    GeminiFlashService? gemini,
  })  : groqService = groq ?? GroqSttService(),
        geminiService = gemini ?? GeminiFlashService();

  Future<List<VehicleResult>> processChunk({
    required String audioPath,
    required double? latitude,
    required double? longitude,
  }) async {
    // ── 1. قرا البايتات ─────────────────────────────────────────────────────
    final bytes = await audioService.readBytes(audioPath);
    await audioService.delete(audioPath);

    // الـ chunk الصغير جداً (أقل من 5KB) مش هيكون فيه كلام
    if (bytes.length < 5000) return [];

    // ── 2. Groq: صوت → نص ──────────────────────────────────────────────────
    final transcript = await groqService.transcribe(bytes);
    lastTranscript = transcript;
    if (transcript.isEmpty) return [];

    // ── 3. Flash Lite: نص → لوحات ─────────────────────────────────────────
    final context = _transcriptBuffer.length >= 2
        ? _transcriptBuffer.sublist(_transcriptBuffer.length - 2).join(' ')
        : _transcriptBuffer.join(' ');

    final extracted = await geminiService.extractVehicles(
      transcript: transcript,
      previousContext: context,
    );

    // حدّث الـ buffer
    _transcriptBuffer.add(transcript);
    if (_transcriptBuffer.length > 5) _transcriptBuffer.removeAt(0);

    if (extracted.isEmpty) return [];

    // ── 4. بناء النتائج مع فلترة التكرار ──────────────────────────────────
    final now = DateTime.now();
    final date = _formatDate(now);
    final time = _formatTime(now);

    final results = <VehicleResult>[];

    for (final v in extracted) {
      final result = VehicleResult.fromExtracted(
        v,
        transcript: transcript,
        date: date,
        time: time,
        latitude: latitude,
        longitude: longitude,
      );

      // تجاهل لوحات فاضية
      if (result.plateNumber.isEmpty) continue;

      // تجاهل تكرار نفس اللوحة في نفس الجلسة
      final normalizedPlate = result.plateNumber
          .replaceAll(' ', '')
          .toLowerCase();
      if (_seenPlates.contains(normalizedPlate)) continue;

      _seenPlates.add(normalizedPlate);
      results.add(result);
    }

    return results;
  }

  void resetSession() {
    _transcriptBuffer.clear();
    _seenPlates.clear();
    lastTranscript = '';
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void dispose() {}
}
