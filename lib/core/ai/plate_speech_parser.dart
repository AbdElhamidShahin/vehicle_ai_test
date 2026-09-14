/// Fast deterministic parser for Egyptian spoken vehicle plates.
///
/// Logical order is the worker's spoken order: 3 letters, then 4 digits.
/// Flutter's RTL layout renders the digits on the left and the letters on the right.
class PlateSpeechParser {
  PlateSpeechParser._();

  static const Map<String, String> _letters = {
    'ا': 'ا', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'الف': 'ا', 'ألف': 'ا', 'الفا': 'ا',
    'ب': 'ب', 'باء': 'ب', 'با': 'ب', 'بي': 'ب',
    'ت': 'ت', 'تاء': 'ت', 'تا': 'ت',
    'ث': 'ث', 'ثاء': 'ث', 'ثا': 'ث',
    'ج': 'ج', 'جيم': 'ج', 'جي': 'ج',
    'ح': 'ح', 'حاء': 'ح', 'حا': 'ح',
    'خ': 'خ', 'خاء': 'خ', 'خا': 'خ',
    'د': 'د', 'دال': 'د', 'دا': 'د',
    'ذ': 'ذ', 'ذال': 'ذ', 'ذا': 'ذ',
    'ر': 'ر', 'راء': 'ر', 'را': 'ر',
    'ز': 'ز', 'زاي': 'ز', 'زائ': 'ز', 'زي': 'ز',
    'س': 'س', 'سين': 'س', 'سي': 'س',
    'ش': 'ش', 'شين': 'ش', 'شي': 'ش',
    'ص': 'ص', 'صاد': 'ص', 'صا': 'ص',
    'ض': 'ض', 'ضاد': 'ض', 'ضا': 'ض',
    'ط': 'ط', 'طاء': 'ط', 'طا': 'ط',
    'ظ': 'ظ', 'ظاء': 'ظ', 'ظا': 'ظ',
    'ع': 'ع', 'عين': 'ع', 'عي': 'ع',
    'غ': 'غ', 'غين': 'غ', 'غي': 'غ',
    'ف': 'ف', 'فاء': 'ف', 'فا': 'ف',
    'ق': 'ق', 'قاف': 'ق', 'قا': 'ق',
    'ك': 'ك', 'كاف': 'ك', 'كا': 'ك',
    'ل': 'ل', 'لام': 'ل', 'لا': 'ل',
    'م': 'م', 'ميم': 'م', 'مي': 'م',
    'ن': 'ن', 'نون': 'ن',
    'ه': 'ه', 'هـ': 'ه', 'هاء': 'ه', 'ها': 'ه',
    'و': 'و', 'واو': 'و',
    'ي': 'ي', 'ياء': 'ي', 'يا': 'ي',
  };

  static const Map<String, String> _digits = {
    '0': '0', '٠': '0', 'صفر': '0', 'زيرو': '0',
    '1': '1', '١': '1', 'واحد': '1', 'واحده': '1',
    '2': '2', '٢': '2', 'اتنين': '2', 'اثنين': '2', 'تنين': '2', 'اتنان': '2',
    '3': '3', '٣': '3', 'تلاتة': '3', 'تلاته': '3', 'ثلاثة': '3', 'ثلاثه': '3', 'تلت': '3', 'ثلاث': '3',
    '4': '4', '٤': '4', 'اربعة': '4', 'اربعه': '4', 'أربعة': '4', 'أربعه': '4', 'أربع': '4',
    '5': '5', '٥': '5', 'خمسة': '5', 'خمسه': '5', 'خمس': '5',
    '6': '6', '٦': '6', 'ستة': '6', 'سته': '6', 'ست': '6',
    '7': '7', '٧': '7', 'سبعة': '7', 'سبعه': '7', 'سبع': '7',
    '8': '8', '٨': '8', 'تمانية': '8', 'تمانيه': '8', 'ثمانية': '8', 'ثمانيه': '8', 'تمان': '8',
    '9': '9', '٩': '9', 'تسعة': '9', 'تسعه': '9', 'تسع': '9',
  };

  // "و" is intentionally treated as noise in free text. The worker should
  // say "واو" for the letter و. Keeping bare "وا" as a letter caused fakes.
  static const Set<String> _noise = {
    'لوحه', 'اللوحة', 'لوحات', 'رقم', 'رقمها', 'هي', 'هو', 'ثم', 'و',
    'وبعدين', 'بعد', 'بعدها', 'والرقم', 'ارقام', 'أرقام', 'حرف', 'حروف',
    'الارقام', 'الأرقام',
  };

  static List<String> parse(String transcript) {
    if (transcript.trim().isEmpty) return const [];

    final tokens = <_Token>[];
    for (final raw in _normalizeText(transcript).split(RegExp(r'\s+'))) {
      final clean = _cleanToken(raw);
      if (clean.isEmpty || _noise.contains(clean)) continue;

      final letter = _letters[clean];
      if (letter != null) {
        tokens.add(_Token.letter(letter));
        continue;
      }

      final digit = _digits[clean];
      if (digit != null) {
        tokens.add(_Token.digit(digit));
        continue;
      }

      final compactDigits = _digitsFromMixedToken(clean);
      if (compactDigits != null) {
        for (final d in compactDigits.split('')) tokens.add(_Token.digit(d));
      }
    }

    final found = <String>[];
    var letters = <String>[];
    var digits = <String>[];

    void flushValid() {
      if (letters.length == 3 && digits.length == 4) {
        final plate = '${letters.join(' ')} ${digits.join()}';
        if (!found.contains(plate)) found.add(plate);
      }
      letters = <String>[];
      digits = <String>[];
    }

    for (final token in tokens) {
      if (token.letterValue != null) {
        final letter = token.letterValue!;
        if (digits.isEmpty) {
          if (letters.length < 3) {
            letters.add(letter);
          } else {
            // 4th letter before digits => the previous sequence was not a plate.
            letters = [letter];
          }
        } else {
          // A letter after digits starts a new vehicle.
          flushValid();
          letters = [letter];
        }
        continue;
      }

      if (token.digitValue != null && letters.length == 3) {
        digits.add(token.digitValue!);
        if (digits.length == 4) flushValid();
      }
    }

    return found;
  }

  static String normalizePlate(String plate) {
    return _normalizeText(plate)
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeText(String text) {
    return text
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ة', 'ه')
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'[،,.;:!?؟]'), ' ')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), ' ')
        .trim()
        .toLowerCase();
  }

  static String _cleanToken(String token) {
    return token
        .replaceAll(RegExp(r'^[^a-zA-Z0-9٠-٩ء-ي]+|[^a-zA-Z0-9٠-٩ء-ي]+$'), '')
        .trim();
  }

  static String? _digitsFromMixedToken(String token) {
    if (!RegExp(r'^[0-9٠-٩]+$').hasMatch(token)) return null;
    return token.split('').map((c) => _digits[c] ?? c).join();
  }
}

class _Token {
  const _Token.letter(this.letterValue) : digitValue = null;
  const _Token.digit(this.digitValue) : letterValue = null;

  final String? letterValue;
  final String? digitValue;
}
