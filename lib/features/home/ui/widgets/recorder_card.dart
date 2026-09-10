import 'package:flutter/material.dart';
import '../../logic/home_controller.dart';

class RecorderCard extends StatelessWidget {
  final HomeController controller;
  const RecorderCard({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final recording = controller.isRecording;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: recording
                  ? Colors.red.shade100
                  : Colors.indigo.shade50,
              child: Icon(
                recording ? Icons.mic : Icons.mic_none,
                size: 48,
                color: recording ? Colors.red : Colors.indigo,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              recording ? controller.timeFormatted : controller.status,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: controller.isProcessing
                    ? null
                    : (recording
                          ? controller.stopAndProcessRecording
                          : controller.startRecording),
                icon: Icon(recording ? Icons.check_circle : Icons.mic),
                style: FilledButton.styleFrom(
                  backgroundColor: recording ? Colors.green.shade700 : null,
                ),
                label: Text(
                  recording
                      ? 'إنهاء التسجيل وجلب الموقع فوراً'
                      : 'ابدأ التسجيل الصوتي',
                ),
              ),
            ),
            if (controller.isProcessing) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
