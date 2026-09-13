class VehicleResult {
  final String id;
  String transcript;
  String plateNumber;
  String vehicleType;
  String address;

  final double? latitude;
  final double? longitude;
  String mapLink;
  final String date;
  final String time;
  String status;
  String? error;

  VehicleResult({
    required this.id,
    required this.transcript,
    required this.plateNumber,
    required this.vehicleType,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.mapLink,
    required this.date,
    required this.time,
    required this.status,
    this.error,
  });

  /// بناء نتيجة واحدة من JSON مستخرج من Flash Lite
  factory VehicleResult.fromExtracted(
      Map<String, dynamic> json, {
        required String transcript,
        required String date,
        required String time,
        required double? latitude,
        required double? longitude,
      }) {
    final plate = '${json['plate_number'] ?? ''}'.trim();
    final lat = latitude ?? 0.0;
    final lng = longitude ?? 0.0;
    return VehicleResult(
      id: '${DateTime.now().microsecondsSinceEpoch}_$plate',
      transcript: transcript,
      plateNumber: plate,
      vehicleType: '${json['vehicle_type'] ?? ''}'.trim(),
      address: '${json['address'] ?? ''}'.trim(),
      latitude: latitude,
      longitude: longitude,
      mapLink: latitude != null
          ? 'https://www.google.com/maps?q=$lat,$lng'
          : '',
      date: date,
      time: time,
      status: plate.isEmpty ? 'needs_review' : 'ok',
      error: plate.isEmpty ? 'لم يتم التعرف على رقم اللوحة' : null,
    );
  }

  // ── للتوافق مع الكود القديم ───────────────────────────────────────────────
  factory VehicleResult.fromJson(
      Map<String, dynamic> json, {
        required String date,
        required String time,
        required double latitude,
        required double longitude,
      }) =>
      VehicleResult.fromExtracted(
        json,
        transcript: '${json['transcript'] ?? ''}'.trim(),
        date: date,
        time: time,
        latitude: latitude,
        longitude: longitude,
      );
}
