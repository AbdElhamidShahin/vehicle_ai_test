import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_ai_test/core/ai/plate_speech_parser.dart';

void main() {
  group('PlateSpeechParser', () {
    test('spoken Arabic letter names + words for digits', () {
      expect(
        PlateSpeechParser.parse('ألف باء تاء واحد اتنين تلاتة اربعة'),
        contains('ا ب ت 1234'),
      );
    });

    test('normalizes Arabic/Persian-style digits and multiple plates', () {
      expect(
        PlateSpeechParser.parse(
          'حاء واو طاء ٤٦٠٤ حاء ميم نون ٥٢٢٦',
        ),
        <String>['ح و ط 4604', 'ح م ن 5226'],
      );
    });

    test('supports Egyptian pronunciation after taa marbuta normalization', () {
      expect(
        PlateSpeechParser.parse('ميم نون راء واحد اتنين تلاته اربعه'),
        contains('م ن ر 1234'),
      );
    });

    test('does not confuse conjunction "و" with the spoken letter "واو"', () {
      expect(
        PlateSpeechParser.parse('ألف باء تاء واحد و اتنين و تلاتة و اربعة'),
        contains('ا ب ت 1234'),
      );
    });
  });
}
