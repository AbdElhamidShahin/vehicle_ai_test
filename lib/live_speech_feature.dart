// ============================================================
// live_speech_screen_v3.dart
//
// FIXED VERSION
//
// أهم الإصلاحات:
//
// 1. الصفوف المقفولة لا يتم تعديلها نهائياً.
// 2. يوجد Live Row واحد فقط في آخر الجدول.
// 3. الـLive Row منفصل تماماً عن الصفوف المؤكدة.
// 4. تم إلغاء الاعتماد على _processedPlateCount.
// 5. لا نعتمد على index ثابت داخل allMatches لأن SpeechToText
//    يمكن أن يعدّل الـpartial result.
// 6. اللوحة الجديدة تُضاف كصف مستقل.
// 7. عند ظهور لوحة جديدة، الـLive Row السابق يتحول إلى Locked Row.
// 8. حذف صف لا يؤثر على آلية تتبع النص.
// 9. duplicate check مستقل عن عدد الصفوف.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

// ============================================================
// MODEL
// ============================================================

class PlateRow {
  final int rowNum;

  String liveText;
  String plateValue;
  String carTypeValue;
  String locationValue;

  bool locked;

  PlateRow({
    required this.rowNum,
    this.liveText = '',
    this.plateValue = '',
    this.carTypeValue = '',
    this.locationValue = '',
    this.locked = false,
  });

  String get plate =>
      plateValue.isNotEmpty ? plateValue : PlateParser.extractPlate(liveText);

  String get carType => carTypeValue.isNotEmpty
      ? carTypeValue
      : PlateParser.extractCarType(liveText);

  String get location => locationValue.isNotEmpty
      ? locationValue
      : PlateParser.extractLocation(liveText);
}

// ============================================================
// PARSER
// ============================================================

class PlateParser {
  static const List<String> _carTypes = [
    'تويوتا',
    'هيونداي',
    'كيا',
    'نيسان',
    'هوندا',
    'مرسيدس',
    'بي إم دبليو',
    'بى ام دبليو',
    'بي ام دبليو',
    'شيفروليه',
    'فولكس',
    'ميتسوبيشي',
    'رينو',
    'بيجو',
    'سوزوكي',
    'سوزوكى',
    'لادا',
    'أوبل',
    'اوبل',
    'فورد',
    'جيب',
    'تشيري',
    'شيرى',
    'جيلي',
    'جيتلي',
    'بي واي دي',
    'بى واى دى',
    'ملاكي',
    'ملاكى',
    'نقل',
    'ميكروباص',
    'مازدا',
    'سكودا',
    'فيات',
    'دايهاتسو',
  ];

  static const List<String> _locationWords = [
    'شارع',
    'ميدان',
    'حي',
    'حى',
    'منطقة',
    'قرية',
    'مدينة',
    'طريق',
    'كورنيش',
    'أمام',
    'امام',
    'خلف',
    'بجانب',
    'عند',
    'ناحية',
    'ناحيه',
    'جنب',
    'قصاد',
    'جراج',
    'محطة',
    'محطه',
    'كمين',
    'موقف',
    'كوبري',
    'كوبرى',
  ];

  // ----------------------------------------------------------
  // Normalize digits
  // ----------------------------------------------------------

  static String normalizeDigits(String input) {
    const map = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    return input.split('').map((c) => map[c] ?? c).join();
  }

  // ----------------------------------------------------------
  // Normalize Arabic
  // ----------------------------------------------------------

