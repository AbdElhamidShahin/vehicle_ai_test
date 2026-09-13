// lib/features/home/data/repositories/vehicle_repository.dart
//
// ✅ الإصلاحات:
//   1. plateStream بقى StreamController حقيقي بدل async* generator
//      (async* generator كان بيعمل stream جديد كل مرة بتعمل get)
//   2. الاشتراك في deepgram.onTranscript بيتعمل مرة واحدة في initialize()
//   3. Buffer logic مصلوح: interim بيتراكم في _buf، الـ validation بيتطبق على speechFinal فقط
//   4. أضفنا كلمات اللهجة المصرية الشائعة في القاموس

import 'dart:async';

import '../../../../core/ai/DeepgramLiveService.dart';
import '../models/vehicle_result.dart';

class VehicleRepository {
  VehicleRepository({required this.deepgram});

  final DeepgramLiveService deepgram;

  // ✅ StreamController حقيقي — مش async* generator
  final _plateCtrl = StreamController<VehicleResult>.broadcast();

  /// اشترك هنا لاستقبال اللوحات المكتملة
  Stream<VehicleResult> get plateStream => _plateCtrl.stream;

  StreamSubscription<DeepgramTranscript>? _transcriptSub;

  // ── Buffer ────────────────────────────────────────────────────────────────
  // بنجمع النص حتى يجي speechFinal (أقوى إشارة من Deepgram إن الكلام خلص)
  final StringBuffer _buf = StringBuffer();

  // ── GPS (اختياري) ─────────────────────────────────────────────────────────
  double? latitude;
  double? longitude;

  // ─────────────────────────────────────────────────────────────────────────
  /// ✅ لازم تتنادى مرة واحدة بعد ما DeepgramLiveService.start() يشتغل
  void initialize() {
    _transcriptSub?.cancel();

    _transcriptSub = deepgram.onTranscript.listen((t) {
      if (t.isFinal) {
        // ✅ بنجمع الـ final text في الـ buffer
        if (_buf.isNotEmpty) _buf.write(' ');
        _buf.write(t.text);

        // ✅ لو Deepgram قال speechFinal → حاول تستخرج اللوحة دلوقتي
        if (t.speechFinal) {
          _tryFlushBuffer();
        }
      }
      // الـ interim مش بنحتاجه هنا — HomeController بيتعامل معاه للـ UI
    });
  }

  /// ✅ حاول flush الـ buffer واستخراج لوحة منه
  void _tryFlushBuffer() {
    final raw = _buf.toString().trim();
    if (raw.isEmpty) return;

    final result = _tryExtractPlate(raw);
    if (result != null) {
      _buf.clear();
      _plateCtrl.add(result);
    }
    // لو مش مكتمل → نكمل نجمع في الـ buffer للـ speechFinal الجاي
  }

  // ─────────────────────────────────────────────────────────────────────────
  VehicleResult? _tryExtractPlate(String raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return null;

    final validated = _validate(normalized);
    if (validated.isEmpty) return null;

    return _buildResult(validated, raw);
  }

  // ── Normalization ─────────────────────────────────────────────────────────
  String _normalize(String raw) {
    var s = raw.trim();

    // 1. أرقام عربية → إنجليزية
    const ar = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < ar.length; i++) {
      s = s.replaceAll(ar[i], '$i');
    }

    // 2. كلمات الأرقام → رقم (مرتبة من الأطول للأقصر علشان "تلاتة" قبل "تلات")
    const numMap = <String, String>{
      'صفر': '0',
      'زيرو': '0',
      'واحد': '1',
      'واحده': '1',
      'واحدة': '1',
      'إتنين': '2',
      'اتنين': '2',
      'اثنين': '2',
      'اثنان': '2',
      'تلاتة': '3',
      'تلاته': '3',
      'ثلاثة': '3',
      'ثلاثه': '3',
      'تلات': '3',
      'أربعة': '4',
      'اربعة': '4',
      'اربعه': '4',
      'أربعه': '4',
      'اربع': '4',
      'أربع': '4',
      'خمسة': '5',
      'خمسه': '5',
      'خمس': '5',
      'ستة': '6',
      'سته': '6',
      'ست': '6',
      'سبعة': '7',
      'سبعه': '7',
      'سبع': '7',
      'ثمانية': '8',
      'تمانية': '8',
      'تمانيه': '8',
      'ثمانيه': '8',
      'تمان': '8',
      'تسعة': '9',
      'تسعه': '9',
      'تسع': '9',
    };

    // رتب من الأطول للأقصر علشان نتجنب partial matches
    final sortedNums = numMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final word in sortedNums) {
      s = s.replaceAll(word, numMap[word]!);
    }

    // 3. كلمات الحروف → حرف واحد
    const letterMap = <String, String>{
      'ألف': 'ا',
      'الف': 'ا',
      'أ': 'ا',
      'باء': 'ب',
      'بيه': 'ب',
      'تاء': 'ت',
      'تيه': 'ت',
      'ثاء': 'ث',
      'جيم': 'ج',
      'حاء': 'ح',
      'حيه': 'ح',
      'خاء': 'خ',
      'دال': 'د',
      'ذال': 'ذ',
      'راء': 'ر',
      'زاي': 'ز',
      'سين': 'س',
      'شين': 'ش',
      'صاد': 'ص',
      'ضاد': 'ض',
      'طاء': 'ط',
      'ظاء': 'ظ',
      'عين': 'ع',
      'غين': 'غ',
      'فاء': 'ف',
      'قاف': 'ق',
      'كاف': 'ك',
      'لام': 'ل',
      'ميم': 'م',
      'نون': 'ن',
      'هاء': 'ه',
      'واو': 'و',
      'ياء': 'ي',
    };

    // رتب من الأطول للأقصر
    final sortedLetters = letterMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final word in sortedLetters) {
      s = s.replaceAll(word, letterMap[word]!);
    }

    // 4. نظّف المسافات
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  // ── Validation: بالضبط 3 حروف عربية + 4 أرقام ─────────────────────────────
  String _validate(String s) {
    final arabicChars =
    RegExp(r'[\u0600-\u06FF]').allMatches(s).map((m) => m[0]!).toList();
    final digits =
    RegExp(r'\d').allMatches(s).map((m) => m[0]!).toList();

    // ✅ الشرط الصارم: بالضبط 3 حروف و 4 أرقام — لا أكثر لا أقل
    if (arabicChars.length != 3 || digits.length != 4) return '';

    // صيغة اللوحة النهائية: "م ن س 1234"
    return '${arabicChars.join(' ')} ${digits.join('')}';
  }

  // ── بناء VehicleResult ────────────────────────────────────────────────────
  VehicleResult _buildResult(String plate, String rawTranscript) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return VehicleResult(
      id: '${now.microsecondsSinceEpoch}_$plate',
      plateNumber: plate,
      vehicleType: '',
      address: '',
      transcript: rawTranscript,
      latitude: latitude,
      longitude: longitude,
      mapLink: latitude != null && longitude != null
          ? 'https://www.google.com/maps?q=$latitude,$longitude'
          : '',
      date: date,
      time: time,
      status: 'ok',
    );
  }

  // ── Reset & Dispose ───────────────────────────────────────────────────────
  void resetBuffer() => _buf.clear();

  Future<void> dispose() async {
    await _transcriptSub?.cancel();
    _transcriptSub = null;
    _buf.clear();
    await _plateCtrl.close();
  }
}