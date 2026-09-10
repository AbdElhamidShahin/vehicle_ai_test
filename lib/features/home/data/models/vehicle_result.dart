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

  factory VehicleResult.fromJson(
    Map<String, dynamic> json, {
    required String date,
    required String time,
    required double latitude,
    required double longitude,
  }) {
    final address = '${json['address'] ?? ''}'.trim();
    return VehicleResult(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      transcript: '${json['transcript'] ?? ''}'.trim(),
      plateNumber: '${json['plate_number'] ?? ''}'.trim(),
      vehicleType: '${json['vehicle_type'] ?? ''}'.trim(),
      address: address,
      latitude: latitude,
      longitude: longitude,
      mapLink: 'https://www.google.com/maps?q=$latitude,$longitude',
      date: date,
      time: time,
      status: '${json['status'] ?? 'ready'}',
      error: json['error']?.toString(),
    );
  }
}
