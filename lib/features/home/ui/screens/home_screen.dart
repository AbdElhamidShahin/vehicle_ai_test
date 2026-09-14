import 'package:flutter/material.dart';
import '../../data/models/vehicle_result.dart';
import '../../logic/home_controller.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// HomeScreen — UI يظهر اللوحات فور ما تتعرف عليها
/// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _c;

  @override
  void initState() {
    super.initState();
    _c = HomeController()..addListener(_rebuild);
  }

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _c.removeListener(_rebuild);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff4f6fb),
        appBar: AppBar(
          title: const Text('تسجيل السيارات — Live'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RecorderCard(c: _c),
              const SizedBox(height: 12),
              if (_c.history.isNotEmpty) _HistoryCard(c: _c),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recorder Card
// ─────────────────────────────────────────────────────────────────────────────
class _RecorderCard extends StatelessWidget {
  const _RecorderCard({required this.c});
  final HomeController c;

  @override
  Widget build(BuildContext context) {
    final rec = c.isRecording;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [

          // ── أيقونة الميكروفون ─────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rec ? Colors.red.shade100 : Colors.indigo.shade50,
            ),
            child: Icon(
              rec ? Icons.mic : Icons.mic_none,
              size: 52,
              color: rec ? Colors.red : Colors.indigo,
            ),
          ),

          const SizedBox(height: 14),

          // ── وقت / حالة ───────────────────────────────────────────────────
          Text(
            rec ? c.timeFormatted : c.status,
            style: TextStyle(
              fontSize: rec ? 30 : 15,
              fontWeight: FontWeight.bold,
              color: rec ? Colors.red : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),

          // ── نص interim (يظهر وأنت بتتكلم) ───────────────────────────────
          if (rec && c.liveText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                c.liveText,
                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // ── عدد اللوحات المسجلة أثناء التسجيل ───────────────────────────
          if (rec && c.history.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '🚗 ${c.history.length} لوحة تم تسجيلها',
              style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.w600),
            ),
          ],

          const SizedBox(height: 20),

          // ── زر التسجيل ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: rec ? c.stopRecording : c.startRecording,
              icon: Icon(rec ? Icons.stop : Icons.mic),
              label: Text(rec ? 'إيقاف التسجيل' : 'ابدأ التسجيل'),
              style: FilledButton.styleFrom(
                backgroundColor: rec ? Colors.red.shade700 : null,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History Card
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.c});
  final HomeController c;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اللوحات المسجلة (${c.history.length})',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            ...c.history.map((v) => _PlateRow(item: v, c: c)),
          ],
        ),
      ),
    );
  }
}

class _PlateRow extends StatelessWidget {
  const _PlateRow({required this.item, required this.c});
  final VehicleResult  item;
  final HomeController c;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        border: Border.all(color: Colors.indigo.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // ── رقم اللوحة ─────────────────────────────────────────────────
          Expanded(
            child: Text(
              item.plateNumber,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // ── وقت ────────────────────────────────────────────────────────
          Text(
            item.time,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),

          // ── حذف ────────────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => c.deleteItem(item.id),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}