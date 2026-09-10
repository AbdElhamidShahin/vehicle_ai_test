import 'package:flutter/material.dart';
import '../../data/models/vehicle_result.dart';
import '../../logic/home_controller.dart';

Future<void> showEditVehicleDialog(
  BuildContext context, {
  required HomeController controller,
  required VehicleResult item,
}) async {
  final plate = TextEditingController(text: item.plateNumber),
      type = TextEditingController(text: item.vehicleType),
      address = TextEditingController(text: item.address);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تعديل بيانات السجل'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: plate,
              decoration: const InputDecoration(labelText: 'رقم اللوحة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: type,
              decoration: const InputDecoration(labelText: 'نوع السيارة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            controller.updateItem(
              item,
              plateNumber: plate.text,
              vehicleType: type.text,
              address: address.text,
            );
            Navigator.pop(ctx);
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  plate.dispose();
  type.dispose();
  address.dispose();
}
