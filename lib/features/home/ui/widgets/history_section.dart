import 'package:flutter/material.dart';
import '../../data/models/vehicle_result.dart';
import '../../logic/home_controller.dart';

class HistorySection extends StatelessWidget {
  final HomeController controller;
  final void Function(VehicleResult) onEdit;
  const HistorySection({
    super.key,
    required this.controller,
    required this.onEdit,
  });
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'السجلات (${controller.history.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: controller.exportToExcel,
                icon: const Icon(Icons.table_chart, size: 18),
                label: const Text('تصدير Excel'),
              ),
            ],
          ),
          const Divider(),
          ...controller.history.map(
                (v) => _VehicleItem(
              item: v,
              controller: controller,
              onEdit: () => onEdit(v),
            ),
          ),
        ],
      ),
    ),
  );
}

class _VehicleItem extends StatelessWidget {
  final VehicleResult item;
  final HomeController controller;
  final VoidCallback onEdit;
  const _VehicleItem({
    required this.item,
    required this.controller,
    required this.onEdit,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      border: Border.all(color: Colors.grey.shade200),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.plateNumber.isEmpty
                    ? 'بدون رقم لوحة'
                    : 'لوحة: ${item.plateNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.indigo,
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  tooltip: 'تعديل السطر',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                  tooltip: 'حذف السطر',
                  onPressed: () => controller.deleteItem(item.id),
                ),
              ],
            ),
          ],
        ),
        Text(
          'نوع السيارة: ${item.vehicleType.isEmpty ? "—" : item.vehicleType}',
        ),
        Text('العنوان المستخرج: ${item.address.isEmpty ? "—" : item.address}'),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${item.date}  |  ${item.time}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (item.mapLink.isNotEmpty)
              InkWell(
                onTap: () async {
                  final ok = await controller.openMap(item.mapLink);
                  if (!ok && context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تعذر فتح رابط الخريطة')),
                    );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'فتح الخريطة (GPS)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
