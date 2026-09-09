import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Gemini API key — passed at build time:
//   flutter run  --dart-define=GEMINI_API_KEY=AIza...
//   flutter build apk --dart-define=GEMINI_API_KEY=AIza...
//


// IMPORTANT: String.fromEnvironment MUST be used in a `const` expression
// so that Dart bakes the value in at compile time (AOT / tree-shaking).
// A non-const call always returns the default ''.
// ─────────────────────────────────────────────────────────────────────────────
const String _geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: '',
);
// Gemini REST endpoint (no extra SDK needed — plain HTTP).
const String _geminiModel = 'gemini-3.5-flash-lite';
const String _geminiEndpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$_geminiModel:generateContent';

void main() {
  // Diagnostic — never prints the key value, only whether it is present.
  debugPrint(
    '[VehicleAI] Gemini key present: ${_geminiApiKey.isNotEmpty}, '
        'length: ${_geminiApiKey.length}',
  );
  runApp(const VehicleAiTestApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class VehicleResult {
  final String transcript;
  final String plateNumber;
  final String vehicleType;
  final String address;
  final String status;
  final String? error;

  const VehicleResult({
    required this.transcript,
    required this.plateNumber,
    required this.vehicleType,
    required this.address,
    required this.status,
    this.error,
  });

  factory VehicleResult.fromJson(Map<String, dynamic> json) {
    return VehicleResult(
      transcript: '${json['transcript'] ?? ''}',
      plateNumber: '${json['plate_number'] ?? ''}',
      vehicleType: '${json['vehicle_type'] ?? ''}',
      address: '${json['address'] ?? ''}',
      status: '${json['status'] ?? 'ready'}',
      error: json['error']?.toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App
// ─────────────────────────────────────────────────────────────────────────────

class VehicleAiTestApp extends StatelessWidget {
  const VehicleAiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vehicle AI Test',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xfff6f7fb),
      ),
      home: const VehicleTestPage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class VehicleTestPage extends StatefulWidget {
  const VehicleTestPage({super.key});

  @override
  State<VehicleTestPage> createState() => _VehicleTestPageState();
}

class _VehicleTestPageState extends State<VehicleTestPage> {
  final AudioRecorder _recorder = AudioRecorder();

  Timer? _timer;
  int _seconds = 0;
  bool _recording = false;
  bool _processing = false;
  String _status = 'جاهز للتسجيل';
  String? _audioPath;
  VehicleResult? _result;
  final List<VehicleResult> _history = [];

  // ── helpers ────────────────────────────────────────────────────────────────

  String get _time {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── recording ──────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    // Guard: key must be present before we even bother recording.
    if (_geminiApiKey.isEmpty) {
      setState(() =>
      _status = 'مفتاح Gemini غير موجود — أعد البناء مع --dart-define=GEMINI_API_KEY=...');
      return;
    }

    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _status = 'اسمح للتطبيق باستخدام الميكروفون');
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/vehicle_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000, // 16 kHz — enough for speech, smaller file
          bitRate: 64000,
        ),
        path: path,
      );

      _timer?.cancel();
      _seconds = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });

      setState(() {
        _recording = true;
        _processing = false;
        _result = null;
        _audioPath = path;
        _status = 'جاري التسجيل...';
      });
    } catch (e) {
      setState(() => _status = 'تعذر بدء التسجيل: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _audioPath = path ?? _audioPath;
        _status =
        path == null ? 'لم يتم حفظ التسجيل' : 'تم التسجيل — جاهز للمعالجة';
      });
    } catch (e) {
      setState(() => _status = 'تعذر إيقاف التسجيل: $e');
    }
  }

  // ── Gemini processing ──────────────────────────────────────────────────────

  Future<void> _processRecording() async {
    final path = _audioPath;
    if (path == null || !File(path).existsSync()) {
      setState(() => _status = 'سجل صوت أولًا');
      return;
    }

    if (_geminiApiKey.isEmpty) {
      setState(() =>
      _status = 'مفتاح Gemini غير موجود — أعد البناء مع --dart-define=GEMINI_API_KEY=...');
      return;
    }

    setState(() {
      _processing = true;
      _status = 'جاري إرسال الصوت إلى Gemini...';
      _result = null;
    });

    try {
      // 1. Read audio bytes and encode as base64.
      final audioBytes = await File(path).readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      debugPrint(
          '[VehicleAI] Audio size: ${audioBytes.length} bytes, sending to Gemini...');

      // 2. Build Gemini request.
      //    We send the audio directly — Gemini 2.5 flash supports inline audio.
      //    The prompt asks for Arabic transcription + structured extraction.
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': 'audio/mp4',
                  'data': audioBase64,
                }
              },
              {
                'text': '''
أنت نظام لاستخراج بيانات تسجيل السيارات من تسجيل صوتي بالعامية المصرية.

استمع للتسجيل الصوتي واستخرج منه:
1. النص المسموع كاملاً (transcript)
2. رقم اللوحة (plate_number)
3. نوع المركبة (vehicle_type) مثل: ملاكي، نقل، موتوسيكل، توك توك، إلخ
4. العنوان أو المكان (address)

أجب بـ JSON فقط بهذا الشكل بدون أي نص إضافي أو Markdown:
{"transcript": "...", "plate_number": "...", "vehicle_type": "...", "address": "..."}

إذا لم تتمكن من استخراج أي معلومة، اجعل قيمتها نصاً فارغاً "".
'''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        },
      });

      // 3. POST to Gemini REST API.
      final response = await http
          .post(
        Uri.parse('$_geminiEndpoint?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(const Duration(minutes: 3));

      debugPrint('[VehicleAI] Gemini HTTP status: ${response.statusCode}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'Gemini API error ${response.statusCode}: ${response.body}');
      }

      // 4. Parse response.
      final responseJson =
      jsonDecode(response.body) as Map<String, dynamic>;

      final candidates =
      responseJson['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini returned no candidates: ${response.body}');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final rawText =
      (parts?.isNotEmpty == true ? parts![0]['text'] : null) as String?;

      if (rawText == null || rawText.isEmpty) {
        throw Exception('Gemini returned empty text');
      }

      debugPrint('[VehicleAI] Gemini raw text length: ${rawText.length}');

      // 5. Strip any accidental markdown fences.
      var cleanText = rawText.trim();
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll(RegExp(r'^```json?\s*'), '');
        cleanText = cleanText.replaceAll(RegExp(r'```\s*$'), '');
        cleanText = cleanText.trim();
      }

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(cleanText) as Map<String, dynamic>;
      } catch (_) {
        // Fallback: put the raw text in transcript.
        parsed = {
          'transcript': rawText,
          'plate_number': '',
          'vehicle_type': '',
          'address': '',
        };
      }

      final transcript = parsed['transcript']?.toString() ?? '';
      final plateNumber = parsed['plate_number']?.toString() ?? '';

      final result = VehicleResult(
        transcript: transcript,
        plateNumber: plateNumber,
        vehicleType: parsed['vehicle_type']?.toString() ?? '',
        address: parsed['address']?.toString() ?? '',
        status: plateNumber.isNotEmpty ? 'ok' : 'needs_review',
        error: plateNumber.isEmpty ? 'لم يتم التعرف على رقم اللوحة' : null,
      );

      setState(() {
        _result = result;
        _history.insert(0, result);
        _status = result.status == 'needs_review'
            ? 'النتيجة تحتاج مراجعة'
            : 'تمت المعالجة بنجاح ✓';
      });

      // Delete temp audio after success.
      await File(path).delete().catchError((_) {});
      _audioPath = null;
    } on TimeoutException {
      setState(() => _status = 'انتهت مهلة الاتصال بـ Gemini (3 دقائق)');
    } catch (e) {
      debugPrint('[VehicleAI] Error: $e');
      setState(() => _status = 'فشلت المعالجة: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _deleteResult() {
    setState(() {
      _result = null;
      _status = 'تم حذف النتيجة من الاختبار';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اختبار تسجيل السيارات بالذكاء الاصطناعي'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // Key warning banner
              if (_geminiApiKey.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'مفتاح Gemini غير موجود.\n'
                              'شغّل التطبيق بـ:\n'
                              'flutter run --dart-define=GEMINI_API_KEY=AIza...',
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildRecorderCard(),
              const SizedBox(height: 14),
              if (_result != null) _buildResultCard(_result!),
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildHistoryCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecorderCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: _recording
                  ? Colors.red.shade100
                  : Colors.indigo.shade50,
              child: Icon(
                _recording ? Icons.mic : Icons.mic_none,
                size: 48,
                color: _recording ? Colors.red : Colors.indigo,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _recording ? _time : _status,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _processing
                    ? null
                    : (_recording ? _stopRecording : _startRecording),
                icon: Icon(_recording ? Icons.stop : Icons.mic),
                label: Text(_recording ? 'إيقاف التسجيل' : 'ابدأ التسجيل'),
              ),
            ),
            const SizedBox(height: 10),
            if (!_recording && _audioPath != null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _processRecording,
                  icon: _processing
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                      _processing ? 'جاري المعالجة...' : 'معالجة بـ Gemini AI'),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'جرّب أن تقول: «مرس 1234 نقل جراج واحد»',
              style: TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(VehicleResult r) {
    final needsReview = r.status == 'needs_review';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  needsReview ? Icons.warning_amber : Icons.check_circle,
                  color: needsReview ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  needsReview ? 'تحتاج مراجعة' : 'النتيجة',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 26),
            _field('النص المسموع', r.transcript),
            _field('رقم اللوحة', r.plateNumber),
            _field('نوع المركبة', r.vehicleType),
            _field('العنوان / المكان', r.address),
            if (r.error != null && r.error!.isNotEmpty)
              _field('ملاحظة', r.error!),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _deleteResult,
              icon: const Icon(Icons.delete_outline),
              label: const Text('حذف نتيجة الاختبار'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '—' : value,
            style:
            const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'سجل الاختبارات (${_history.length})',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._history.take(10).map(
                  (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.directions_car_outlined),
                title: Text(
                    r.plateNumber.isEmpty ? 'بدون لوحة' : r.plateNumber),
                subtitle: Text('${r.vehicleType} • ${r.address}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}