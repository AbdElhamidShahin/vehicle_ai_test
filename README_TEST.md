# Vehicle AI Test — Direct Gemini

نسخة اختبار فقط: التطبيق يسجل الصوت على الموبايل ويرسله مباشرة إلى Gemini API.
لا يوجد FastAPI ولا Python ولا كمبيوتر مطلوب أثناء تشغيل التطبيق.

## تشغيل الاختبار

ضع مفتاح Gemini كـ dart-define ولا تكتبه داخل الكود:

```powershell
flutter pub get
flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

أو لبناء APK:

```powershell
flutter build apk --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

الموديل المستخدم في الاختبار:
`gemini-2.5-flash-lite`

ملاحظة: وضع API key داخل تطبيق موبايل بهذه الطريقة مناسب للاختبار فقط. في النسخة الإنتاجية يجب وضع المفتاح خلف Backend/Cloud Function وعدم شحنه داخل APK.
