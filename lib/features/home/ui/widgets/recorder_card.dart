import 'package:flutter/material.dart';
import '../../logic/home_controller.dart';

class RecorderCard extends StatelessWidget {
  final HomeController controller;
  const RecorderCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final recording = controller.isRecording;
    final processing = controller.isProcessing;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── أيقونة التسجيل ──────────────────────────────────────────
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor:
                  recording ? Colors.red.shade100 : Colors.indigo.shade50,
                  child: Icon(
                    recording ? Icons.mic : Icons.mic_none,
                    size: 48,
                    color: recording ? Colors.red : Colors.indigo,
                  ),
                ),
                // مؤشر صغير لما بيتعالج chunk في الخلفية
                if (processing && recording)
                  Positioned(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // ── الوقت أو الحالة ─────────────────────────────────────────
            Text(
              recording ? controller.timeFormatted : controller.status,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),

            // ── آخر نص ظهر من Groq ─────────────────────────────────────
            if (recording && controller.liveTranscript.isNotEmpty) ...[
              const SizedBox(height: 8),
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
                      fontSize: 13, color: Colors.green.shade800),
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // ── عدد العربيات أثناء التسجيل ─────────────────────────────
            if (recording && controller.history.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '🚗 ${controller.history.length} سيارة تم تسجيلها',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.indigo.shade700,
                    fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 20),

            // ── زر التسجيل ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: recording
                    ? controller.stopRecording
                    : controller.startRecording,
                icon: Icon(recording ? Icons.stop_circle : Icons.mic),
                style: FilledButton.styleFrom(
                  backgroundColor:
                  recording ? Colors.red.shade700 : null,
                ),
                label: Text(
                  recording ? 'إنهاء التسجيل' : 'ابدأ التسجيل الصوتي',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            // ── مؤشر المعالجة في الخلفية ────────────────────────────────
            if (processing && !recording) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('جاري معالجة آخر جزء...'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
