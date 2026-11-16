import re
from decimal import Decimal, ROUND_HALF_UP

import psycopg2.extras
from database import Database


class ErrorReserva(Exception):
    """Error de negocio con el código HTTP que debe devolver la API."""

    def __init__(self, mensaje, codigo=400):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.codigo = codigo


class AdminReservaService:
    """Reservas de todos los clientes, vistas por el administrador."""

    # fecha_reserva se guarda en UTC; los filtros por día usan la hora de Ecuador.
    ZONA = "America/Guayaquil"
    IVA = Decimal("1.15")
    POR_PAGINA = 10
    MAX_EXPORTAR = 5000
    ESTADOS = ("ACTIVA", "CANCELADA")
    PERIODOS = ("hoy", "7d", "mes", "todo")

    # Lo mismo que deja escribir el buscador de la app: letras (con tildes, ñ y ü),
    # números, espacios y @ . _ + -  (códigos, nombres, usuarios y correos).
    _NO_PERMITIDO_BUSQUEDA = re.compile(r"[^0-9A-Za-zÁÉÍÓÚÜÑáéíóúüñ @._+\-]")
    LARGO_BUSQUEDA = 50

    def _limpiar_busqueda(self, q):
        """Quita caracteres no permitidos y espacios de más; None si no queda nada que buscar."""
        q = self._NO_PERMITIDO_BUSQUEDA.sub("", q or "")
        q = " ".join(q.split())[: self.LARGO_BUSQUEDA].strip()
        return q if any(c.isalnum() for c in q) else None

    def _con_iva(self, valor):
        return float((Decimal(valor or 0) * self.IVA).quantize(Decimal("0.01"), ROUND_HALF_UP))

    def _filtros(self, q, periodo, vuelo_id):
        """WHERE común (sin el estado, para poder contar por pestaña)."""
        dia = f"((r.fecha_reserva AT TIME ZONE 'UTC') AT TIME ZONE '{self.ZONA}')::date"
        hoy = f"(NOW() AT TIME ZONE '{self.ZONA}')::date"
        condiciones = {
            "hoy": f"{dia} = {hoy}",
            "7d": f"{dia} > {hoy} - 7",
            "mes": f"date_trunc('month', {dia}) = date_trunc('month', {hoy})",
            "todo": "TRUE",
        }
        sql = f"""
            WHERE {condiciones[periodo]}
              AND (%(q)s IS NULL
                   OR r.codigo_reserva ILIKE %(patron)s
                   OR u.nombre_completo ILIKE %(patron)s
                   OR u.usuario ILIKE %(patron)s
                   OR u.correo ILIKE %(patron)s)
              AND (%(vuelo)s IS NULL OR r.vuelo_id = %(vuelo)s)
        """
        # En ILIKE "_" es comodín (cualquier carácter): se escapa para buscarlo tal cual
        patron = "%" + q.replace("_", r"\_") + "%" if q else None
        return sql, {"q": q, "patron": patron, "vuelo": vuelo_id}

    # ───────────────────────── Listar ─────────────────────────

    def listar(self, estado=None, q=None, periodo="todo", vuelo_id=None, pagina=1, exportar=False):
        estado = (estado or "").upper() or None
        if estado and estado not in self.ESTADOS:
            raise ErrorReserva("Estado de reserva no válido")
        periodo = (periodo or "todo").lower()
        if periodo not in self.PERIODOS:
            raise ErrorReserva("Periodo no válido")
        q = self._limpiar_busqueda(q)
        pagina = max(1, pagina or 1)

        where, params = self._filtros(q, periodo, vuelo_id)
        params.update({
            "estado": estado,
            "limite": self.MAX_EXPORTAR if exportar else self.POR_PAGINA,
            "desde": 0 if exportar else (pagina - 1) * self.POR_PAGINA,
        })
        desde = """
            FROM reservas r
            INNER JOIN usuarios u ON u.id = r.usuario_id
            INNER JOIN vuelos v ON v.id = r.vuelo_id
        """

        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            # Cantidad por pestaña (con la búsqueda y los filtros aplicados)
            cursor.execute(f"""
                SELECT COUNT(*) AS todas,
                       COUNT(*) FILTER (WHERE r.estado = 'ACTIVA') AS activas,
                       COUNT(*) FILTER (WHERE r.estado = 'CANCELADA') AS canceladas
                {desde} {where}
            """, params)
            c = cursor.fetchone()
            conteos = {"todas": c["todas"], "activas": c["activas"], "canceladas": c["canceladas"]}

            cursor.execute(f"""
                SELECT r.id, r.codigo_reserva, r.estado, r.total, r.cantidad_asientos,
                       r.fecha_reserva,
                       u.id AS usuario_id, u.nombre_completo, u.usuario, u.correo,
                       v.id AS vuelo_id, v.aerolinea, v.origen, v.destino, v.fecha,
                       v.hora_salida, v.estado AS vuelo_activo,
                       (v.fecha + v.hora_salida) <= (NOW() AT TIME ZONE '{self.ZONA}') AS vuelo_salio,
                       COALESCE((SELECT STRING_AGG(av.numero_asiento, ', ' ORDER BY av.numero_asiento)
                                 FROM asientos_vuelo av WHERE av.reserva_id = r.id), '') AS asientos
                {desde} {where}
                  AND (%(estado)s IS NULL OR r.estado = %(estado)s)
                ORDER BY r.fecha_reserva DESC, r.id DESC
                LIMIT %(limite)s OFFSET %(desde)s
            """, params)
            reservas = [self._a_dict(f) for f in cursor.fetchall()]

            # Vuelos que tienen reservas (para el filtro "Vuelo")
            cursor.execute("""
                SELECT DISTINCT v.id, v.origen, v.destino, v.fecha, v.hora_salida
                FROM vuelos v
                INNER JOIN reservas r ON r.vuelo_id = v.id
                ORDER BY v.fecha DESC, v.hora_salida DESC
            """)
            vuelos = [
                {"id": f["id"], "origen": f["origen"], "destino": f["destino"],
                 "fecha": str(f["fecha"]), "hora_salida": str(f["hora_salida"])}
                for f in cursor.fetchall()
            ]

            return {
                "reservas": reservas,
                "total": conteos[{"ACTIVA": "activas", "CANCELADA": "canceladas"}.get(estado, "todas")],
                "pagina": 1 if exportar else pagina,
                "por_pagina": self.POR_PAGINA,
                "conteos": conteos,
                "vuelos": vuelos,
            }
        finally:
            cursor.close()
            conexion.close()

    def _a_dict(self, f):
        return {
            "id": f["id"],
            "codigo": f["codigo_reserva"],
            "estado": f["estado"],
            "total": self._con_iva(f["total"]),
            "cantidad": f["cantidad_asientos"],
            "asientos": f["asientos"],
            # UTC con "Z" para que Flutter la pase a la hora local
            "fecha": f["fecha_reserva"].isoformat() + "Z",
            "cliente": {
                "id": f["usuario_id"],
                "nombre": f["nombre_completo"],
                "usuario": f["usuario"],
                "correo": f["correo"],
            },
            "vuelo": {
                "id": f["vuelo_id"],
                "aerolinea": f["aerolinea"],
                "origen": f["origen"],
                "destino": f["destino"],
                "fecha": str(f["fecha"]),
                "hora_salida": str(f["hora_salida"]),
                "cancelado": not f["vuelo_activo"],
                "salio": f["vuelo_salio"],
            },
        }

    # ───────────────────────── Cancelar ─────────────────────────

    def cancelar(self, reserva_id):
        """Cancela una reserva activa de cualquier cliente y libera sus asientos."""
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            # Mismo orden de bloqueo que las compras (vuelo → reserva) para no chocar
            cursor.execute("SELECT vuelo_id FROM reservas WHERE id = %s", (reserva_id,))
            fila = cursor.fetchone()
            if fila is None:
                raise ErrorReserva("Reserva no encontrada", 404)

            cursor.execute(f"""
                SELECT (fecha + hora_salida) <= (NOW() AT TIME ZONE '{self.ZONA}') AS salio
                FROM vuelos WHERE id = %s FOR UPDATE
            """, (fila["vuelo_id"],))
            salio = cursor.fetchone()["salio"]

            cursor.execute("""
                SELECT codigo_reserva, cantidad_asientos, estado
                FROM reservas WHERE id = %s FOR UPDATE
            """, (reserva_id,))
            reserva = cursor.fetchone()
            if reserva["estado"] != "ACTIVA":
                raise ErrorReserva("La reserva ya está cancelada", 409)
            if salio:
                raise ErrorReserva("No se puede cancelar: el vuelo ya salió", 409)

            cursor.execute("UPDATE reservas SET estado = 'CANCELADA' WHERE id = %s", (reserva_id,))
            cursor.execute("""
                UPDATE asientos_vuelo SET estado = 'DISPONIBLE', reserva_id = NULL
                WHERE reserva_id = %s
                RETURNING numero_asiento
            """, (reserva_id,))
            liberados = sorted(f["numero_asiento"] for f in cursor.fetchall())
            cursor.execute("""
                UPDATE vuelos
                SET asientos_disponibles = asientos_disponibles + %s, version = version + 1
                WHERE id = %s
            """, (reserva["cantidad_asientos"], fila["vuelo_id"]))

            conexion.commit()
            return {
                "mensaje": "Reserva cancelada",
                "codigo": reserva["codigo_reserva"],
                "asientos_liberados": liberados,
            }
        except Exception:
            conexion.rollback()
            raise
        finally:
            cursor.close()
            conexion.close()
