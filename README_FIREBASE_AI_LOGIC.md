# Firebase AI Logic test setup

This version adds a temporary direct AI provider for testing:

```text
Flutter
  -> Firebase AI Logic
  -> Gemini 3.5 Flash-Lite
  -> structured JSON
  -> VehicleResult
```

The existing `VehicleAiService` abstraction is preserved. When `AI_FUNCTION_URL`
is supplied, the Cloud Function provider is still used instead.

## 1. Create/connect the Firebase project

From the Flutter project root:

```bash
firebase login
flutterfire configure
```

Choose the Firebase project and Android app you want to use. This generates:

```text
lib/firebase_options.dart
```

The generated file is intentionally not included in this ZIP because it is
specific to your Firebase project.

## 2. Keep billing disabled for the free test

For the temporary Gemini Developer API free-tier test, keep the Firebase
project on the Spark plan and do not link Cloud Billing. Check the current
Firebase AI Logic pricing/quotas before large-scale testing.

## 3. App Check for local Android testing

The app currently activates the Firebase App Check debug provider for Android
and iOS. Run the app once and copy the debug token printed in the logs, then
register it in Firebase Console -> App Check -> your app -> Manage debug tokens.

This debug configuration is for development only.

## 4. Install and run

```bash
flutter pub get
flutter run
```

There is no Gemini API key in the Flutter source.

## 5. What the AI receives

The app sends the recorded M4A audio directly through Firebase AI Logic and
asks Gemini to return JSON with:

```json
{
  "success": true,
  "transcript": "مرس 1234 نقل جراج 1",
  "plate_number": "مرس 1234",
  "vehicle_type": "نقل",
  "address": "جراج 1"
}
```

## 6. Switching to Cloud Function later

No UI rewrite is required. Run with:

```bash
flutter run --dart-define=AI_FUNCTION_URL=https://YOUR_FUNCTION_URL
```

The controller will then use `CloudFunctionAiService` instead of the direct
Firebase AI Logic provider.

## Important

The Firebase AI Logic provider is intentionally a temporary testing provider.
For production, use the Cloud Function architecture so the AI provider can be
changed later without changing the Flutter UI/business layer.
