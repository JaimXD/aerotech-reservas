import hashlib
import json
import base64
import hmac
import os
from datetime import datetime, timedelta, timezone

SECRET_KEY = os.getenv("JWT_SECRET", "aerotech_super_secret_key_12345")

def base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('utf-8')

def base64url_decode(data: str) -> bytes:
    padding = '=' * (4 - len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)

class Seguridad:
    @staticmethod
    def generar_hash(password):
        return hashlib.sha256(password.encode("utf-8")).hexdigest()

    @staticmethod
    def generar_token(payload_data):
        # We accept a payload dictionary, add 'exp', and build the JWT
        header = {"alg": "HS256", "typ": "JWT"}
        header_b64 = base64url_encode(json.dumps(header, separators=(',', ':')).encode('utf-8'))
        
        payload = payload_data.copy()
        exp_time = datetime.now(timezone.utc) + timedelta(hours=2)
        payload["exp"] = int(exp_time.timestamp())
        
        payload_b64 = base64url_encode(json.dumps(payload, separators=(',', ':')).encode('utf-8'))
        
        signature = hmac.new(
            SECRET_KEY.encode('utf-8'),
            f"{header_b64}.{payload_b64}".encode('utf-8'),
            hashlib.sha256
        ).digest()
        signature_b64 = base64url_encode(signature)
        
        return f"{header_b64}.{payload_b64}.{signature_b64}"

    @staticmethod
    def verificar_token(token):
        try:
            parts = token.split('.')
            if len(parts) != 3:
                return None
            header_b64, payload_b64, signature_b64 = parts
            
            expected_signature = hmac.new(
                SECRET_KEY.encode('utf-8'),
                f"{header_b64}.{payload_b64}".encode('utf-8'),
                hashlib.sha256
            ).digest()
            expected_signature_b64 = base64url_encode(expected_signature)
            
            if not hmac.compare_digest(signature_b64, expected_signature_b64):
                return None
                
            payload = json.loads(base64url_decode(payload_b64).decode('utf-8'))
            
            exp = payload.get("exp")
            if exp and datetime.now(timezone.utc).timestamp() > exp:
                return None
                
            return payload
        except Exception:
            return None

    @staticmethod
    def fecha_expiracion_token():
        return datetime.now(timezone.utc) + timedelta(hours=2)

