import psycopg2.extras
from database import Database


class ErrorUsuario(Exception):
    """Error de negocio con el código HTTP que debe devolver la API."""

    def __init__(self, mensaje, codigo=400):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.codigo = codigo


class AdminUsuarioService:
    """Cuentas de la aplicación vistas por el administrador."""

    POR_PAGINA = 10
    ROLES = ("user", "admin")
    ESTADOS = ("activo", "suspendido")

    # ───────────────────────── Listar ─────────────────────────

    def listar(self, yo_id, q=None, rol=None, estado=None, pagina=1):
        rol = (rol or "").lower() or None
        if rol and rol not in self.ROLES:
            raise ErrorUsuario("Rol no válido")
        estado = (estado or "").lower() or None
        if estado and estado not in self.ESTADOS:
            raise ErrorUsuario("Estado no válido")
        q = (q or "").strip() or None
        pagina = max(1, pagina or 1)

        params = {
            "q": q,
            "patron": f"%{q}%" if q else None,
            "rol": rol,
            "activo": None if estado is None else estado == "activo",
            "limite": self.POR_PAGINA,
            "desde": (pagina - 1) * self.POR_PAGINA,
            "yo": yo_id,
        }
        where = """
            WHERE (%(q)s IS NULL
                   OR u.nombre_completo ILIKE %(patron)s
                   OR u.usuario ILIKE %(patron)s
                   OR u.correo ILIKE %(patron)s)
              AND (%(rol)s IS NULL OR u.rol = %(rol)s)
              AND (%(activo)s IS NULL OR COALESCE(u.estado, TRUE) = %(activo)s)
        """

        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            # Resumen de todas las cuentas (para el subtítulo, sin filtros)
            cursor.execute("""
                SELECT COUNT(*) AS cuentas,
                       COUNT(*) FILTER (WHERE rol = 'admin') AS administradores,
                       COUNT(*) FILTER (WHERE estado = FALSE) AS suspendidas
                FROM usuarios
            """)
            resumen = dict(cursor.fetchone())

            cursor.execute(f"SELECT COUNT(*) AS total FROM usuarios u {where}", params)
            total = cursor.fetchone()["total"]

            # Primero los administradores y luego las cuentas más nuevas
            cursor.execute(f"""
                SELECT u.id, u.usuario, u.nombre_completo, u.correo, u.rol,
                       u.correo_verificado, COALESCE(u.estado, TRUE) AS activo,
                       u.fecha_creacion,
                       (SELECT COUNT(*) FROM reservas r
                        WHERE r.usuario_id = u.id AND r.estado = 'ACTIVA') AS reservas
                FROM usuarios u
                {where}
                ORDER BY (u.rol = 'admin') DESC, u.fecha_creacion DESC NULLS LAST, u.id DESC
                LIMIT %(limite)s OFFSET %(desde)s
            """, params)
            usuarios = [self._a_dict(f, yo_id) for f in cursor.fetchall()]

            return {
                "usuarios": usuarios,
                "total": total,
                "pagina": pagina,
                "por_pagina": self.POR_PAGINA,
                "resumen": resumen,
            }
        finally:
            cursor.close()
            conexion.close()

    def _a_dict(self, f, yo_id):
        return {
            "id": f["id"],
            "usuario": f["usuario"],
            "nombre": f["nombre_completo"],
            "correo": f["correo"],
            "rol": f["rol"],
            "verificado": bool(f["correo_verificado"]),
            "activo": bool(f["activo"]),
            "reservas": f["reservas"],
            "desde": f["fecha_creacion"].isoformat() if f["fecha_creacion"] else None,
            "es_yo": f["id"] == yo_id,
        }

    # ───────────────────────── Acciones ─────────────────────────

    def _bloquear(self, cursor, usuario_id):
        cursor.execute("""
            SELECT id, usuario, nombre_completo, rol, COALESCE(estado, TRUE) AS activo
            FROM usuarios WHERE id = %s FOR UPDATE
        """, (usuario_id,))
        fila = cursor.fetchone()
        if fila is None:
            raise ErrorUsuario("Usuario no encontrado", 404)
        return fila

    @staticmethod
    def _cerrar_sesiones(cursor, usuario_id):
        cursor.execute("""
            UPDATE tokens SET activo = FALSE
            WHERE usuario_id = %s AND activo = TRUE
        """, (usuario_id,))
        return cursor.rowcount

    def cambiar_rol(self, yo_id, usuario_id, rol):
        """Hace o deja de hacer administrador a una cuenta."""
        rol = (rol or "").lower()
        if rol not in self.ROLES:
            raise ErrorUsuario("Rol no válido")
        if usuario_id == yo_id:
            raise ErrorUsuario("No puedes cambiar tu propio rol", 409)

        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            u = self._bloquear(cursor, usuario_id)
            if u["rol"] == rol:
                raise ErrorUsuario(
                    "La cuenta ya es administradora" if rol == "admin"
                    else "La cuenta ya es de cliente", 409)

            cursor.execute("UPDATE usuarios SET rol = %s WHERE id = %s", (rol, usuario_id))
            # Al volver a entrar abrirá la aplicación que le corresponde
            self._cerrar_sesiones(cursor, usuario_id)
            conexion.commit()
            return {
                "mensaje": "Rol actualizado",
                "id": usuario_id,
                "usuario": u["usuario"],
                "rol": rol,
            }
        except Exception:
            conexion.rollback()
            raise
        finally:
            cursor.close()
            conexion.close()

    def cambiar_estado(self, yo_id, usuario_id, activo):
        """Suspende o reactiva una cuenta. Sus reservas no se tocan."""
        if not isinstance(activo, bool):
            raise ErrorUsuario("Falta indicar si la cuenta queda activa")
        if usuario_id == yo_id:
            raise ErrorUsuario("No puedes suspender tu propia cuenta", 409)

        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            u = self._bloquear(cursor, usuario_id)
            if u["activo"] == activo:
                raise ErrorUsuario(
                    "La cuenta ya está activa" if activo
                    else "La cuenta ya está suspendida", 409)

            cursor.execute("UPDATE usuarios SET estado = %s WHERE id = %s", (activo, usuario_id))
            sesiones = 0
            if not activo:
                sesiones = self._cerrar_sesiones(cursor, usuario_id)
                # Suelta los asientos que tenía apartados en el carrito
                cursor.execute("""
                    UPDATE asientos_vuelo
                    SET bloqueado_por = NULL, bloqueado_hasta = NULL
                    WHERE bloqueado_por = %s
                """, (usuario_id,))
            conexion.commit()
            return {
                "mensaje": "Cuenta reactivada" if activo else "Cuenta suspendida",
                "id": usuario_id,
                "usuario": u["usuario"],
                "activo": activo,
                "sesiones_cerradas": sesiones,
            }
        except Exception:
            conexion.rollback()
            raise
        finally:
            cursor.close()
            conexion.close()
