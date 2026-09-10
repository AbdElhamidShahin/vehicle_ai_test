# Flutter phase test checklist

1. `flutter pub get`
2. `flutter analyze`
3. `flutter run`
4. Allow microphone permission.
5. Allow location permission and enable location service.
6. Record a short test clip.
7. Stop recording.
8. Confirm a test vehicle row appears.
9. Confirm latitude/longitude and map link are present.
10. Confirm temporary audio is deleted after successful processing.

The AI backend is intentionally not connected in this phase. The app uses `MockVehicleAiService` unless `AI_FUNCTION_URL` is supplied.
