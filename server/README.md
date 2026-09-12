# Local Whisper test server

This version connects the Flutter app to the local Windows `whisper.cpp` CLI.

## 1) Install server packages

```powershell
pip install -r server\requirements.txt
```

## 2) Check paths

Defaults are set for the current test machine:

- `C:\Users\abdo\Downloads\whisper-bin-x64\Release\whisper-cli.exe`
- `C:\whisper.cpp\ggml-base.bin`

To override them:

```powershell
$env:WHISPER_EXE = "C:\path\to\whisper-cli.exe"
$env:WHISPER_MODEL = "C:\path\to\ggml-base.bin"
```

## 3) Start

From the Flutter project root:

```powershell
python -m uvicorn server.main:app --host 0.0.0.0 --port 8000
```

The phone should call `http://192.168.1.22:8000`. If the laptop IP changes, update `_aiServerUrl` in `lib/main.dart`.

## What this test does

Flutter records WAV 16 kHz mono, sends it to `/transcribe`, and Whisper Base returns the transcript. No Gemini and no Llama are used yet.
