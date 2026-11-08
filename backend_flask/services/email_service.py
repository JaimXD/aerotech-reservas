"""Envío de correos de AeroTech Reservas mediante la API HTTPS de Resend.

Las credenciales se leen exclusivamente desde backend_flask/.env.
Nunca colocar RESEND_API_KEY en código Flutter ni en el repositorio.
"""
from html import escape
import os
import re

import requests


class EmailService:
    URL_API = "https://api.resend.com/emails"

    @staticmethod
    def _enviar(correo_destino: str, asunto: str, contenido_html: str, contenido_texto: str) -> str:
        api_key = os.getenv("RESEND_API_KEY", "").strip()
        remitente = os.getenv("EMAIL_FROM", "").strip()

        if not api_key or not remitente:
            raise RuntimeError("Configura RESEND_API_KEY y EMAIL_FROM en backend_flask/.env")
        if not correo_destino or "@" not in correo_destino:
            raise ValueError("El correo de destino no es válido")

        try:
            respuesta = requests.post(
                EmailService.URL_API,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "from": remitente,
                    "to": [correo_destino],
                    "subject": asunto,
                    "html": contenido_html,
                    "text": contenido_texto,
                },
                timeout=15,
            )
        except requests.RequestException as exc:
            raise RuntimeError("No se pudo establecer conexión con la API de Resend") from exc

        if not respuesta.ok:
            try:
                detalle = respuesta.json()
                mensaje = str(detalle.get("message", "Solicitud rechazada"))[:180]
            except ValueError:
                mensaje = "Solicitud rechazada"
            raise RuntimeError(f"Resend rechazó el correo (HTTP {respuesta.status_code}): {mensaje}")

        try:
            return str(respuesta.json().get("id", "sin identificador"))
        except ValueError:
            return "sin identificador"

    @staticmethod
    def enviar_codigo(correo_destino: str, codigo: str) -> None:
        if not re.fullmatch(r"[0-9]{6}", codigo):
            raise ValueError("El código de verificación debe tener 6 dígitos")

        codigo_seguro = escape(codigo)
        html = f"""<!doctype html>
<html lang="es"><body style="margin:0;padding:32px 12px;background:#f5efe8;font-family:Arial,sans-serif;color:#3f2b22">
  <div style="max-width:520px;margin:auto;background:#fff;border-radius:18px;padding:32px;border:1px solid #e7dbd1">
    <p style="color:#865940;font-size:13px;font-weight:700;letter-spacing:1px">AEROTECH RESERVAS</p>
    <h1 style="font-size:26px;margin:12px 0">Verifica tu correo electrónico</h1>
    <p style="line-height:1.6">Utiliza este código para activar tu cuenta:</p>
    <div style="font-size:37px;letter-spacing:10px;font-weight:800;text-align:center;background:#f5efe8;padding:19px;border-radius:12px">{codigo_seguro}</div>
    <p style="line-height:1.6">El código vence en <strong>10 minutos</strong> y solo puede utilizarse una vez.</p>
    <p style="color:#75685f;font-size:13px">Si no solicitaste una cuenta en AeroTech Reservas, ignora este correo.</p>
  </div>
</body></html>"""
        texto = (
            "AeroTech Reservas\n\n"
            f"Tu código de verificación es: {codigo}\n"
            "Caduca en 10 minutos y solo puede usarse una vez.\n"
            "Si no solicitaste esta cuenta, ignora el mensaje."
        )
        EmailService._enviar(
            correo_destino,
            "AeroTech Reservas | Verifica tu correo",
            html,
            texto,
        )

    @staticmethod
    def enviar_prueba(correo_destino: str) -> str:
        """Prueba aislada: no genera códigos OTP ni modifica Supabase."""
        return EmailService._enviar(
            correo_destino,
            "AeroTech Reservas | Prueba de envío con Resend",
            "<h2>Correo de prueba</h2><p>La integración de AeroTech Reservas con Resend funciona.</p>",
            "Correo de prueba: la integración de AeroTech Reservas con Resend funciona.",
        )
