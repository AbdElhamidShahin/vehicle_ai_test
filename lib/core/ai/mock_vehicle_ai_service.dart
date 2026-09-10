import 'vehicle_ai_service.dart';

/// Local development implementation used before the Firebase backend exists.
/// It lets us test the complete Flutter flow without any AI key.
class MockVehicleAiService implements VehicleAiService {
  @override
  Future<Map<String, dynamic>> processAudio({
    required List<int> audioBytes,
    required String mimeType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return {
      'success': true,
      'transcript': 'تجربة تسجيل سيارة',
      'plate_number': 'TEST 1234',
      'vehicle_type': 'نقل',
      'address': 'جراج تجريبي',
    };
  }
}
