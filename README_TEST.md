# Vehicle AI - Local Whisper test

This build temporarily replaces Gemini with a local Windows Whisper Base server.

Flow: Flutter phone -> HTTP -> FastAPI -> whisper-cli.exe -> transcript -> Flutter.

The current test intentionally stops at transcription. Plate/type/address extraction comes next after we measure Whisper accuracy.
