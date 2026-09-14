# Vehicle AI Test - Flutter Client

This version is the **Flutter/client phase only**. It is intentionally prepared for a Firebase Cloud Function AI backend, but it does not contain any Gemini/Kimi API key.

## Architecture

```text
Flutter
  |
  +-- AudioService
  +-- LocationService
  +-- VehicleRepository
  +-- VehicleAiService (interface)
  |      |
  |      +-- FirebaseAiLogicVehicleAiService (current Gemini test)
  |      +-- MockVehicleAiService (offline/local test)
  |      +-- CloudFunctionAiService (production backend)
  |
  +-- VehicleResult
  +-- History UI
  +-- Export
```

Production target:

```text
Flutter
  -> Cloud Function
  -> AI Provider (Gemini initially, Kimi/another provider later)
  -> normalized JSON
  -> Flutter
  -> local storage (next phase)
```

## Current behavior

- Records short M4A audio.
- Starts GPS acquisition with recording to reduce latency.
- Stores latitude/longitude as real fields and builds a map link.
- Uses an AI abstraction so the UI does not depend on Gemini.
- Uses Firebase AI Logic -> Gemini 3.5 Flash-Lite when no backend URL is configured.
- Keeps a local mock provider available for offline/local tests.
- Uses the Cloud Function provider automatically when `AI_FUNCTION_URL` is supplied.
- No Gemini API key is present in the Flutter app.
- Deletes the temporary audio after successful processing.

## Run local Flutter flow

No backend is needed for the mock flow:

```bash
flutter pub get
flutter analyze
flutter run
```

The mock AI returns test data so recording -> processing -> history can be tested.

## Connect the backend later

After the Firebase Cloud Function is deployed, run:

```bash
flutter run --dart-define=AI_FUNCTION_URL=https://YOUR_FUNCTION_URL
```

The Flutter client expects the backend to return a normalized JSON object like:

```json
{
  "success": true,
  "transcript": "مرس 1234 نقل جراج 1",
  "plate_number": "مرس 1234",
  "vehicle_type": "نقل",
  "address": "جراج 1"
}
```

The Flutter app does not need to know whether the backend used Gemini, Kimi, or another provider.

For Firebase AI Logic setup, see `README_FIREBASE_AI_LOGIC.md`.
