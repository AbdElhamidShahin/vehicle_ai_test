import 'package:flutter/material.dart';
import '../../logic/home_controller.dart';
import '../widgets/edit_vehicle_dialog.dart';
import '../widgets/history_section.dart';
import '../widgets/recorder_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController c;
  @override
  void initState() {
    super.initState();
    c = HomeController()..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل السيارات والموقع الجغرافي'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          if (c.history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.file_download),
              tooltip: 'تصدير إلى Excel',
              onPressed: c.exportToExcel,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RecorderCard(controller: c),
            const SizedBox(height: 16),
            if (c.history.isNotEmpty)
              HistorySection(
                controller: c,
                onEdit: (v) =>
                    showEditVehicleDialog(context, controller: c, item: v),
              ),
          ],
        ),
      ),
    ),
  );
  @override
  void dispose() {
    c.removeListener(_refresh);
    c.dispose();
    super.dispose();
  }
}
