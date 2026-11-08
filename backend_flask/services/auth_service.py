import psycopg2.extras
from database import Database
from utils.seguridad import Seguridad


class AuthService:

    @staticmethod
    def crear_sesion(cursor, fila, mensaje="Login correcto"):
        """Emite el token y lo registra. Se ejecuta dentro de la transacción de quien llama."""
        datos_usuario = {
            "id": fila["id"],
            "usuario": fila["usuario"],
            "nombre_completo": fila["nombre_completo"],
            "correo": fila["correo"],
            "role": fila["rol"],
            "tipo_usuario": fila["rol"],
        }
        token = Seguridad.generar_token(datos_usuario)
        expiracion = Seguridad.fecha_expiracion_token()

        cursor.execute("""
            INSERT INTO tokens (usuario_id, token, fecha_expiracion, activo)
            VALUES (%s, %s, NOW() + INTERVAL '2 hours', TRUE)
        """, (fila["id"], token))

        return {
            "mensaje": mensaje,
            "usuario": datos_usuario,
            "token": token,
            "expiracion": expiracion.isoformat(),
        }

    def login(self, usuario, password):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            password_hash = Seguridad.generar_hash(password)

            cursor.execute("""
                SELECT id, usuario, nombre_completo, correo, rol, correo_verificado
                FROM usuarios
                WHERE LOWER(usuario) = LOWER(%s)
                  AND password_hash = %s
                  AND estado = TRUE
            """, (usuario, password_hash))

            fila = cursor.fetchone()

            if fila is None:
                return None

            # Segunda barrera: con el registro nuevo no deberían existir
            # cuentas sin verificar, pero se mantiene el control.
            if not fila["correo_verificado"]:
                return {"correo_pendiente": True}

            resultado = self.crear_sesion(cursor, fila)
            conexion.commit()
            return resultado

        except Exception as e:
            conexion.rollback()
            raise e

        finally:
            cursor.close()
            conexion.close()

    def validar_token(self, token):
        payload = Seguridad.verificar_token(token)
        if payload is None:
            return None

        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            cursor.execute("""
                SELECT u.id, u.usuario, u.nombre_completo, u.correo, u.rol
                FROM tokens t
                INNER JOIN usuarios u ON u.id = t.usuario_id
                WHERE t.token = %s
                  AND t.activo = TRUE
                  AND t.fecha_expiracion > NOW()
                  AND u.estado = TRUE
                  AND u.correo_verificado = TRUE
            """, (token,))

            fila = cursor.fetchone()

            if fila is None:
                return None

            return {
                "id": fila["id"],
                "usuario": fila["usuario"],
                "nombre_completo": fila["nombre_completo"],
                "correo": fila["correo"],
                "role": fila["rol"],
                "tipo_usuario": fila["rol"]
            }

        finally:
            cursor.close()
            conexion.close()