  static String normalizeArabic(String input) {
    return input
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '');
  }

  // ----------------------------------------------------------
  // Normalize
  // ----------------------------------------------------------

  static String normalize(String input) {
    var v = normalizeDigits(input);
    v = normalizeArabic(v);

    v = v
        .replaceAll(RegExp(r'[،,؛;|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return v;
  }

  // ----------------------------------------------------------
  // Find plates
  // ----------------------------------------------------------

  static List<RegExpMatch> findPlateMatches(String rawInput) {
    final text = normalize(rawInput);

    final patterns = [
      // حروف مفرقة:
      // م ر س 1234
      RegExp(
        r'[\u0621-\u064A](?:\s+[\u0621-\u064A]){1,3}\s+\d{3,4}(?!\d)',
        caseSensitive: false,
      ),

      // حروف ملتصقة:
      // مرس 1234
      // مرس1234
      RegExp(r'[\u0621-\u064A]{2,5}\s*\d{3,4}(?!\d)', caseSensitive: false),

      // أرقام مفرقة:
      // مرس 12 34
      RegExp(
        r'[\u0621-\u064A]{1,5}\s+\d{2,3}\s+\d{2,3}(?!\d)',
        caseSensitive: false,
      ),
    ];

    final allMatches = <RegExpMatch>[];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final value = match.group(0) ?? '';

        final digits = RegExp(r'\d').allMatches(value).length;

        if (digits < 3) continue;

        final overlaps = allMatches.any(
          (existing) =>
              match.start < existing.end && match.end > existing.start,
        );

        if (!overlaps) {
          allMatches.add(match);
        }
      }
    }

    allMatches.sort((a, b) => a.start.compareTo(b.start));

    return allMatches;
  }

  // ----------------------------------------------------------
  // Clean plate
  // ----------------------------------------------------------

  static String cleanPlate(String value) {
    var text = normalize(value);

    final lettersList = RegExp(
      r'[\u0621-\u064A]',
    ).allMatches(text).map((m) => m.group(0)!).toList();

    final digits = RegExp(
      r'\d',
    ).allMatches(text).map((m) => m.group(0)!).join();

    if (lettersList.isEmpty && digits.isEmpty) {
      return text;
    }

    final letters = lettersList.take(4).join(' ');

    if (letters.isEmpty) {
      return digits;
    }

    if (digits.isEmpty) {
      return letters;
    }

    return '$letters $digits';
  }

  // ----------------------------------------------------------
  // Extract first plate
  // ----------------------------------------------------------

  static String extractPlate(String raw) {
    final matches = findPlateMatches(raw);

    if (matches.isNotEmpty) {
      return cleanPlate(matches.first.group(0)!);
    }

    return raw.trim();
  }

  // ----------------------------------------------------------
  // Car type
  // ----------------------------------------------------------

  static String extractCarType(String raw) {
    final normalized = normalize(raw);

    for (final type in _carTypes) {
      if (normalized.contains(normalize(type))) {
        return type;
      }
    }

    return '';
  }

  // ----------------------------------------------------------
  // Location
  // ----------------------------------------------------------

  static String extractLocation(String raw) {
    final normalized = normalize(raw);

    for (final keyword in _locationWords) {
      final index = normalized.indexOf(normalize(keyword));

      if (index != -1) {
        return normalized.substring(index).split(' ').take(6).join(' ');
      }
    }

    return '';
  }

  // ----------------------------------------------------------
  // Parse segment
  // ----------------------------------------------------------

  static Map<String, String> parseSegment(String text) {
    return {
      'plate': extractPlate(text),
      'carType': extractCarType(text),
      'location': extractLocation(text),
    };
  }
}

// ============================================================
// SCREEN
// ============================================================

class LiveSpeechScreen extends StatefulWidget {
  const LiveSpeechScreen({super.key});

  @override
  State<LiveSpeechScreen> createState() => _LiveSpeechScreenState();
}

