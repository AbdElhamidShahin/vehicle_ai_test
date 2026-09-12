from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile

app = FastAPI(title="Vehicle Whisper Server", version="0.2.0")

# Defaults match the current Windows test setup.
WHISPER_EXE = Path(os.getenv(
    "WHISPER_EXE",
    r"C:\Users\abdo\Downloads\whisper-bin-x64\Release\whisper-cli.exe",
))
WHISPER_MODEL = Path(os.getenv(
    "WHISPER_MODEL",
    r"C:\whisper.cpp\ggml-base.bin",
))


def check_files() -> None:
    if not WHISPER_EXE.exists():
        raise HTTPException(500, f"whisper-cli.exe not found: {WHISPER_EXE}")
    if not WHISPER_MODEL.exists():
        raise HTTPException(500, f"Whisper model not found: {WHISPER_MODEL}")


@app.get("/")
def root():
    return {
        "status": "ok",
        "service": "vehicle-whisper-server",
        "model": str(WHISPER_MODEL),
    }


@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    check_files()

    suffix = Path(file.filename or "audio.wav").suffix.lower() or ".wav"
    if suffix != ".wav":
        raise HTTPException(400, "This test endpoint expects WAV audio")

    with tempfile.TemporaryDirectory(prefix="vehicle_whisper_") as tmp:
        tmp_path = Path(tmp) / "input.wav"
        out_base = Path(tmp) / "result"
        tmp_path.write_bytes(await file.read())

        cmd = [
            str(WHISPER_EXE),
            "-m", str(WHISPER_MODEL),
            "-f", str(tmp_path),
            "-l", "ar",
            "-nt",
            "-otxt",
            "-of", str(out_base),
            "-t", "6",
        ]

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=300,
            )
        except subprocess.TimeoutExpired:
            raise HTTPException(504, "Whisper timed out")
        except OSError as exc:
            raise HTTPException(500, f"Could not start Whisper: {exc}")

        txt_path = Path(str(out_base) + ".txt")
        if result.returncode != 0:
            raise HTTPException(
                500,
                "Whisper failed: " + (result.stderr or result.stdout)[-3000:],
            )

        transcript = txt_path.read_text(encoding="utf-8", errors="replace").strip() if txt_path.exists() else ""

        return {
            "status": "ok",
            "transcript": transcript,
            "model": str(WHISPER_MODEL),
        }
