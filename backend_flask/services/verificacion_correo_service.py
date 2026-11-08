"""Verificación OTP: códigos efímeros, HMAC, caducidad e intentos limitados."""
import hashlib
import hmac
import os
import re
import secrets

from database import Database
from services.email_service import EmailService


class ErrorVerificacion(Exception):
    def __init__(self, mensaje: str, estado_http: int = 400):
        super().__init__(mensaje)
        self.estado_http = estado_http


class VerificacionCorreoService:
    MINUTOS_VIGENCIA = 10
    MAX_INTENTOS = 5
    REENVIO_SEGUNDOS = 60
    MAX_ENVIOS_HORA = 5

    @staticmethod
    def _secreto() -> str:
        secreto = os.getenv("OTP_SECRET", "")
        if len(secreto) < 32:
            raise RuntimeError("Configura OTP_SECRET con al menos 32 caracteres en .env")
        return secreto

    @staticmethod
    def nuevo_codigo() -> str:
        return f"{secrets.randbelow(1000000):06d}"

    @classmethod
    def hash_codigo(cls, usuario_id: int, codigo: str) -> str:
        mensaje = f"{usuario_id}:{codigo}".encode("utf-8")
        return hmac.new(cls._secreto().encode("utf-8"), mensaje, hashlib.sha256).hexdigest()

    @classmethod
    def guardar_codigo_nuevo(cls, cursor, usuario_id: int, codigo: str) -> None:
        huella = cls.hash_codigo(usuario_id, codigo)
        cursor.execute("""
            INSERT INTO public.verificaciones_correo
                (usuario_id, codigo_hash, expira_en, intentos, ultimo_envio,
                 ventana_inicio, envios_en_ventana)
            VALUES (%s, %s, NOW() + INTERVAL '10 minutes', 0, NOW(), NOW(), 1)
        """, (usuario_id, huella))

    @staticmethod
    def _permitir_reenvio_inmediato(usuario_id: int) -> None:
        """Si Resend falla, no penalizar con 60 segundos por un envío fallido."""
        conexion = Database.obtener_conexion()
        try:
            with conexion:
                with conexion.cursor() as cursor:
                    cursor.execute("""
                        UPDATE public.verificaciones_correo
                        SET ultimo_envio = NOW() - INTERVAL '61 seconds',
                            envios_en_ventana = GREATEST(0, envios_en_ventana - 1)
                        WHERE usuario_id = %s
                    """, (usuario_id,))
        finally:
            conexion.close()

    @classmethod
    def enviar_registro(cls, usuario_id: int, correo: str, codigo: str) -> bool:
        try:
            EmailService.enviar_codigo(correo, codigo)
            return True
        except Exception as exc:
            # El código nunca se imprime en logs.
            print(f"No se pudo enviar correo de registro: {type(exc).__name__}")
            cls._permitir_reenvio_inmediato(usuario_id)
            return False

    @classmethod
    def verificar(cls, correo: str, codigo: str) -> None:
        if not isinstance(correo, str) or not isinstance(codigo, str):
            raise ErrorVerificacion("Correo y código son obligatorios")
        correo = correo.strip().lower()
        if not re.fullmatch(r"[0-9]{6}", codigo):
            raise ErrorVerificacion("El código debe tener seis dígitos")

        conexion = Database.obtener_conexion()
        error = None
        try:
            with conexion:
                with conexion.cursor() as cursor:
                    cursor.execute("""
                        SELECT u.id, u.correo_verificado, v.codigo_hash,
                               v.expira_en > NOW(), v.intentos
                        FROM public.usuarios u
                        LEFT JOIN public.verificaciones_correo v ON v.usuario_id = u.id
                        WHERE LOWER(u.correo) = %s
                        FOR UPDATE OF u
                    """, (correo,))
                    fila = cursor.fetchone()
                    if not fila:
                        raise ErrorVerificacion("Código inválido o vencido")
                    usuario_id, verificado, huella, vigente, intentos = fila
                    if verificado:
                        return
                    if not huella or not vigente:
                        raise ErrorVerificacion("Código vencido. Solicita uno nuevo")
                    if intentos >= cls.MAX_INTENTOS:
                        raise ErrorVerificacion("Demasiados intentos. Solicita otro código", 429)
                    correcto = hmac.compare_digest(cls.hash_codigo(usuario_id, codigo), huella.strip())
                    if correcto:
                        cursor.execute("""
                            UPDATE public.usuarios SET correo_verificado = TRUE
                            WHERE id = %s
                        """, (usuario_id,))
                        cursor.execute("""
                            DELETE FROM public.verificaciones_correo WHERE usuario_id = %s
                        """, (usuario_id,))
                    else:
                        cursor.execute("""
                            UPDATE public.verificaciones_correo SET intentos = intentos + 1
                            WHERE usuario_id = %s
                        """, (usuario_id,))
                        # Mantener el contador: lanzar error después del commit.
                        error = ErrorVerificacion("Código incorrecto", 400)
            if error is not None:
                raise error
        finally:
            conexion.close()

    @classmethod
    def reenviar(cls, correo: str) -> bool:
        if not isinstance(correo, str) or len(correo.strip()) > 100 or "@" not in correo:
            raise ErrorVerificacion("Indica un correo válido")
        correo = correo.strip().lower()
        conexion = Database.obtener_conexion()
        usuario_id = None
        codigo = None
        try:
            with conexion:
                with conexion.cursor() as cursor:
                    cursor.execute("""
                        SELECT u.id, u.correo_verificado,
                               v.ultimo_envio, v.ventana_inicio, v.envios_en_ventana
                        FROM public.usuarios u
                        LEFT JOIN public.verificaciones_correo v ON v.usuario_id = u.id
                        WHERE LOWER(u.correo) = %s
                        FOR UPDATE OF u
                    """, (correo,))
                    fila = cursor.fetchone()
                    if not fila or fila[1]:
                        return True  # No revelar si el correo existe / ya está verificado.
                    usuario_id, _, ultimo_envio, ventana, cantidad = fila
                    from datetime import datetime, timezone, timedelta
                    ahora = datetime.now(timezone.utc)
                    if ultimo_envio is not None and ahora - ultimo_envio < timedelta(seconds=cls.REENVIO_SEGUNDOS):
                        raise ErrorVerificacion("Espera 60 segundos antes de reenviar", 429)
                    dentro_hora = ventana is not None and ahora - ventana < timedelta(hours=1)
                    if dentro_hora and cantidad >= cls.MAX_ENVIOS_HORA:
                        raise ErrorVerificacion("Límite de envíos alcanzado. Intenta en una hora", 429)
                    nueva_ventana = ventana if dentro_hora else ahora
                    nueva_cantidad = (cantidad or 0) + 1 if dentro_hora else 1
                    codigo = cls.nuevo_codigo()
                    huella = cls.hash_codigo(usuario_id, codigo)
                    cursor.execute("""
                        INSERT INTO public.verificaciones_correo
                            (usuario_id, codigo_hash, expira_en, intentos,
                             ultimo_envio, ventana_inicio, envios_en_ventana)
                        VALUES (%s, %s, NOW() + INTERVAL '10 minutes', 0, NOW(), %s, %s)
                        ON CONFLICT (usuario_id) DO UPDATE
                          SET codigo_hash = EXCLUDED.codigo_hash,
                              expira_en = EXCLUDED.expira_en,
                              intentos = 0, ultimo_envio = NOW(),
                              ventana_inicio = EXCLUDED.ventana_inicio,
                              envios_en_ventana = EXCLUDED.envios_en_ventana
                    """, (usuario_id, huella, nueva_ventana, nueva_cantidad))
            # Tras confirmar el cambio, enviar el código por Resend.
            try:
                EmailService.enviar_codigo(correo, codigo)
            except Exception as exc:
                print(f"No se pudo reenviar correo: {type(exc).__name__}")
                cls._permitir_reenvio_inmediato(usuario_id)
                raise ErrorVerificacion("No se pudo enviar el correo. Revisa Resend y la API Key", 503) from None
            return True
        finally:
            conexion.close()
