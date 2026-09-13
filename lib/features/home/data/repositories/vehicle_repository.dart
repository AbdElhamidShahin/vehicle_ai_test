import '../../../../core/ai/DeepgramLiveService.dart';
import '../../data/models/vehicle_result.dart';

class VehicleRepository {
  final DeepgramLiveService deepgramService;

  VehicleRepository({
    DeepgramLiveService? deepgramLiveService,
  }) : deepgramService = deepgramLiveService ?? DeepgramLiveService();

  /// دالة التحقق والفلاتر الصارمة: تضمن أن اللوحة 3 حروف و 4 أرقام فقط
  String _normalizeAndValidatePlate(String raw) {
    var result = raw.trim();

    // 1. تحويل الأرقام العربية لهندية/إنجليزية لو وجدت
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], '$i');
    }

    // 2. فلتر وتنسيق الحروف والأرقام (مثال: 3 حروف أو أكثر بقليل متبوعة بمسافة و 4 أرقام)
    final plateRegex = RegExp(r'^([أ-يA-Za-z\s]{2,8})\s+(\d{4})$');
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    if (plateRegex.hasMatch(result)) {
      final parts = result.split(' ');
      if (parts.isNotEmpty && RegExp(r'^[a-zA-Z]+$').hasMatch(parts.first)) {
        parts[0] = parts.first.toUpperCase();
        result = parts.join(' ');
      }
      return result;
    }

    // لو غير مطابقة للشرط (ناقصة أو زايدة) → تُرفض فوراً
    return '';
  }

  /// معالجة النص القادم من الـ Live Stream
  List<VehicleResult> processLiveTranscript({
    required String rawTranscript,
    required double? latitude,
    required double? longitude,
  }) {
    final validatedPlate = _normalizeAndValidatePlate(rawTranscript);

    if (validatedPlate.isEmpty) return [];

    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final vehicleResult = VehicleResult.fromExtracted(
      {
        'plate_number': validatedPlate,
        'vehicle_type': '',
        'address': '',
      },
      transcript: rawTranscript,
      date: date,
      time: time,
      latitude: latitude,
      longitude: longitude,
    );

    return [vehicleResult];
  }

  void dispose() {
    deepgramService.dispose();
  }
}