class _LiveSpeechScreenState extends State<LiveSpeechScreen>
    with WidgetsBindingObserver {
  final SpeechToText _stt = SpeechToText();

  bool _ready = false;
  bool _active = false;
  bool _isStartingListening = false;

  final List<PlateRow> _rows = [];

  // ============================================================
  // TEXT BUFFER
  //
  // globalBuffer:
  // النص النهائي من الـsessions السابقة.
  //
  // sessionText:
  // النص الحالي من SpeechToText.
  //
  // مهم:
  // لا يوجد processedPlateCount هنا.
  // ============================================================

  String _globalBuffer = '';
  String _sessionText = '';

  // ============================================================
  // TRACKING
  // ============================================================

  final List<String> _committedPlates = [];

  String _lastStablePlate = '';

  // آخر نص تم استخدامه للـpreview.
  String _lastPreviewText = '';

  // عدد الـplates الموجودة في آخر نتيجة.
  int _lastDetectedPlateCount = 0;

  // ============================================================
  // TIMERS
  // ============================================================

  Timer? _restartTimer;
  Timer? _sessionTimer;
  Timer? _clockTimer;
  Timer? _debounceTimer;

  static const int _maxSec = 3600;

  int _elapsed = 0;

  final ScrollController _scroll = ScrollController();

  String? _error;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initStt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _restartTimer?.cancel();
    _sessionTimer?.cancel();
    _clockTimer?.cancel();
    _debounceTimer?.cancel();

    _scroll.dispose();

    _stt.stop();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _active) {
      _scheduleRestart(delay: const Duration(milliseconds: 200));
    }
  }

  // ============================================================
  // INIT
  // ============================================================

  Future<void> _initStt() async {
    try {
      final ok = await _stt.initialize(onError: _onError, onStatus: _onStatus);

      if (!mounted) return;

      setState(() {
        _ready = ok;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _ready = false;
        _error = 'فشل تشغيل التعرف الصوتي';
      });
    }
  }

  // ============================================================
  // START
  // ============================================================

  Future<void> _start() async {
    if (!_ready || _active) return;

    _restartTimer?.cancel();
    _sessionTimer?.cancel();
    _clockTimer?.cancel();
    _debounceTimer?.cancel();

    setState(() {
      _active = true;
      _error = null;
      _elapsed = 0;

      _rows.clear();

      _globalBuffer = '';
      _sessionText = '';

      _committedPlates.clear();

      _lastStablePlate = '';
      _lastPreviewText = '';
      _lastDetectedPlateCount = 0;
    });

    _sessionTimer = Timer(const Duration(seconds: _maxSec), () {
      if (_active) {
        _stop();
      }
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_active || !mounted) return;

      setState(() {
        _elapsed++;
      });
    });

    await _startListeningSession();
  }

  // ============================================================
  // START ONE SESSION
  // ============================================================

  Future<void> _startListeningSession() async {
    if (!_active || !_ready || _isStartingListening) {
      return;
    }

    if (_stt.isListening) return;

    _isStartingListening = true;

    try {
      // نقل الـsession السابقة إلى globalBuffer
      if (_sessionText.trim().isNotEmpty) {
        _globalBuffer = '${_globalBuffer.trim()} ${_sessionText.trim()}'.trim();

        _sessionText = '';
      }

      await _stt.listen(
        onResult: _onResult,
        localeId: 'ar-EG',
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 60),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );
    } catch (_) {
      if (_active) {
        _scheduleRestart(delay: const Duration(seconds: 1));
      }
    } finally {
      _isStartingListening = false;
    }
  }

  // ============================================================
  // RESTART
  // ============================================================

  void _scheduleRestart({Duration delay = const Duration(milliseconds: 150)}) {
    if (!_active) return;

    _restartTimer?.cancel();

    _restartTimer = Timer(delay, () async {
      if (!_active) return;

      await _startListeningSession();
    });
  }

  // ============================================================
  // STOP
  // ============================================================

  Future<void> _stop() async {
    if (!_active) return;

    _restartTimer?.cancel();
    _sessionTimer?.cancel();
    _clockTimer?.cancel();
    _debounceTimer?.cancel();

    _isStartingListening = false;

    // حفظ آخر session
    if (_sessionText.trim().isNotEmpty) {
      _globalBuffer = '${_globalBuffer.trim()} ${_sessionText.trim()}'.trim();

      _sessionText = '';
    }

    try {
      await _stt.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _active = false;

      // عند الإيقاف:
      // أي Live Row موجود يتحول إلى locked
      _commitLiveRow();

      // لو فيه نص لم يتحول إلى row
      // نحاول استخراج آخر لوحة منه.
      _flushRemainingText();

      for (final row in _rows) {
        row.locked = true;
      }
    });

    _scrollToBottom();
  }

  // ============================================================
  // STATUS
  // ============================================================

  void _onStatus(String status) {
    if (!_active) return;

    if (status == 'done' || status == 'notListening') {
      _scheduleRestart(delay: const Duration(milliseconds: 100));
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _onError(SpeechRecognitionError error) {
    final code = error.errorMsg;

    if (code == 'error_permission' || code == 'error_not_supported') {
      if (!mounted) return;

      setState(() {
        _error = 'خطأ: $code';
        _active = false;
      });

      return;
    }

    if (_active) {
      _scheduleRestart(delay: const Duration(seconds: 1));
    }
  }

  // ============================================================
  // SPEECH RESULT
  // ============================================================

  void _onResult(SpeechRecognitionResult result) {
    if (!_active) return;

    final words = result.recognizedWords.trim();

    if (words.isEmpty) return;

    _sessionText = words;

    final allText = '${_globalBuffer.trim()} ${_sessionText.trim()}'.trim();

    final normalized = PlateParser.normalize(allText);

    final matches = PlateParser.findPlateMatches(normalized);

    final detectedCount = matches.length;

    // ----------------------------------------------------------
    // FINAL RESULT
    // ----------------------------------------------------------

    if (result.finalResult) {
      _debounceTimer?.cancel();

      _processDetectedPlates(normalized, matches, forceLast: true);

      _lastDetectedPlateCount = detectedCount;

      return;
    }

    // ----------------------------------------------------------
    // PARTIAL RESULT
    // ----------------------------------------------------------

    // لو ظهر plate جديد
    if (detectedCount > _lastDetectedPlateCount) {
      _debounceTimer?.cancel();

      _processDetectedPlates(normalized, matches, forceLast: false);

      _lastDetectedPlateCount = detectedCount;

      return;
    }

    // ----------------------------------------------------------
    // نفس عدد اللوحات:
    // ممكن اللوحة الحالية بتتغير.
    // نعرضها كـ Live فقط.
    // ----------------------------------------------------------

    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!_active) return;

      _processDetectedPlates(normalized, matches, forceLast: false);
    });
  }

  // ============================================================
  // PROCESS DETECTED PLATES
  // ============================================================

  void _processDetectedPlates(
    String normalized,
    List<RegExpMatch> matches, {
    required bool forceLast,
  }) {
    if (!mounted) return;

    if (matches.isEmpty) {
      _updateLivePreview(normalized);

      return;
    }

    // ----------------------------------------------------------
    // أولاً:
    // نحدد اللوحات الموجودة فعلاً في النص.
    // ----------------------------------------------------------

    final parsedPlates = <_DetectedPlate>[];

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];

      final segmentEnd = i + 1 < matches.length
          ? matches[i + 1].start
          : normalized.length;

      final segment = normalized.substring(match.start, segmentEnd).trim();

      final parsed = PlateParser.parseSegment(segment);

      final plate = parsed['plate'] ?? '';

      if (plate.isEmpty) continue;

      final digits = RegExp(
        r'\d',
      ).allMatches(plate).map((m) => m.group(0)!).join();

      if (digits.length < 3) continue;

      parsedPlates.add(
        _DetectedPlate(
          plate: plate,
          segment: segment,
          carType: parsed['carType'] ?? '',
          location: parsed['location'] ?? '',
        ),
      );
    }

    if (parsedPlates.isEmpty) {
      _updateLivePreview(normalized);

      return;
    }

    // ----------------------------------------------------------
    // نضيف اللوحات الجديدة فقط.
    //
    // آخر لوحة لا نثبتها مباشرة في partial.
    // لأنها ممكن تكون لسه بتتغير.
    // ----------------------------------------------------------

    final int lastIndex = parsedPlates.length - 1;

    for (int i = 0; i < parsedPlates.length; i++) {
      final item = parsedPlates[i];

      final clean = PlateParser.cleanPlate(item.plate);

      // اللوحة موجودة بالفعل؟
      if (_isCommitted(clean)) {
        continue;
      }

      // آخر لوحة في partial:
      // خليها Live.
      if (i == lastIndex && !forceLast) {
        continue;
      }

      _commitPlate(item);
    }

    // ----------------------------------------------------------
    // Live preview
    // ----------------------------------------------------------

    if (!forceLast) {
      final last = parsedPlates.last;

      final clean = PlateParser.cleanPlate(last.plate);

      if (!_isCommitted(clean)) {
        _updateLivePreview(last.segment);
      } else {
        _clearLiveRow();
      }
    } else {
      _clearLiveRow();
    }

    _scrollToBottom();
  }

  // ============================================================
  // COMMIT PLATE
  // ============================================================

  void _commitPlate(_DetectedPlate detected) {
    if (!mounted) return;

    final plate = PlateParser.cleanPlate(detected.plate);

    if (plate.isEmpty) return;

    if (_isCommitted(plate)) {
      return;
    }

    setState(() {
      // أولاً:
      // لو فيه Live Row لنفس اللوحة، نحوله
      // إلى Row ثابت بدلاً من إنشاء صف جديد.

      final liveIndex = _findLiveRowIndex();

      if (liveIndex != null) {
        final liveRow = _rows[liveIndex];

        liveRow.liveText = detected.segment;

        liveRow.plateValue = plate;

        liveRow.carTypeValue = detected.carType;

        liveRow.locationValue = detected.location;

        liveRow.locked = true;
      } else {
        // مفيش Live Row:
        // نضيف صف جديد.

        _rows.add(
          PlateRow(
            rowNum: _rows.length + 1,
            liveText: detected.segment,
            plateValue: plate,
            carTypeValue: detected.carType,
            locationValue: detected.location,
            locked: true,
          ),
        );
      }

      _committedPlates.add(plate);

      _lastStablePlate = plate;

      _lastPreviewText = '';
    });

    _scrollToBottom();
  }

  // ============================================================
  // FIND LIVE ROW
  // ============================================================

  int? _findLiveRowIndex() {
    if (_rows.isEmpty) {
      return null;
    }

    for (int i = _rows.length - 1; i >= 0; i--) {
      if (!_rows[i].locked) {
        return i;
      }
    }

    return null;
  }

  // ============================================================
  // UPDATE LIVE PREVIEW
  // ============================================================

  void _updateLivePreview(String text) {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    if (cleanText == _lastPreviewText) {
      return;
    }

    _lastPreviewText = cleanText;

    if (!mounted) return;

    setState(() {
      final liveIndex = _findLiveRowIndex();

      if (liveIndex != null) {
        // مهم جدًا:
        // نعدل آخر Live Row فقط.
        _rows[liveIndex].liveText = cleanText;
      } else {
        // إنشاء Live Row مستقل.

        _rows.add(
          PlateRow(
            rowNum: _rows.length + 1,
            liveText: cleanText,
            locked: false,
          ),
        );
      }
    });

    _scrollToBottom();
  }

  // ============================================================
  // CLEAR LIVE ROW
  // ============================================================

  void _clearLiveRow() {
    if (!mounted) return;

    final index = _findLiveRowIndex();

    if (index == null) {
      return;
    }

    setState(() {
      _rows.removeAt(index);

      _rebuildRowNumbers();
    });
  }

  // ============================================================
  // COMMIT LIVE ROW
  // ============================================================

  void _commitLiveRow() {
    final index = _findLiveRowIndex();

    if (index == null) return;

    final row = _rows[index];

    final parsed = PlateParser.parseSegment(row.liveText);

    final plate = parsed['plate'] ?? '';

    final digits = RegExp(
      r'\d',
    ).allMatches(plate).map((m) => m.group(0)!).join();

    if (plate.isEmpty || digits.length < 3) {
      return;
    }

    final clean = PlateParser.cleanPlate(plate);

    if (_isCommitted(clean)) {
      _rows.removeAt(index);
      _rebuildRowNumbers();
      return;
    }

    setState(() {
      row.plateValue = clean;

      row.carTypeValue = parsed['carType'] ?? '';

      row.locationValue = parsed['location'] ?? '';

      row.locked = true;

      _committedPlates.add(clean);

      _lastStablePlate = clean;

      _lastPreviewText = '';
    });
  }

  // ============================================================
  // FLUSH REMAINING TEXT
  // ============================================================

  void _flushRemainingText() {
    final allText = '${_globalBuffer.trim()} ${_sessionText.trim()}'.trim();

    if (allText.isEmpty) return;

    final normalized = PlateParser.normalize(allText);

    final matches = PlateParser.findPlateMatches(normalized);

    if (matches.isEmpty) {
      return;
    }

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];

      final end = i + 1 < matches.length
          ? matches[i + 1].start
          : normalized.length;

      final segment = normalized.substring(match.start, end).trim();

      final parsed = PlateParser.parseSegment(segment);

      final plate = parsed['plate'] ?? '';

      if (plate.isEmpty) continue;

      final digits = RegExp(
        r'\d',
      ).allMatches(plate).map((m) => m.group(0)!).join();

      if (digits.length < 3) {
        continue;
      }

      final clean = PlateParser.cleanPlate(plate);

      if (_isCommitted(clean)) {
        continue;
      }

      _commitPlate(
        _DetectedPlate(
          plate: clean,
          segment: segment,
          carType: parsed['carType'] ?? '',
          location: parsed['location'] ?? '',
        ),
      );
    }
  }

  // ============================================================
  // DUPLICATE
  // ============================================================

  bool _isCommitted(String plate) {
    final normalized = PlateParser.cleanPlate(plate);

    if (normalized.isEmpty) {
      return false;
    }

    return _committedPlates.contains(normalized);
  }

  // ============================================================
  // DELETE ROW
  // ============================================================

  void _deleteRow(int index) {
    if (index < 0 || index >= _rows.length) {
      return;
    }

    setState(() {
      final row = _rows[index];

      // لو الصف locked وكان فيه plate
      // نشيله من duplicate list.
      if (row.locked && row.plateValue.isNotEmpty) {
        final plate = PlateParser.cleanPlate(row.plateValue);

        _committedPlates.remove(plate);
      }

      _rows.removeAt(index);

      _rebuildRowNumbers();
    });
  }

  // ============================================================
  // REBUILD ROW NUMBERS
  // ============================================================

  void _rebuildRowNumbers() {
    for (int i = 0; i < _rows.length; i++) {
      final old = _rows[i];

      _rows[i] = PlateRow(
        rowNum: i + 1,
        liveText: old.liveText,
        plateValue: old.plateValue,
        carTypeValue: old.carTypeValue,
        locationValue: old.locationValue,
        locked: old.locked,
      );
    }
  }

  // ============================================================
  // CLEAR ALL
  // ============================================================

  void _clearAll() {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E2130),
          title: const Text(
            'مسح الجدول',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'هل تريد حذف كل السجلات؟',
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _rows.clear();

                  _globalBuffer = '';

                  _sessionText = '';

                  _committedPlates.clear();

                  _lastStablePlate = '';

                  _lastPreviewText = '';

                  _lastDetectedPlateCount = 0;
                });

                Navigator.pop(context);
              },
              child: const Text(
                'مسح',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }

      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // TIME
  // ============================================================

  String get _timeStr {
    final minutes = _elapsed ~/ 60;

    final seconds = _elapsed % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0F1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTableHeader(),
              Expanded(child: _buildTableBody()),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    final lockedCount = _rows.where((row) => row.locked).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141624),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car,
              color: Color(0xFF60A5FA),
              size: 20,
            ),
          ),

          const SizedBox(width: 10),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رصد اللوحات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'تسجيل صوتي مباشر',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
              ),
            ],
          ),

          const Spacer(),

          if (lockedCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$lockedCount لوحة',
                style: const TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 8),

            GestureDetector(
              onTap: _clearAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1515),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'مسح',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                ),
              ),
            ),
          ],

          if (_active) ...[
            const SizedBox(width: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF14532D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                  const SizedBox(width: 5),
                  Text(
                    _timeStr,
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget _buildTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF60A5FA).withOpacity(0.3),
            width: 1.5,
          ),
        ),
      ),
      child: _tableRowWidget(
        cells: const ['#', 'اللوحة', 'النوع', 'الموقع', ''],
        flex: const [1, 4, 2, 3, 1],
        isHeader: true,
      ),
    );
  }

  // ============================================================
  // TABLE BODY
  // ============================================================

  Widget _buildTableBody() {
    if (_rows.isEmpty) {
      return _buildEmpty();
    }

    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.zero,
      itemCount: _rows.length,
      itemBuilder: (_, index) {
        final row = _rows[index];

        return _buildSingleRow(row, index, !row.locked);
      },
    );
  }

  // ============================================================
  // SINGLE ROW
  // ============================================================

  Widget _buildSingleRow(PlateRow row, int index, bool isLive) {
    return Dismissible(
      key: ValueKey('row_${row.rowNum}_${row.plate}_$index'),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: const Color(0xFF2D1515),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
      ),
      onDismissed: (_) => _deleteRow(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isLive
              ? const Color(0xFF0F2040)
              : index.isEven
              ? const Color(0xFF0D0F1A)
              : const Color(0xFF111326),
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
            right: isLive
                ? const BorderSide(color: Color(0xFF3B82F6), width: 3)
                : BorderSide.none,
          ),
        ),
        child: isLive
            ? _buildLiveRow(row, index)
            : _tableRowWidget(
                cells: [
                  '${row.rowNum}',
                  row.plate.isNotEmpty ? row.plate : row.liveText.trim(),
                  row.carType.isNotEmpty ? row.carType : '—',
                  row.location.isNotEmpty ? row.location : '—',
                  '',
                ],
                flex: const [1, 4, 2, 3, 1],
                isHeader: false,
                rowIndex: index,
              ),
      ),
    );
  }

  // ============================================================
  // LIVE ROW
  // ============================================================

  Widget _buildLiveRow(PlateRow row, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${row.rowNum}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF3B82F6),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 8),

          const Icon(Icons.mic, color: Color(0xFF60A5FA), size: 16),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              row.liveText.isNotEmpty ? row.liveText : 'في انتظار الكلام...',
              style: TextStyle(
                color: row.liveText.isNotEmpty
                    ? Colors.white
                    : const Color(0xFF4B5563),
                fontSize: 15,
                fontStyle: row.liveText.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          GestureDetector(
            onTap: () => _deleteRow(index),
            child: const Icon(Icons.close, color: Color(0xFF374151), size: 16),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE ROW
  // ============================================================

  Widget _tableRowWidget({
    required List<String> cells,
    required List<int> flex,
    required bool isHeader,
    int? rowIndex,
  }) {
    return IntrinsicHeight(
      child: Row(
        children: List.generate(cells.length, (col) {
          if (!isHeader && col == cells.length - 1) {
            return Expanded(
              flex: flex[col],
              child: Center(
                child: GestureDetector(
                  onTap: rowIndex != null ? () => _deleteRow(rowIndex) : null,
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF374151),
                    size: 16,
                  ),
                ),
              ),
            );
          }

          final isPlateCol = !isHeader && col == 1;

          return Expanded(
            flex: flex[col],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              decoration: col < cells.length - 1
                  ? BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.white.withOpacity(
                            isHeader ? 0.12 : 0.05,
                          ),
                        ),
                      ),
                    )
                  : null,
              child: Text(
                cells[col],
                style: TextStyle(
                  color: isHeader
                      ? const Color(0xFF60A5FA)
                      : isPlateCol
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFFCBD5E1),
                  fontSize: isHeader
                      ? 12
                      : isPlateCol
                      ? 15
                      : 13,
                  fontWeight: isHeader || isPlateCol
                      ? FontWeight.bold
                      : FontWeight.normal,
                  letterSpacing: isPlateCol ? 1.5 : 0,
                ),
                textAlign: col == 0 ? TextAlign.center : TextAlign.start,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_none, size: 56, color: Colors.white.withOpacity(0.1)),

          const SizedBox(height: 14),

          Text(
            'اضغط "بدء التسجيل"',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'اتكلم براحتك وسجل عدد كبير من اللوحات\n'
            'التسجيل يفضل شغال لحد ما تضغط إيقاف',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141624),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: GestureDetector(
        onTap: _active ? _stop : _start,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _active
                ? const Color(0xFF7F1D1D)
                : _ready
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF374151),
            boxShadow: [
              BoxShadow(
                color:
                    (_active
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF3B82F6))
                        .withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _active ? Icons.stop_circle_outlined : Icons.mic,
                color: Colors.white,
                size: 24,
              ),

              const SizedBox(width: 10),

              Text(
                _active ? 'إيقاف التسجيل' : 'بدء التسجيل',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (_active) ...[
                const SizedBox(width: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _timeStr,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETECTED PLATE MODEL
// ============================================================

class _DetectedPlate {
  final String plate;
  final String segment;
  final String carType;
  final String location;

  const _DetectedPlate({
    required this.plate,
    required this.segment,
    required this.carType,
    required this.location,
  });
}
