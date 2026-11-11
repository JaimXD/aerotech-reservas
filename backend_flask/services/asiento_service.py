import psycopg2.extras
from database import Database
from models.asiento_model import AsientoModel


class AsientoService:

    def listar_asientos_por_vuelo(self, vuelo_id, usuario_id=None):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            # Un asiento apartado por OTRA persona se envía como BLOQUEADO.
            # Los que están en mi carrito llegan como DISPONIBLE + en_mi_carrito.
            cursor.execute("""
                SELECT
                    id,
                    vuelo_id,
                    numero_asiento,
                    CASE
                        WHEN estado = 'DISPONIBLE'
                         AND bloqueado_hasta > NOW()
                         AND bloqueado_por IS DISTINCT FROM %s
                        THEN 'BLOQUEADO'
                        ELSE estado
                    END AS estado,
                    reserva_id,
                    COALESCE(
                        estado = 'DISPONIBLE'
                        AND bloqueado_hasta > NOW()
                        AND bloqueado_por = %s,
                        FALSE
                    ) AS en_mi_carrito
                FROM asientos_vuelo
                WHERE vuelo_id = %s
                ORDER BY 
                    CAST(regexp_replace(numero_asiento, '[^0-9]', '', 'g') AS INT),
                    regexp_replace(numero_asiento, '[0-9]', '', 'g')
            """, (usuario_id, usuario_id, vuelo_id))

            asientos = []

            for fila in cursor.fetchall():
                asiento = AsientoModel.from_row(fila)
                asientos.append(asiento.to_dict())

            return asientos

        finally:
            cursor.close()
            conexion.close()

    def crear_reserva_con_asientos(self, usuario_id, vuelo_id, asientos):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            cursor.execute("""
                SELECT 
                    reserva_id,
                    codigo_reserva,
                    total,
                    estado
                FROM crear_reserva_asientos_segura(%s, %s, %s)
            """, (
                usuario_id,
                vuelo_id,
                asientos
            ))

            fila = cursor.fetchone()

            conexion.commit()

            return {
                "id": fila["reserva_id"],
                "codigo_reserva": fila["codigo_reserva"],
                "total": float(fila["total"]),
                "estado": fila["estado"],
                "asientos": asientos
            }

        except Exception as e:
            conexion.rollback()
            raise e

        finally:
            cursor.close()
            conexion.close()