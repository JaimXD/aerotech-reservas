import psycopg2.extras
from database import Database
from models.vuelo_model import VueloModel


class VueloService:

    def buscar_vuelos(self, origen=None, destino=None, fecha=None, fecha_inicio=None, fecha_fin=None):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            sql = """
                SELECT id, aerolinea, origen, destino, fecha,
                       hora_salida, hora_llegada, precio,
                       asientos_disponibles, fecha_llegada
                FROM vuelos
                WHERE estado = TRUE
                  AND asientos_disponibles > 0
                  AND (%s IS NULL OR origen ILIKE %s)
                  AND (%s IS NULL OR destino ILIKE %s)
            """
            params = [
                origen, f"%{origen}%" if origen else None,
                destino, f"%{destino}%" if destino else None
            ]

            if fecha_inicio and fecha_fin:
                sql += " AND (fecha >= %s AND fecha <= %s)"
                params.extend([fecha_inicio, fecha_fin])
            elif fecha:
                sql += " AND (fecha = %s)"
                params.append(fecha)

            sql += " ORDER BY fecha, hora_salida"

            cursor.execute(sql, tuple(params))

            vuelos = []

            for fila in cursor.fetchall():
                vuelos.append(VueloModel.from_row(fila).to_dict())

            return vuelos

        finally:
            cursor.close()
            conexion.close()
