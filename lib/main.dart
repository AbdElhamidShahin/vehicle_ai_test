import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // حزمة لفتح الروابط

// ─────────────────────────────────────────────────────────────────────────────
// Gemini API key & Model Configuration
// ─────────────────────────────────────────────────────────────────────────────
const String _geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: '',
);

const String _geminiModel = 'gemini-3.5-flash-lite';
const String _geminiEndpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$_geminiModel:generateContent';

void main() {
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
  final String id;
  String transcript;
  String plateNumber;
  String vehicleType;
  String address;
  String mapLink;
  final String date;
  final String time;
  String status;
  String? error;

  VehicleResult({
    required this.id,
    required this.transcript,
    required this.plateNumber,
    required this.vehicleType,
    required this.address,
    required this.mapLink,
    required this.date,
    required this.time,
    required this.status,
    this.error,
  });

  factory VehicleResult.fromJson(
      Map<String, dynamic> json, String date, String time, String gpsMapLink) {
    final address = '${json['address'] ?? ''}';

    String finalMapLink = gpsMapLink;
    if (finalMapLink.isEmpty && address.isNotEmpty) {
      final encodedAddress = Uri.encodeComponent(address);
      finalMapLink = 'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
    }

    return VehicleResult(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      transcript: '${json['transcript'] ?? ''}',
      plateNumber: '${json['plate_number'] ?? ''}',
      vehicleType: '${json['vehicle_type'] ?? ''}',
      address: address,
      mapLink: finalMapLink,
      date: date,
      time: time,
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
      title: 'Vehicle AI System',
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
  final List<VehicleResult> _history = [];

  String get _timeFormatted {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── جلب الموقع الجغرافي الحالي (GPS) ──────────────────────────────────
  Future<String> _getCurrentLocationMapLink() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return '';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return '';
      }

      if (permission == LocationPermission.deniedForever) return '';

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
    } catch (_) {
      return '';
    }
  }

  // ── فتح رابط الخريطة ──────────────────────────────────────────────────────
  Future<void> _openMapLink(String urlString) async {
    if (urlString.isEmpty) {
      setState(() => _status = 'رابط الخريطة غير متوفر');
      return;
    }
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        setState(() => _status = 'تعذر فتح رابط الخريطة');
      }
    } catch (e) {
      setState(() => _status = 'خطأ في فتح الرابط: $e');
    }
  }

  // ── recording ──────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_geminiApiKey.isEmpty) {
      setState(() => _status = 'مفتاح Gemini غير موجود');
      return;
    }

    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _status = 'اسمح للتطبيق باستخدام الميكروفون');
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/vehicle_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
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
        _audioPath = path;
        _status = 'جاري التسجيل وتحديد الموقع...';
      });
    } catch (e) {
      setState(() => _status = 'تعذر بدء التسجيل: $e');
    }
  }

  Future<void> _stopAndProcessRecording() async {
    try {
      _timer?.cancel();
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _audioPath = path ?? _audioPath;
      });

      if (_audioPath != null) {
        await _processRecording();
      }
    } catch (e) {
      setState(() => _status = 'تعذر إيقاف التسجيل: $e');
    }
  }

  // ── Gemini processing & GPS ────────────────────────────────────────────────

  Future<void> _processRecording() async {
    final path = _audioPath;
    if (path == null || !File(path).existsSync()) {
      setState(() => _status = 'لا يوجد ملف صوتي للمعالجة');
      return;
    }

    setState(() {
      _processing = true;
      _status = 'جاري جلب الموقع الجغرافي والتحليل بالذكاء الاصطناعي...';
    });

    try {
      final gpsMapLink = await _getCurrentLocationMapLink();

      final audioBytes = await File(path).readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

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
أنت نظام ذكاء اصطناعي متطور جداً ومتخصص بدقة في استخراج وتفريغ بيانات تسجيل السيارات من التسجيلات الصوتية باللهجة المصرية.
استمع بدقة واستخرج البيانات التالية بدقة تامة:
1. النص المسموع كاملاً (transcript)
2. رقم اللوحة (plate_number)
3. نوع المركبة (vehicle_type) مثل: ملاكي، نقل، نص نقل، موتوسيكل، إلخ.
4. العنوان أو المكان المنطوق (address)

أجب بـ JSON فقط بهذا الشكل بدون أي نص إضافي أو Markdown:
{"transcript": "...", "plate_number": "...", "vehicle_type": "...", "address": "..."}
'''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.0,
          'responseMimeType': 'application/json',
        },
      });

      final response = await http.post(
        Uri.parse('$_geminiEndpoint?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(minutes: 3));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gemini API error ${response.statusCode}');
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = responseJson['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('لم يتم استلام رد من الذكاء الاصطناعي');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final rawText = (parts?.isNotEmpty == true ? parts![0]['text'] : null) as String?;

      var cleanText = rawText?.trim() ?? '{}';
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll(RegExp(r'^```json?\s*'), '');
        cleanText = cleanText.replaceAll(RegExp(r'```\s*$'), '');
        cleanText = cleanText.trim();
      }

      Map<String, dynamic> parsed = {};
      try {
        parsed = jsonDecode(cleanText) as Map<String, dynamic>;
      } catch (_) {
        parsed = {'transcript': rawText ?? '', 'plate_number': '', 'vehicle_type': '', 'address': ''};
      }

      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      final result = VehicleResult.fromJson(parsed, dateStr, timeStr, gpsMapLink);
      result.status = result.plateNumber.isNotEmpty ? 'ok' : 'needs_review';
      result.error = result.plateNumber.isEmpty ? 'لم يتم التعرف على رقم اللوحة' : null;

      setState(() {
        _history.insert(0, result);
        _status = 'تمت المعالجة وتحديد الموقع بنجاح ✓';
      });

      await File(path).delete().catchError((_) {});
      _audioPath = null;
    } on TimeoutException {
      setState(() => _status = 'انتهت مهلة الاتصال');
    } catch (e) {
      setState(() => _status = 'فشلت المعالجة: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ── التعديل والحذف وتصدير الإكسل ──────────────────────────────────────────

  void _deleteItem(String id) {
    setState(() {
      _history.removeWhere((element) => element.id == id);
      _status = 'تم حذف السطر';
    });
  }

  void _editItem(VehicleResult item) {
    final plateController = TextEditingController(text: item.plateNumber);
    final typeController = TextEditingController(text: item.vehicleType);
    final addressController = TextEditingController(text: item.address);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل بيانات السجل'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: plateController, decoration: const InputDecoration(labelText: 'رقم اللوحة')),
              const SizedBox(height: 10),
              TextField(controller: typeController, decoration: const InputDecoration(labelText: 'نوع السيارة')),
              const SizedBox(height: 10),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'العنوان')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              setState(() {
                item.plateNumber = plateController.text;
                item.vehicleType = typeController.text;
                item.address = addressController.text;
                if (item.address.isNotEmpty && !item.address.startsWith('http')) {
                  final encodedAddress = Uri.encodeComponent(item.address);
                  item.mapLink = '[https://www.google.com/maps/search/?api=1&query=$encodedAddress](https://www.google.com/maps/search/?api=1&query=$encodedAddress)';
                }
                _status = 'تم التعديل بنجاح';
              });
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    if (_history.isEmpty) {
      setState(() => _status = 'لا توجد بيانات للتصدير');
      return;
    }

    try {
      List<List<String>> rows = [
        ['رقم اللوحه', 'نوع السياره', 'العنوان', 'رابط الخريطه', 'التاريخ', 'الوقت']
      ];

      for (var h in _history) {
        rows.add([
          '"${h.plateNumber}"',
          '"${h.vehicleType}"',
          '"${h.address}"',
          '"${h.mapLink}"',
          '"${h.date}"',
          '"${h.time}"',
        ]);
      }

      String csvData = rows.map((row) => row.join(',')).join('\n');
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/vehicles_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csvData)]);
      await Share.shareXFiles([XFile(path)], text: 'تقرير سجلات السيارات ومواقعها');
      setState(() => _status = 'تم التصدير بنجاح');
    } catch (e) {
      setState(() => _status = 'فشل التصدير: $e');
    }
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
          title: const Text('تسجيل السيارات والموقع الجغرافي'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          actions: [
            if (_history.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.file_download),
                tooltip: 'تصدير إلى Excel',
                onPressed: _exportToExcel,
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildRecorderCard(),
              const SizedBox(height: 16),
              if (_history.isNotEmpty) _buildHistoryCard(),
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
              backgroundColor: _recording ? Colors.red.shade100 : Colors.indigo.shade50,
              child: Icon(
                _recording ? Icons.mic : Icons.mic_none,
                size: 48,
                color: _recording ? Colors.red : Colors.indigo,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _recording ? _timeFormatted : _status,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _processing
                    ? null
                    : (_recording ? _stopAndProcessRecording : _startRecording),
                icon: Icon(_recording ? Icons.check_circle : Icons.mic),
                style: FilledButton.styleFrom(
                  backgroundColor: _recording ? Colors.green.shade700 : null,
                ),
                label: Text(_recording ? 'إنهاء التسجيل وجلب الموقع فوراً' : 'ابدأ التسجيل الصوتي'),
              ),
            ),
            if (_processing) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
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
                  'السجلات (${_history.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _exportToExcel,
                  icon: const Icon(Icons.table_chart, size: 18),
                  label: const Text('تصدير Excel'),
                ),
              ],
            ),
            const Divider(),
            ..._history.map((r) => Container(
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
                      Text(
                        r.plateNumber.isEmpty ? 'بدون رقم لوحة' : 'لوحة: ${r.plateNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                            tooltip: 'تعديل السطر',
                            onPressed: () => _editItem(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            tooltip: 'حذف السطر',
                            onPressed: () => _deleteItem(r.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text('نوع السيارة: ${r.vehicleType.isEmpty ? "—" : r.vehicleType}'),
                  Text('العنوان المستخرج: ${r.address.isEmpty ? "—" : r.address}'),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${r.date}  |  ${r.time}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (r.mapLink.isNotEmpty)
                        InkWell(
                          onTap: () => _openMapLink(r.mapLink),
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
            )),
          ],
        ),
      ),
    );
  }
}