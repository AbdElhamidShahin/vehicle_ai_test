# خطوات تشغيل المشروع (مرة واحدة بس)

## المشاكل اللي اتصلحت:
1. **firebase_ai 4.0.0** - خطأ `@internal` في `live_session.dart` (بسبب import ناقص)
2. **Kotlin version** - رُفعت من `2.1.0` إلى `2.1.21` عشان تتوافق مع `firebase-auth 24.2.0`
3. **Firebase packages** - كلها اتحدّثت لإصدارات متوافقة مع بعض

## الخطوات:

### الخطوة 1: صلّح ملف firebase_ai (مرة واحدة بس)
```powershell
cd D:\vehicle_ai_test
.\fix_firebase_ai.ps1
```

### الخطوة 2: شغّل المشروع
```powershell
flutter clean
flutter pub get
flutter run
```

## ملاحظة:
لو مسحت الـ pub cache أو غيّرت نسخة firebase_ai، هتحتاج تشغّل السكريبت تاني.
