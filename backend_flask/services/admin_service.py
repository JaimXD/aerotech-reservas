from decimal import Decimal, ROUND_HALF_UP

import psycopg2.extras
from database import Database


class AdminService:
    """Datos del panel del administrador."""

    # Supabase guarda NOW() en UTC; las fechas del panel son las de Ecuador.
    ZONA = "America/Guayaquil"
    IVA = Decimal("1.15")

    def obtener_panel(self):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            return {
                **self._ventas_y_reservas(cursor),
                "ocupacion": self._ocupacion(cursor),
                "en_carritos": self._en_carritos(cursor),
                "ventas_semana": self._ventas_semana(cursor),
                "proximas_salidas": self._proximas_salidas(cursor),
                "ultimas_reservas": self._ultimas_reservas(cursor),
            }
        finally:
            cursor.close()
            conexion.close()

    # ───────────────────────── Cambios ─────────────────────────

    def obtener_cambios(self):
        """Huella de cada grupo de datos para que la app se actualice sola.

        La app la consulta cada pocos segundos y solo recarga una sección
        cuando cambia la huella de algo que esa sección muestra.
        """
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor()
        try:
            cursor.execute(f"""
                SELECT
                    -- Cualquier cambio en un vuelo, y los que van saliendo con la hora
                    (SELECT md5(COALESCE(string_agg(v::text, '|' ORDER BY v.id), ''))
                            || ':' || COUNT(*) FILTER (
                                WHERE (v.fecha + v.hora_salida) <= (NOW() AT TIME ZONE '{self.ZONA}'))
                     FROM vuelos v),
                    -- Las reservas solo se crean o se cancelan
                    (SELECT COUNT(*) || ':' || COALESCE(MAX(id), 0) || ':'
                            || COUNT(*) FILTER (WHERE estado = 'CANCELADA')
                     FROM reservas),
                    (SELECT md5(COALESCE(string_agg(
                                concat_ws(',', id, usuario, nombre_completo, correo,
                                          rol, estado, correo_verificado),
                                '|' ORDER BY id), ''))
                     FROM usuarios),
                    -- Asientos apartados ahora mismo (cambia también cuando vencen)
                    (SELECT md5(COALESCE(string_agg(
                                concat_ws(',', id, bloqueado_por, bloqueado_hasta),
                                '|' ORDER BY id), ''))
                     FROM asientos_vuelo WHERE bloqueado_hasta > NOW())
            """)
            vuelos, reservas, usuarios, carritos = cursor.fetchone()
            return {
                "vuelos": vuelos,
                "reservas": reservas,
                "usuarios": usuarios,
                "carritos": carritos,
            }
        finally:
            cursor.close()
            conexion.close()

    # ───────────────────────── Ayudantes ─────────────────────────

    def _con_iva(self, valor):
        return float((Decimal(valor or 0) * self.IVA).quantize(Decimal("0.01"), ROUND_HALF_UP))

    def _hoy_sql(self):
        return f"(NOW() AT TIME ZONE '{self.ZONA}')::date"

    def _dia_reserva_sql(self, columna="r.fecha_reserva"):
        # fecha_reserva es "timestamp without time zone" guardado en UTC
        return f"(({columna} AT TIME ZONE 'UTC') AT TIME ZONE '{self.ZONA}')::date"

    # ───────────────────────── Indicadores ─────────────────────────

    def _ventas_y_reservas(self, cursor):
        hoy = self._hoy_sql()
        dia = self._dia_reserva_sql()
        cursor.execute(f"""
            SELECT
                COALESCE(SUM(r.total) FILTER (WHERE {dia} = {hoy} AND r.estado = 'ACTIVA'), 0) AS ventas_hoy,
                COALESCE(SUM(r.total) FILTER (WHERE {dia} = {hoy} - 1 AND r.estado = 'ACTIVA'), 0) AS ventas_ayer,
                COUNT(*) FILTER (WHERE {dia} = {hoy}) AS reservas_hoy,
                COUNT(*) FILTER (WHERE {dia} = {hoy} AND r.estado = 'CANCELADA') AS canceladas_hoy
            FROM reservas r
        """)
        fila = cursor.fetchone()

        hoy_total = Decimal(fila["ventas_hoy"])
        ayer_total = Decimal(fila["ventas_ayer"])
        variacion = None
        if ayer_total > 0:
            variacion = float(((hoy_total - ayer_total) / ayer_total * 100).quantize(Decimal("1"), ROUND_HALF_UP))

        return {
            "ventas_hoy": self._con_iva(hoy_total),
            "variacion_ventas": variacion,  # % frente a ayer (None si ayer no hubo ventas)
            "reservas_hoy": fila["reservas_hoy"],
            "canceladas_hoy": fila["canceladas_hoy"],
        }

    def _ocupacion(self, cursor):
        """Asientos vendidos / asientos totales de los vuelos que aún no salen."""
        cursor.execute(f"""
            SELECT
                COUNT(*) FILTER (WHERE av.estado = 'RESERVADO') AS vendidos,
                COUNT(*) AS total
            FROM asientos_vuelo av
            INNER JOIN vuelos v ON v.id = av.vuelo_id
            WHERE v.estado = TRUE
              AND v.fecha >= {self._hoy_sql()}
        """)
        fila = cursor.fetchone()
        if not fila["total"]:
            return 0
        return round(fila["vendidos"] * 100 / fila["total"])

    def _en_carritos(self, cursor):
        cursor.execute("""
            SELECT COUNT(*) AS asientos, COUNT(DISTINCT bloqueado_por) AS clientes
            FROM asientos_vuelo
            WHERE estado = 'DISPONIBLE'
              AND bloqueado_hasta > NOW()
        """)
        fila = cursor.fetchone()
        return {"asientos": fila["asientos"], "clientes": fila["clientes"]}

    def _ventas_semana(self, cursor):
        """Ventas (con IVA) de cada uno de los últimos 7 días, hoy incluido."""
        hoy = self._hoy_sql()
        cursor.execute(f"""
            SELECT d.dia::date AS dia, COALESCE(SUM(r.total), 0) AS total
            FROM generate_series({hoy} - 6, {hoy}, INTERVAL '1 day') AS d(dia)
            LEFT JOIN reservas r
                   ON {self._dia_reserva_sql()} = d.dia::date
                  AND r.estado = 'ACTIVA'
            GROUP BY d.dia
            ORDER BY d.dia
        """)
        return [
            {"fecha": str(f["dia"]), "total": self._con_iva(f["total"])}
            for f in cursor.fetchall()
        ]

    def _proximas_salidas(self, cursor, limite=5):
        cursor.execute(f"""
            SELECT
                v.id, v.aerolinea, v.origen, v.destino, v.fecha, v.hora_salida,
                COUNT(av.id) FILTER (WHERE av.estado = 'RESERVADO') AS vendidos,
                COUNT(av.id) AS total
            FROM vuelos v
            LEFT JOIN asientos_vuelo av ON av.vuelo_id = v.id
            WHERE v.estado = TRUE
              AND (v.fecha + v.hora_salida) >= (NOW() AT TIME ZONE '{self.ZONA}')
            GROUP BY v.id
            ORDER BY v.fecha, v.hora_salida
            LIMIT %s
        """, (limite,))
        return [
            {
                "id": f["id"],
                "aerolinea": f["aerolinea"],
                "origen": f["origen"],
                "destino": f["destino"],
                "fecha": str(f["fecha"]),
                "hora_salida": str(f["hora_salida"]),
                "vendidos": f["vendidos"],
                "total": f["total"],
            }
            for f in cursor.fetchall()
        ]

    def _ultimas_reservas(self, cursor, limite=5):
        cursor.execute("""
            SELECT
                r.id, r.codigo_reserva, r.estado, r.total, r.fecha_reserva,
                u.nombre_completo, v.origen, v.destino,
                COALESCE(
                    STRING_AGG(av.numero_asiento, ', ' ORDER BY av.numero_asiento),
                    ''
                ) AS asientos
            FROM reservas r
            INNER JOIN usuarios u ON u.id = r.usuario_id
            INNER JOIN vuelos v ON v.id = r.vuelo_id
            LEFT JOIN asientos_vuelo av ON av.reserva_id = r.id
            GROUP BY r.id, u.nombre_completo, v.origen, v.destino
            ORDER BY r.fecha_reserva DESC
            LIMIT %s
        """, (limite,))
        return [
            {
                "id": f["id"],
                "codigo": f["codigo_reserva"],
                "estado": f["estado"],
                "total": self._con_iva(f["total"]),
                # ISO en UTC con "Z" para que Flutter la convierta a la hora local
                "fecha": f["fecha_reserva"].isoformat() + "Z",
                "cliente": f["nombre_completo"],
                "origen": f["origen"],
                "destino": f["destino"],
                "asientos": f["asientos"],
            }
            for f in cursor.fetchall()
        ]
