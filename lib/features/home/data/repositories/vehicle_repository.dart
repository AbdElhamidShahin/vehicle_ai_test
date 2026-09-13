import '../../data/models/vehicle_result.dart';
import '../../../../core/ai/groq_stt_service.dart';
import '../../../../core/ai/gemini_flash_service.dart';
import '../../../../core/services/audio_service.dart';

class VehicleRepository {
  final AudioService audioService;
  final GroqSttService groqService;
  final GeminiFlashService geminiService;

  /// آخر 3 transcripts عشان نديهم لـ Flash Lite كـ context
  final _transcriptBuffer = <String>[];

  VehicleRepository({
    required this.audioService,
    GroqSttService? groq,
    GeminiFlashService? gemini,
  })  : groqService = groq ?? GroqSttService(),
        geminiService = gemini ?? GeminiFlashService();

  /// معالجة chunk صوتي واحد — بيرجع قايمة العربيات اللي اتذكرت فيه
  Future<List<VehicleResult>> processChunk({
    required String audioPath,
    required double? latitude,
    required double? longitude,
  }) async {
    // 1. قراءة الـ chunk
    final bytes = await audioService.readBytes(audioPath);
    await audioService.delete(audioPath);

    // 2. Groq: صوت → نص
    final transcript = await groqService.transcribe(bytes);
    if (transcript.isEmpty) return [];

    // 3. Flash Lite: نص → قايمة عربيات
    final context = _transcriptBuffer.length > 2
        ? _transcriptBuffer.sublist(_transcriptBuffer.length - 2).join(' ')
        : _transcriptBuffer.join(' ');

    final extracted = await geminiService.extractVehicles(
      transcript: transcript,
      previousContext: context,
    );

    // تحديث الـ buffer
    _transcriptBuffer.add(transcript);
    if (_transcriptBuffer.length > 5) _transcriptBuffer.removeAt(0);

    if (extracted.isEmpty) return [];

    // 4. بناء نتائج
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return extracted
        .map((v) => VehicleResult.fromExtracted(
      v,
      transcript: transcript,
      date: date,
      time: time,
      latitude: latitude,
      longitude: longitude,
    ))
        .where((r) => r.plateNumber.isNotEmpty)
        .toList();
  }

  void resetContext() => _transcriptBuffer.clear();

  void dispose() {}
}
