"""
Prototipo temporal para probar la app Flutter en tu red local.

1) Instala dependencias (en esta carpeta `backend/`):
   python -m venv .venv
   .venv\\Scripts\\activate
   pip install -r requirements.txt

2) Arranca el servidor escuchando en todas las interfaces:
   uvicorn main:app --reload --host 0.0.0.0 --port 8000

3) En tu PC, obtén tu IP LAN (ej. 192.168.1.45) y en el celular (misma WiFi)
   corre Flutter con:
   flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://TU_IP:8000

Endpoints que consume la app:
  POST /auth/login   body: {"username":"...","password":"..."}
  GET  /auth/me      header: Authorization: Bearer <token>
  GET  /otp/current  header: Authorization: Bearer <token>

Extra (para probar desde Postman/curl sin FCM):
  POST /otp/issue    header: Authorization: Bearer <token>  -> genera un código nuevo
"""

from __future__ import annotations

import secrets
import string
from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

app = FastAPI(title="Exel OTT API (prototipo)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer(auto_error=False)

# token -> user payload
_sessions: dict[str, dict] = {}
# token -> {"code": str, "expires_at": datetime}
_otp: dict[str, dict] = {}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _random_code() -> str:
    return "".join(secrets.choice(string.digits) for _ in range(6))


class LoginBody(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    user: dict


def _issue_otp(token: str) -> dict:
    code = _random_code()
    exp = _now() + timedelta(minutes=2)
    _otp[token] = {"code": code, "expires_at": exp}
    return {"code": code, "expires_at": exp.isoformat()}


def get_token(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
) -> str:
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Falta Authorization Bearer")
    token = creds.credentials
    if token not in _sessions:
        raise HTTPException(status_code=401, detail="Token inválido")
    return token


@app.post("/auth/login", response_model=LoginResponse)
def auth_login(body: LoginBody):
    u = body.username.strip().lower()
    p = body.password.strip()
    ok = (u in {"demo@exel.com.mx", "demo@exel.com"} and p == "demo") or (
        u == "demo" and p == "demo"
    )
    if not ok:
        raise HTTPException(status_code=401, detail="Credenciales inválidas")

    token = secrets.token_urlsafe(32)
    user = {
        "name": "JOSE LUIS SEGURA HERNANDEZ",
        "email": "demo@exel.com.mx",
        "regions": "CH,CJ,CN,GD,HE,LC,LG,MD,MX,...",
    }
    _sessions[token] = user
    _issue_otp(token)
    return LoginResponse(access_token=token, user=user)


@app.get("/auth/me")
def auth_me(token: Annotated[str, Depends(get_token)]):
    return _sessions[token]


@app.get("/otp/current")
def otp_current(token: Annotated[str, Depends(get_token)]):
    data = _otp.get(token)
    if not data:
        return None
    exp: datetime = data["expires_at"]
    if _now() > exp:
        return {"code": "", "expires_at": ""}
    return {"code": data["code"], "expires_at": exp.isoformat()}


@app.post("/otp/issue")
def otp_issue(token: Annotated[str, Depends(get_token)]):
    """Genera un OTP nuevo (simula que el backend lo emitió / notificó)."""
    return _issue_otp(token)


@app.get("/health")
def health():
    return {"ok": True, "time": _now().isoformat()}
