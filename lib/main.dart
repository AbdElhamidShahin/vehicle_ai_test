import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

void main() {
  runApp(const VehicleAiTestApp());
}

class VehicleResult {
  final String id;
  String transcript;
  final String date;
  final String time;
  String mapLink;

  VehicleResult({
    required this.id,
    required this.transcript,
    required this.date,
    required this.time,
    required this.mapLink,
  });
}

class VehicleAiTestApp extends StatelessWidget {
  const VehicleAiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vehicle AI Live',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xfff6f7fb),
      ),
      home: const VehicleTestPage(),
    );
  }
}

class VehicleTestPage extends StatefulWidget {
  const VehicleTestPage({super.key});

  @override
  State<VehicleTestPage> createState() => _VehicleTestPageState();
}

class _VehicleTestPageState extends State<VehicleTestPage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _liveText = '';
  String _status = 'جاهز للتسجيل المباشر';
  final List<VehicleResult> _history = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  // ── تنظيف وتنسيق النص: تحويل الكلمات لأرقام وحروف وترتيب اللوحات في أسطر جديدة ──
  String _formatPlateText(String input) {
    if (input.isEmpty) return '';

    String text = input;

    // 1. تحويل الكلمات الشائعة للأرقام لو مكتوبة بالكلمات
    final Map<String, String> wordToDigit = {
      'صفر': '0', 'واحد': '1', 'اتنين': '2', 'ثلاثة': '3', 'أربعة': '4',
      'خمسة': '5', 'ستة': '6', 'سبعة': '7', 'ثمانية': '8', 'تسعة': '9',
      'إتنين': '2', 'التنين': '2'
    };

    wordToDigit.forEach((word, digit) {
      text = text.replaceAll(word, digit);
    });

    // 2. تنسيق الأسطر: جعل كل لوحة جديدة (حروف يتبعها أرقام) تبدأ في سطر جديد بمسافة
    // مثال: "منس 1234" تصبح في سطر مستقل
    text = text.replaceAllMapped(
        RegExp(r'([أ-ي\s]{2,})\s*(\d{2,})'),
            (match) => '\n🚗 ${match.group(1)?.replaceAll(' ', ' - ').trim()} : ${match.group(2)}'
    );

    return text.trim();
  }

  // ── بدء الاستماع المباشر (Live) ──────────────────────────────────────────
  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('Status: $status'),
      onError: (error) => setState(() => _status = 'خطأ: ${error.errorMsg}'),
    );

    if (available) {
      setState(() {
        _isListening = true;
        _status = 'جاري الاستماع والكتابة الحية...';
      });

      _speech.listen(
        localeId: 'ar_EG', // اللهجة العربية المصرية لتفهم اللوحات بدقة
        onResult: (result) {
          setState(() {
            // يظهر الكلام مباشرة على الشاشة أول بأول وأنت بتكلم!
            _liveText = _formatPlateText(result.recognizedWords);
          });
        },
      );
    } else {
      setState(() => _status = 'تعذر تشغيل الميكروفون للتعرف الصوتي');
    }
  }

  // ── إيقاف الاستماع وحفظ النتيجة في السجلات ──────────────────────────────
  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _status = 'تم حفظ التسجيل بنجاح';
    });

    if (_liveText.isNotEmpty) {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      // جلب موقع GPS الخريطة
      String gpsMapLink = await _getCurrentLocationMapLink();

      setState(() {
        _history.insert(
          0,
          VehicleResult(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            transcript: _liveText,
            date: dateStr,
            time: timeStr,
            mapLink: gpsMapLink,
          ),
        );
        _liveText = ''; // تفريغ الصندوق الحي لتسجيل جديد
      });
    }
  }

  Future<String> _getCurrentLocationMapLink() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return '';
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return '';
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _openMap(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسجيل اللوحات الفوري (Live)'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // كارد الميكروفون والشاشة السوداء الحية
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: _isListening ? Colors.red.shade100 : Colors.indigo.shade50,
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          size: 36,
                          color: _isListening ? Colors.red : Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),

                      // صندوق الكتابة الحية اللحظية أثناء الكلام
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 120, maxHeight: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _liveText.isEmpty ? '🎙️ تحدث الآن (سترى الحروف والأرقام تظهر هنا فوراً سطرًا بسطر)...' : _liveText,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 16,
                              height: 1.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _isListening ? _stopListening : _startListening,
                          icon: Icon(_isListening ? Icons.stop : Icons.mic),
                          style: FilledButton.styleFrom(
                            backgroundColor: _isListening ? Colors.red.shade700 : Colors.indigo,
                          ),
                          label: Text(_isListening ? 'إنهاء وحفظ التسجيل' : 'ابدأ التسجيل الفوري'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // السجلات المحفوظة
              if (_history.isNotEmpty) ...[
                const Text('السجلات المحفوظة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                ..._history.map((r) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.transcript, style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${r.date} | ${r.time}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (r.mapLink.isNotEmpty)
                            InkWell(
                              onTap: () => _openMap(r.mapLink),
                              child: const Text('فتح الخريطة (GPS)', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}