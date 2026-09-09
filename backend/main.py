import json
import os
from pathlib import Path
from tempfile import NamedTemporaryFile

from fastapi import FastAPI, File, UploadFile, HTTPException
from faster_whisper import WhisperModel
from google import genai

app = FastAPI(title="Vehicle AI Test Backend")

# Free Gemini API key from https://aistudio.google.com/apikey (no credit card
# needed). Set it as an environment variable before starting the server:
#   $env:GEMINI_API_KEY = "your-key-here"
gemini_client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])

# gemini-2.5-flash-lite has the most generous free daily quota; switch to
# gemini-2.5-flash if you want slightly stronger reasoning and can live with
# a lower daily request cap.
GEMINI_MODEL = "gemini-2.5-flash-lite"

# Loaded once at server startup. "small" is a good CPU speed/accuracy
# balance; switch to "medium" for better Arabic accuracy if your PC can
# handle the extra load, or "base" if it's too slow.
whisper_model = WhisperModel("small", device="cpu", compute_type="int8")


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/process-audio")
async def process_audio(audio: UploadFile = File(...)):
    suffix = Path(audio.filename or "audio.m4a").suffix or ".m4a"
    data = await audio.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty audio")

    # faster-whisper needs a real file on disk (it shells out to ffmpeg
    # internally), so we write the upload to a temp file first.
    with NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(data)
        tmp_path = tmp.name

    try:
        segments, _ = whisper_model.transcribe(tmp_path, language="ar")
        transcript = " ".join(seg.text.strip() for seg in segments).strip()
    finally:
        os.unlink(tmp_path)

    if not transcript:
        return {
            "transcript": "",
            "plate_number": "",
            "vehicle_type": "",
            "address": "",
            "status": "needs_review",
            "error": "لم يتم التعرف على أي كلام في التسجيل",
        }

    prompt = f"""أنت نظام لاستخراج بيانات تسجيل السيارات من نص مسموع بالعامية المصرية.
هذا هو النص المسموع: "{transcript}"

استخرج منه:
1. رقم اللوحة
2. نوع المركبة
3. العنوان أو المكان

أجب بـ JSON فقط بهذا الشكل بدون أي نص إضافي أو Markdown:
{{"plate_number": "رقم اللوحة", "vehicle_type": "نوع المركبة", "address": "العنوان"}}"""

    try:
        response = gemini_client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
        )
        text = response.text.strip()
    except Exception as e:
        return {
            "transcript": transcript,
            "plate_number": "",
            "vehicle_type": "",
            "address": "",
            "status": "needs_review",
            "error": f"خطأ في استدعاء Gemini API: {e}",
        }

    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
        text = text.strip()

    try:
        parsed = json.loads(text)
    except Exception:
        parsed = {"plate_number": "", "vehicle_type": "", "address": ""}

    result = {
        "transcript": transcript,
        "plate_number": parsed.get("plate_number", ""),
        "vehicle_type": parsed.get("vehicle_type", ""),
        "address": parsed.get("address", ""),
    }
    result["status"] = "needs_review" if not result["plate_number"] else "ok"
    result["error"] = ""
    return result