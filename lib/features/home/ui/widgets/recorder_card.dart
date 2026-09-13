import 'package:flutter/material.dart';
import '../../logic/home_controller.dart';

class RecorderCard extends StatelessWidget {
  final HomeController controller;
  const RecorderCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final rec  = controller.isRecording;
    final proc = controller.isProcessing;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── أيقونة ─────────────────────────────────────────────────────
            Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(
                radius: 48,
                backgroundColor:
                rec ? Colors.red.shade100 : Colors.indigo.shade50,
                child: Icon(
                  rec ? Icons.mic : Icons.mic_none,
                  size: 48,
                  color: rec ? Colors.red : Colors.indigo,
                ),
              ),
              if (proc && rec)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle),
                  child: const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                ),
            ]),

            const SizedBox(height: 14),

            // ── الوقت / الحالة ──────────────────────────────────────────────
            Text(
              rec ? controller.timeFormatted : controller.status,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),

            // ── آخر نص من Groq ──────────────────────────────────────────────
            if (rec && controller.liveTranscript.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '📝 ${controller.liveTranscript}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.green.shade800),
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // ── عداد اللوحات ────────────────────────────────────────────────
            if (rec && controller.history.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  '🚗 ${controller.history.length} سيارة',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                // عدد اللي محتاجة مراجعة
                if (controller.history
                    .any((r) => r.status == 'needs_review'))
                  Text(
                    '⚠️ ${controller.history.where((r) => r.status == 'needs_review').length} تحتاج مراجعة',
                    style: TextStyle(
                        fontSize: 12, color: Colors.orange.shade700),
                  ),
              ]),
            ],

            const SizedBox(height: 20),

            // ── زر التسجيل ──────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed:
                rec ? controller.stopRecording : controller.startRecording,
                icon: Icon(rec ? Icons.stop_circle : Icons.mic),
                style: FilledButton.styleFrom(
                  backgroundColor: rec ? Colors.red.shade700 : null,
                ),
                label: Text(
                  rec ? 'إنهاء التسجيل' : 'ابدأ التسجيل الصوتي',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            if (proc && !rec) ...[
              const SizedBox(height: 16),
              const Row(children: [
                SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('جاري معالجة آخر جزء...'),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
