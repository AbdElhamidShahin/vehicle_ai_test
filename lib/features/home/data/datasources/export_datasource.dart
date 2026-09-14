import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/vehicle_result.dart';

class ExportDatasource {
  Future<void> exportVehicles(List<VehicleResult> vehicles) async {
    final rows = <List<String>>[
      [
        'رقم اللوحه',
        'نوع السياره',
        'العنوان',
        'خط العرض',
        'خط الطول',
        'رابط الخريطه',
        'التاريخ',
        'الوقت',
      ],
      ...vehicles.map(
            (v) => [
          v.plateNumber,
          v.vehicleType,
          v.address,
          '${v.latitude ?? ''}',
          '${v.longitude ?? ''}',
          v.mapLink,
          v.date,
          v.time,
        ],
      ),
    ];
    final csv = rows
        .map((r) => r.map((v) => '"${v.replaceAll('"', '""')}"').join(','))
        .join('\n');
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/vehicles_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    await File(path).writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    await Share.shareXFiles([
      XFile(path),
    ], text: 'تقرير سجلات السيارات ومواقعها');
  }
}
