"""Registro en tres pasos con verificación obligatoria del correo.

Paso 1  enviar_codigo(correo)            -> envía un código de 6 dígitos.
Paso 2  verificar_codigo(correo, codigo) -> devuelve un token_registro temporal.
Paso 3  completar(datos)                 -> crea la cuenta ya verificada e inicia sesión.

La cuenta solo existe en public.usuarios después del paso 3.
"""
import hashlib
import hmac
import os
import re
import secrets
import unicodedata

import psycopg2
import psycopg2.extras

from database import Database
from services.auth_service import AuthService
from services.email_service import EmailService
from utils.seguridad import Seguridad


class ErrorRegistro(Exception):
    def __init__(self, mensaje: str, estado_http: int = 400, extra: dict | None = None):
        super().__init__(mensaje)
        self.estado_http = estado_http
        self.extra = extra or {}


_LETRAS = "A-Za-zÁÉÍÓÚÜÑáéíóúüñ"
RE_CORREO = re.compile(
    r"[A-Za-z0-9_%+\-]+(?:\.[A-Za-z0-9_%+\-]+)*@"
    r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
    r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+"
)
RE_USUARIO = re.compile(rf"[{_LETRAS}0-9._-]{{3,40}}")
RE_NOMBRE = re.compile(rf"[{_LETRAS}]+(?:[ '\u2019-]+[{_LETRAS}]+)*")
RE_CODIGO = re.compile(r"[0-9]{6}")

MENSAJES_DUPLICADO = {
    "usuarios_usuario_key": "Ese nombre de usuario ya está en uso",
    "usuarios_usuario_lower_key": "Ese nombre de usuario ya está en uso",
    "usuarios_cedula_key": "Ya existe una cuenta registrada con esta cédula",
    "usuarios_correo_key": "Ya existe una cuenta con este correo",
}


