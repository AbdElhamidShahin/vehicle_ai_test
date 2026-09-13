import '../../../../core/ai/DeepgramLiveService.dart';
import '../models/vehicle_result.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// VehicleRepository
/// ─────────────────────────────────────────────────────────────────────────────
///
/// مسؤول عن:
///   1. استقبال النص الحي من DeepgramLiveService.
///   2. تطبيق الفلتر الصارم (3 حروف + 4 أرقام).
///   3. تحويل النص المتحقق منه لـ VehicleResult وإصداره كـ Stream.
///
class VehicleRepository {
  VehicleRepository({required this.deepgram});

  final DeepgramLiveService deepgram;

  // ── Streams ────────────────────────────────────────────────────────────────
  /// يُصدر VehicleResult جديدة كل ما تكتمل لوحة صالحة
  Stream<VehicleResult> get plateStream => _buildPlateStream();

  // ── Live text buffer ───────────────────────────────────────────────────────
  // بنجمع النص الـ interim في buffer حتى يأتي is_final
  // ثم نطبق الفلتر على النص النهائي
  final StringBuffer _buf = StringBuffer();

  // GPS (اختياري — يُضبط من الخارج)
  double? latitude;
  double? longitude;

  // ── stream builder ─────────────────────────────────────────────────────────
  Stream<VehicleResult> _buildPlateStream() async* {
    await for (final t in deepgram.onTranscript) {
      if (!t.isFinal) continue;   // الـ interim بس للعرض المرئي — مش للحفظ

      // أضف النص النهائي للـ buffer
      if (_buf.isNotEmpty) _buf.write(' ');
      _buf.write(t.text);

      // حاول استخرج لوحة من الـ buffer المتراكم
      final result = _tryExtractPlate(_buf.toString());
      if (result != null) {
        _buf.clear();
        yield result;
      }
      // لو مش مكتمل بعد، نكمل نجمع في الـ buffer
    }
  }

  // ── plate extraction ───────────────────────────────────────────────────────

  /// يحول النص المنطوق لأرقام وحروف ويتحقق من القاعدة الصارمة
  VehicleResult? _tryExtractPlate(String raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return null;

    final validated = _validate(normalized);
    if (validated.isEmpty) return null;

    return _buildResult(validated, raw);
  }

  /// ── تحويل الكلمات المنطوقة لصيغة اللوحة ─────────────────────────────────
  String _normalize(String raw) {
    var s = raw.trim();

    // 1. أرقام عربية → إنجليزية
    const ar = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < ar.length; i++) {
      s = s.replaceAll(ar[i], '$i');
    }

    // 2. كلمات الأرقام → رقم
    const numMap = {
      'صفر': '0', 'زيرو': '0',
      'واحد': '1', 'واحده': '1',
      'اتنين': '2', 'اثنين': '2', 'إتنين': '2', 'اثنان': '2',
      'تلاتة': '3', 'تلاته': '3', 'ثلاثة': '3', 'تلات': '3',
      'أربعة': '4', 'اربعة': '4', 'اربعه': '4', 'أربعه': '4',
      'خمسة': '5', 'خمسه': '5', 'خمس': '5',
      'ستة': '6', 'سته': '6', 'ست': '6',
      'سبعة': '7', 'سبعه': '7', 'سبع': '7',
      'ثمانية': '8', 'تمانية': '8', 'تمانيه': '8', 'تمان': '8',
      'تسعة': '9', 'تسعه': '9', 'تسع': '9',
    };
    numMap.forEach((word, digit) {
      s = s.replaceAll(word, digit);
    });

    // 3. كلمات الحروف العربية → حرف
    const letterMap = {
      'ألف': 'ا', 'الف': 'ا', 'أ': 'ا',
      'باء': 'ب', 'با': 'ب',
      'تاء': 'ت', 'تا': 'ت',
      'ثاء': 'ث',
      'جيم': 'ج',
      'حاء': 'ح', 'حا': 'ح',
      'خاء': 'خ',
      'دال': 'د',
      'ذال': 'ذ',
      'راء': 'ر', 'را': 'ر',
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
      'هاء': 'ه', 'ها': 'ه',
      'واو': 'و',
      'ياء': 'ي',
    };
    // نستبدل كلمات الحروف بالحرف نفسه (الكلمة الأطول أولاً)
    final sortedLetters = letterMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final word in sortedLetters) {
      s = s.replaceAll(word, letterMap[word]!);
    }

    // 4. نظّف المسافات
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  /// ── فلتر صارم: 3 حروف + 4 أرقام ─────────────────────────────────────────
  ///
  /// الصيغ المقبولة:
  ///   م ن س 1 2 3 4     (حروف مفصولة بمسافة + أرقام مفصولة بمسافة)
  ///   م ن س 1234        (حروف مفصولة + أرقام ملتصقة)
  ///   منس 1234           (حروف ملتصقة + أرقام)
  ///
  String _validate(String s) {
    // استخرج الحروف العربية
    final arabic  = RegExp(r'[\u0600-\u06FF]');
    // استخرج الأرقام
    final digits  = RegExp(r'\d');

    final letters = arabic.allMatches(s).map((m) => m[0]!).toList();
    final nums    = digits.allMatches(s).map((m) => m[0]!).toList();

    // الشرط الصارم: بالضبط 3 حروف و 4 أرقام
    if (letters.length != 3 || nums.length != 4) return '';

    // بنفصل الحروف بمسافة ونلصق الأرقام
    final plate = '${letters.join(' ')} ${nums.join('')}';
    return plate;
  }

  /// ── بناء VehicleResult ────────────────────────────────────────────────────
  VehicleResult _buildResult(String plate, String rawTranscript) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final lat = latitude;
    final lng = longitude;

    return VehicleResult(
      id:          '${now.microsecondsSinceEpoch}_$plate',
      plateNumber: plate,
      vehicleType: '',   // اختياري — Deepgram مش هيعرف النوع
      address:     '',   // اختياري
      transcript:  rawTranscript,
      latitude:    lat,
      longitude:   lng,
      mapLink:     lat != null && lng != null
          ? 'https://www.google.com/maps?q=$lat,$lng'
          : '',
      date:   date,
      time:   time,
      status: 'ok',
    );
  }

  // ── reset ──────────────────────────────────────────────────────────────────
  void resetBuffer() => _buf.clear();

  void dispose() {
    _buf.clear();
  }
}