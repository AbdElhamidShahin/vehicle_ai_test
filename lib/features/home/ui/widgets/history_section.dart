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
                        fontSize: 18, fontWeight: FontWeight.bold),
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
  Widget build(BuildContext context) {
    final needsReview = item.status == 'needs_review';
    final lowConf     = item.confidence == 'low';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: needsReview ? Colors.orange.shade50 : Colors.grey.shade50,
        border: Border.all(
          color: needsReview ? Colors.orange.shade300 : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      item.plateNumber.isEmpty
                          ? 'بدون رقم لوحة'
                          : item.plateNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: needsReview
                            ? Colors.orange.shade800
                            : Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // badge: needs_review
                    if (needsReview)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('⚠️ مراجعة',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade900)),
                      ),
                    // badge: low confidence
                    if (lowConf && !needsReview) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('دقة منخفضة',
                            style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ),
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                  tooltip: 'تعديل السطر',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.red),
                  tooltip: 'حذف السطر',
                  onPressed: () => controller.deleteItem(item.id),
                ),
              ]),
            ],
          ),
          Text(
              'نوع السيارة: ${item.vehicleType.isEmpty ? "—" : item.vehicleType}'),
          Text(
              'العنوان: ${item.address.isEmpty ? "—" : item.address}'),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.date}  |  ${item.time}',
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (item.mapLink.isNotEmpty)
                InkWell(
                  onTap: () async {
                    final ok = await controller.openMap(item.mapLink);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('تعذر فتح رابط الخريطة')),
                      );
                    }
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.map, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'فتح الخريطة',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
