import '../../../../core/ai/vehicle_ai_service.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/location_service.dart';
import '../models/vehicle_result.dart';

class VehicleRepository {
  final AudioService audioService;
  final VehicleAiService aiService;

  VehicleRepository({
    required this.audioService,
    required this.aiService,
  });

  Future<VehicleResult> processRecording({
    required String audioPath,
    required Future<LocationResult> locationFuture,
  }) async {
    // Read the audio and wait for GPS in parallel to reduce latency.
    final results = await Future.wait<dynamic>([
      audioService.readBytes(audioPath),
      locationFuture,
    ]);

    final bytes = results[0] as List<int>;
    final location = results[1] as LocationResult;

    final json = await aiService.processAudio(
      audioBytes: bytes,
      mimeType: 'audio/mp4',
    );

    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final result = VehicleResult.fromJson(
      json,
      date: date,
      time: time,
      latitude: location.latitude,
      longitude: location.longitude,
    );

    if (result.plateNumber.isEmpty) {
      result.status = 'needs_review';
      result.error = 'لم يتم التعرف على رقم اللوحة';
    } else {
      result.status = 'ok';
      result.error = null;
    }

    return result;
  }

  void dispose() {}
}
