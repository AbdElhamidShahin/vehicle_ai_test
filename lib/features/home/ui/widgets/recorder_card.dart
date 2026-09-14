import 'package:flutter/material.dart';
import '../../logic/home_controller.dart';

class RecorderCard extends StatelessWidget {
  final HomeController controller;
  const RecorderCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.isDownloading) return _buildDownloadCard();
    if (!controller.isModelReady) return _buildDownloadPrompt();
    return _buildRecorderCard();
  }

  // ── 1. بيحمّل الموديل ─────────────────────────────────────────────────────
  Widget _buildDownloadCard() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.cloud_download, size: 56, color: Colors.indigo),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل ${controller.downloadLabel}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: controller.downloadProgress),
            const SizedBox(height: 8),
            Text(
              '${(controller.downloadProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'لازم تحميل مرة واحدة بس — بعدها بيشتغل offline',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]),
        ),
      );

  // ── 2. لسه مش محمّل ───────────────────────────────────────────────────────
  Widget _buildDownloadPrompt() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.download_for_offline,
                size: 56, color: Colors.indigo.shade300),
            const SizedBox(height: 16),
            const Text(
              'الموديل غير محمّل',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'محتاج تحميل موديل whisper.cpp\n(466MB — مرة واحدة فقط)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: controller.downloadModel,
                icon: const Icon(Icons.download),
                label: const Text('تحميل الموديل', style: TextStyle(fontSize: 15)),
              ),
            ),
          ]),
        ),
      );

  // ── 3. جاهز للتسجيل ───────────────────────────────────────────────────────
  Widget _buildRecorderCard() {
    final rec  = controller.isRecording;
    final proc = controller.isProcessing;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // أيقونة
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
            if (proc)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.orange, shape: BoxShape.circle),
                child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
              ),
          ]),

          const SizedBox(height: 14),

          // الوقت أو الحالة
          Text(
            rec ? controller.timeFormatted : controller.status,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),

          // النص المؤقت (أثناء الكلام)
          if (rec && controller.partialTranscript.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                '✏️ ${controller.partialTranscript}',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                textDirection: TextDirection.rtl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // آخر نص نهائي
          if (rec && controller.liveTranscript.isNotEmpty) ...[
            const SizedBox(height: 6),
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
                style:
                    TextStyle(fontSize: 12, color: Colors.green.shade800),
                textDirection: TextDirection.rtl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // عداد اللوحات
          if (rec && controller.history.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('🚗 ${controller.history.length} سيارة',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w700)),
              if (controller.history
                  .any((r) => r.status == 'needs_review')) ...[
                const SizedBox(width: 12),
                Text(
                  '⚠️ ${controller.history.where((r) => r.status == 'needs_review').length} مراجعة',
                  style: TextStyle(
                      fontSize: 12, color: Colors.orange.shade700),
                ),
              ],
            ]),
          ],

          const SizedBox(height: 20),

          // زر التسجيل
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed:
                  rec ? controller.stopRecording : controller.startRecording,
              icon: Icon(rec ? Icons.stop_circle : Icons.mic),
              style: FilledButton.styleFrom(
                  backgroundColor: rec ? Colors.red.shade700 : null),
              label: Text(
                rec ? 'إنهاء التسجيل' : 'ابدأ التسجيل (offline)',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),

          // Badge offline
          if (!rec) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.offline_bolt,
                      size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text('STT يشتغل offline',
                      style: TextStyle(
                          fontSize: 11, color: Colors.green.shade700)),
                ]),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
