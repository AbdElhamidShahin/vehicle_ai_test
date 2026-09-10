import '../../features/home/data/models/vehicle_result.dart';

/// AI abstraction used by the Flutter app.
///
/// The UI and business logic do not know whether the provider is Gemini,
/// Kimi, or another model. The production implementation will call our
/// Firebase Cloud Function.
abstract class VehicleAiService {
  Future<Map<String, dynamic>> processAudio({
    required List<int> audioBytes,
    required String mimeType,
  });

}