class RegistroService:
    MINUTOS_CODIGO = 10
    MINUTOS_TOKEN = 30
    MAX_INTENTOS = 5
    SEGUNDOS_REENVIO = 60
    MAX_ENVIOS_HORA = 5
    HORAS_PENDIENTE = 24

    # ------------------------------------------------------------------
    # Utilidades
    # ------------------------------------------------------------------
    @staticmethod
    def _secreto() -> bytes:
        secreto = os.getenv("OTP_SECRET", "")
        if len(secreto) < 32:
            raise RuntimeError("Configura OTP_SECRET con al menos 32 caracteres en .env")
        return secreto.encode("utf-8")

    @classmethod
    def _hash_codigo(cls, correo: str, codigo: str) -> str:
        mensaje = f"registro:{correo}:{codigo}".encode("utf-8")
        return hmac.new(cls._secreto(), mensaje, hashlib.sha256).hexdigest()

    @staticmethod
    def _hash_token(token: str) -> str:
        return hashlib.sha256(token.encode("utf-8")).hexdigest()

    @staticmethod
    def _normalizar_correo(correo) -> str:
        if not isinstance(correo, str) or not correo.strip():
            raise ErrorRegistro("Ingresa tu correo electrónico")
        correo = correo.strip().lower()
        if len(correo) > 100 or not RE_CORREO.fullmatch(correo):
            raise ErrorRegistro("Correo electrónico inválido")
        return correo

    @staticmethod
    def _cedula_valida(cedula: str) -> bool:
        if not re.fullmatch(r"[0-9]{10}", cedula):
            return False
        provincia = int(cedula[:2])
        if not ((1 <= provincia <= 24) or provincia == 30) or int(cedula[2]) >= 6:
            return False
        suma = 0
        for i, caracter in enumerate(cedula[:9]):
            d = int(caracter) * (2 if i % 2 == 0 else 1)
            suma += d - 9 if d > 9 else d
        return (10 - suma % 10) % 10 == int(cedula[9])

    @classmethod
    def _validar_perfil(cls, datos: dict):
        for campo in ("usuario", "nombre_completo", "cedula", "password"):
            if not isinstance(datos.get(campo), str) or not datos[campo]:
                raise ErrorRegistro(f"El campo {campo} es obligatorio")

        usuario = datos["usuario"].strip()
        nombre = " ".join(datos["nombre_completo"].strip().split())
        cedula = datos["cedula"].strip()
        password = datos["password"]  # Las contraseñas no se recortan.

        if not RE_USUARIO.fullmatch(usuario):
            raise ErrorRegistro("Usuario inválido: de 3 a 40 letras, números, . _ o -")
        if not 3 <= len(nombre) <= 80 or not RE_NOMBRE.fullmatch(nombre):
            raise ErrorRegistro("Nombre completo inválido")
        if not cls._cedula_valida(cedula):
            raise ErrorRegistro("Cédula ecuatoriana inválida")
        if not 8 <= len(password) <= 128 or password.isspace():
            raise ErrorRegistro("La contraseña debe tener entre 8 y 128 caracteres")
        if not re.search(f"[{_LETRAS}]", password) or not re.search(r"[0-9]", password):
            raise ErrorRegistro("La contraseña debe contener letras y números")
        if any(unicodedata.category(c) in ("Cc", "Cf", "Cs", "Co", "So") for c in password):
            raise ErrorRegistro("La contraseña contiene caracteres no admitidos")
        return usuario, nombre, cedula, password

    # ------------------------------------------------------------------
    # Paso 1: enviar (o reenviar) el código
    # ------------------------------------------------------------------
    @classmethod
    def enviar_codigo(cls, correo) -> dict:
        correo = cls._normalizar_correo(correo)
        codigo = f"{secrets.randbelow(1_000_000):06d}"
        huella = cls._hash_codigo(correo, codigo)

        conexion = Database.obtener_conexion()
        try:
            try:
                with conexion:
                    with conexion.cursor() as cursor:
                        # Limpieza de registros abandonados.
                        cursor.execute("""
                            DELETE FROM public.registros_pendientes
                            WHERE creado_en < NOW() - %s * INTERVAL '1 hour'
                        """, (cls.HORAS_PENDIENTE,))

                        cursor.execute("SELECT 1 FROM public.usuarios WHERE correo = %s", (correo,))
                        if cursor.fetchone():
                            raise ErrorRegistro(
                                "Ya existe una cuenta con este correo. Inicia sesión.", 409
                            )

                        cursor.execute("""
                            SELECT CEIL(EXTRACT(EPOCH FROM (
                                       ultimo_envio + %s * INTERVAL '1 second' - NOW()
                                   )))::int,
                                   NOW() - ventana_inicio < INTERVAL '1 hour',
                                   envios_en_ventana
                            FROM public.registros_pendientes
                            WHERE correo = %s
                            FOR UPDATE
                        """, (cls.SEGUNDOS_REENVIO, correo))
                        fila = cursor.fetchone()

                        if fila is None:
                            cursor.execute("""
                                INSERT INTO public.registros_pendientes
                                    (correo, codigo_hash, codigo_expira_en)
                                VALUES (%s, %s, NOW() + %s * INTERVAL '1 minute')
                            """, (correo, huella, cls.MINUTOS_CODIGO))
                        else:
                            espera, dentro_hora, envios = fila
                            if espera > 0:
                                raise ErrorRegistro(
                                    f"Espera {espera} segundos para pedir otro código",
                                    429, {"reintentar_en": espera},
                                )
                            if dentro_hora and envios >= cls.MAX_ENVIOS_HORA:
                                raise ErrorRegistro(
                                    "Alcanzaste el límite de códigos. Intenta en una hora", 429
                                )
                            # Un código nuevo invalida el anterior y cualquier verificación previa.
                            cursor.execute("""
                                UPDATE public.registros_pendientes
                                SET codigo_hash = %s,
                                    codigo_expira_en = NOW() + %s * INTERVAL '1 minute',
                                    intentos = 0,
                                    ultimo_envio = NOW(),
                                    ventana_inicio = CASE WHEN %s THEN ventana_inicio ELSE NOW() END,
                                    envios_en_ventana = CASE WHEN %s THEN envios_en_ventana + 1 ELSE 1 END,
                                    verificado_en = NULL,
                                    token_hash = NULL,
                                    token_expira_en = NULL,
                                    creado_en = NOW()
                                WHERE correo = %s
                            """, (huella, cls.MINUTOS_CODIGO, dentro_hora, dentro_hora, correo))
            except psycopg2.IntegrityError:
                # Dos solicitudes simultáneas para el mismo correo.
                raise ErrorRegistro("Espera unos segundos e inténtalo de nuevo", 429) from None

            # Se envía después de confirmar la transacción.
            try:
                EmailService.enviar_codigo(correo, codigo)
            except Exception as exc:
                print(f"No se pudo enviar el código de registro: {type(exc).__name__}")
                # Un envío fallido no debe penalizar al usuario con la espera.
                with conexion:
                    with conexion.cursor() as cursor:
                        cursor.execute("""
                            UPDATE public.registros_pendientes
                            SET ultimo_envio = NOW() - %s * INTERVAL '1 second',
                                envios_en_ventana = GREATEST(0, envios_en_ventana - 1)
                            WHERE correo = %s
                        """, (cls.SEGUNDOS_REENVIO + 1, correo))
                raise ErrorRegistro(
                    "No pudimos enviar el código. Inténtalo de nuevo en unos segundos", 503
                ) from None
        finally:
            conexion.close()

        return {
            "mensaje": "Te enviamos un código de verificación",
            "correo": correo,
            "expira_en_minutos": cls.MINUTOS_CODIGO,
            "reenviar_en_segundos": cls.SEGUNDOS_REENVIO,
        }

    # ------------------------------------------------------------------
    # Paso 2: verificar el código
    # ------------------------------------------------------------------
    @classmethod
    def verificar_codigo(cls, correo, codigo) -> dict:
        correo = cls._normalizar_correo(correo)
        if not isinstance(codigo, str) or not RE_CODIGO.fullmatch(codigo.strip()):
            raise ErrorRegistro("El código debe tener seis dígitos")
        codigo = codigo.strip()
        token = secrets.token_urlsafe(32)
        error = None

        conexion = Database.obtener_conexion()
        try:
            with conexion:
                with conexion.cursor() as cursor:
                    cursor.execute("""
                        SELECT codigo_hash, codigo_expira_en > NOW(), intentos
                        FROM public.registros_pendientes
                        WHERE correo = %s
                        FOR UPDATE
                    """, (correo,))
                    fila = cursor.fetchone()
                    if fila is None or fila[0] is None:
                        raise ErrorRegistro("No hay un código activo. Solicita uno nuevo", 400)

                    huella, vigente, intentos = fila
                    if not vigente:
                        raise ErrorRegistro("El código venció. Solicita uno nuevo", 410)
                    if intentos >= cls.MAX_INTENTOS:
                        raise ErrorRegistro("Demasiados intentos. Solicita un código nuevo", 429)

                    if hmac.compare_digest(cls._hash_codigo(correo, codigo), huella.strip()):
                        cursor.execute("""
                            UPDATE public.registros_pendientes
                            SET codigo_hash = NULL,
                                codigo_expira_en = NULL,
                                verificado_en = NOW(),
                                token_hash = %s,
                                token_expira_en = NOW() + %s * INTERVAL '1 minute'
                            WHERE correo = %s
                        """, (cls._hash_token(token), cls.MINUTOS_TOKEN, correo))
                    else:
                        cursor.execute("""
                            UPDATE public.registros_pendientes
                            SET intentos = intentos + 1
                            WHERE correo = %s
                            RETURNING intentos
                        """, (correo,))
                        restantes = cls.MAX_INTENTOS - cursor.fetchone()[0]
                        # El contador se guarda; el error se lanza después del commit.
                        error = ErrorRegistro(
                            f"Código incorrecto. Te quedan {restantes} intentos"
                            if restantes > 0 else "Código incorrecto. Solicita un código nuevo",
                            400 if restantes > 0 else 429,
                            {"intentos_restantes": restantes},
                        )
            if error is not None:
                raise error
        finally:
            conexion.close()

        return {
            "mensaje": "Correo verificado",
            "token_registro": token,
            "expira_en_minutos": cls.MINUTOS_TOKEN,
        }

    # ------------------------------------------------------------------
    # Paso 3: completar los datos y crear la cuenta
    # ------------------------------------------------------------------
    @classmethod
    def completar(cls, datos) -> dict:
        if not isinstance(datos, dict):
            raise ErrorRegistro("El registro debe contener un objeto JSON")
        token = datos.get("token_registro")
        if not isinstance(token, str) or not 20 <= len(token) <= 100:
            raise ErrorRegistro("Verificación inválida. Vuelve a empezar el registro", 401)
        usuario, nombre, cedula, password = cls._validar_perfil(datos)

        conexion = Database.obtener_conexion()
        try:
            with conexion:
                with conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                    cursor.execute("""
                        SELECT id, correo
                        FROM public.registros_pendientes
                        WHERE token_hash = %s
                          AND token_expira_en > NOW()
                        FOR UPDATE
                    """, (cls._hash_token(token),))
                    pendiente = cursor.fetchone()
                    if pendiente is None:
                        raise ErrorRegistro(
                            "Tu verificación expiró. Vuelve a empezar el registro", 410
                        )

                    cursor.execute("""
                        INSERT INTO public.usuarios
                            (usuario, password_hash, nombre_completo, correo,
                             cedula, rol, estado, correo_verificado)
                        VALUES (%s, %s, %s, %s, %s, 'user', TRUE, TRUE)
                        RETURNING id, usuario, nombre_completo, correo, rol
                    """, (
                        usuario, Seguridad.generar_hash(password), nombre,
                        pendiente["correo"], cedula,
                    ))
                    fila = cursor.fetchone()

                    cursor.execute(
                        "DELETE FROM public.registros_pendientes WHERE id = %s",
                        (pendiente["id"],),
                    )
                    return AuthService.crear_sesion(cursor, fila, "Cuenta creada correctamente")
        except psycopg2.IntegrityError as exc:
            if exc.pgcode == "23505":
                mensaje = MENSAJES_DUPLICADO.get(
                    exc.diag.constraint_name, "Algunos datos ya están registrados"
                )
                # La transacción se revierte: el token sigue válido para corregir y reintentar.
                raise ErrorRegistro(mensaje, 409) from None
            raise
        finally:
            conexion.close()
