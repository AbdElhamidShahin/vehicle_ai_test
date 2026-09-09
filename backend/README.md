# Vehicle AI Test Backend

## Windows

```powershell
cd backend
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Then set `backendUrl` in `lib/main.dart` to the PC LAN IP, for example:
`http://192.168.1.20:8000`

The current endpoint verifies phone-to-PC audio upload. The free Egyptian-Arabic ASR model is connected in the next step.
