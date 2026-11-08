import psycopg2.extras
from database import Database
from models.reserva_model import ReservaModel


class ReservaService:

    def crear_reserva(self, usuario_id, vuelo_id, cantidad_asientos):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            cursor.execute("""
                SELECT reserva_id, codigo_reserva, total, estado
                FROM crear_reserva_segura(%s, %s, %s)
            """, (
                usuario_id,
                vuelo_id,
                cantidad_asientos
            ))

            fila = cursor.fetchone()
            conexion.commit()

            return {
                "id": fila["reserva_id"],
                "codigo_reserva": fila["codigo_reserva"],
                "total": float(fila["total"]),
                "estado": fila["estado"]
            }

        except Exception as e:
            conexion.rollback()
            raise e

        finally:
            cursor.close()
            conexion.close()

    def listar_mis_reservas(self, usuario_id):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            cursor.execute("""
                SELECT 
                    r.id,
                    r.vuelo_id,
                    r.codigo_reserva,
                    r.cantidad_asientos,
                    r.total,
                    r.estado,
                    r.fecha_reserva,
                    v.aerolinea,
                    v.origen,
                    v.destino,
                    v.fecha,
                    v.fecha_llegada,
                    v.hora_salida,
                    v.hora_llegada,
                    COALESCE(
                        ARRAY_AGG(av.numero_asiento ORDER BY av.numero_asiento)
                        FILTER (WHERE av.numero_asiento IS NOT NULL),
                        ARRAY[]::VARCHAR[]
                     ) AS asientos
                FROM reservas r
                INNER JOIN vuelos v ON v.id = r.vuelo_id
                LEFT JOIN asientos_vuelo av ON av.reserva_id = r.id
                WHERE r.usuario_id = %s
                GROUP BY 
                    r.id,
                    r.vuelo_id,
                    r.codigo_reserva,
                    r.cantidad_asientos,
                    r.total,
                    r.estado,
                    r.fecha_reserva,
                    v.aerolinea,
                    v.origen,
                    v.destino,
                    v.fecha,
                    v.fecha_llegada,
                    v.hora_salida,
                    v.hora_llegada
                ORDER BY r.fecha_reserva DESC
            """, (usuario_id,))

            reservas = []

            for fila in cursor.fetchall():
                reservas.append({
                    "id": fila["id"],
                    "vuelo_id": fila["vuelo_id"],
                    "codigo_reserva": fila["codigo_reserva"],
                    "cantidad_asientos": fila["cantidad_asientos"],
                    "total": float(fila["total"]),
                    "estado": fila["estado"],
                    "fecha_reserva": str(fila["fecha_reserva"]),
                    "aerolinea": fila["aerolinea"],
                    "origen": fila["origen"],
                    "destino": fila["destino"],
                    "fecha_vuelo": str(fila["fecha"]),
                    "fecha_llegada": str(fila["fecha_llegada"]),
                    "hora_salida": str(fila["hora_salida"]),
                    "hora_llegada": str(fila["hora_llegada"]),
                    "asientos": list(fila["asientos"])
                })

            return reservas

        finally:
            cursor.close()
            conexion.close()

    def cancelar_reserva(self, usuario_id, reserva_id):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            cursor.execute("""
                SELECT vuelo_id, cantidad_asientos, estado
                FROM reservas
                WHERE id = %s
                  AND usuario_id = %s
                FOR UPDATE
            """, (
                reserva_id,
                usuario_id
            ))

            reserva = cursor.fetchone()

            if reserva is None:
                conexion.rollback()
                return None

            if reserva["estado"] != "ACTIVA":
                conexion.rollback()
                return "NO_ACTIVA"

            cursor.execute("""
                UPDATE reservas
                SET estado = 'CANCELADA'
                WHERE id = %s
            """, (reserva_id,))

            cursor.execute("""
                UPDATE asientos_vuelo
                SET estado = 'DISPONIBLE',
                    reserva_id = NULL
                WHERE reserva_id = %s
            """, (reserva_id,))

            cursor.execute("""
                UPDATE vuelos
                SET asientos_disponibles = asientos_disponibles + %s,
                    version = version + 1
                WHERE id = %s
            """, (
                reserva["cantidad_asientos"],
                reserva["vuelo_id"]
            ))
            conexion.commit()
            return "CANCELADA"

        except Exception as e:
            conexion.rollback()
            raise e

        finally:
            cursor.close()
            conexion.close()

    def editar_reserva(self, usuario_id, reserva_id, datos):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            # 1. Lock the reservation and check ownership + state
            cursor.execute("""
                SELECT r.id, r.usuario_id, r.vuelo_id, r.cantidad_asientos, r.total, r.estado,
                       v.fecha, v.precio, v.asientos_disponibles
                FROM reservas r
                INNER JOIN vuelos v ON v.id = r.vuelo_id
                WHERE r.id = %s AND r.usuario_id = %s
                FOR UPDATE
            """, (reserva_id, usuario_id))

            reserva = cursor.fetchone()

            if reserva is None:
                raise Exception("Reserva no encontrada")

            if reserva["estado"] != "ACTIVA":
                raise Exception("Solo se pueden editar reservas activas")

            # 2. Check if the flight date has already passed
            from datetime import date
            fecha_vuelo = reserva["fecha"]
            if isinstance(fecha_vuelo, str):
                from datetime import datetime
                fecha_vuelo = datetime.strptime(fecha_vuelo, "%Y-%m-%d").date()
            
            if fecha_vuelo < date.today():
                raise Exception("No se puede editar una reserva cuya fecha de vuelo ya pasó")

            # 3. Read input parameters
            nuevo_vuelo_id = datos.get("vuelo_id")
            if nuevo_vuelo_id is not None:
                nuevo_vuelo_id = int(nuevo_vuelo_id)
            else:
                nuevo_vuelo_id = reserva["vuelo_id"]

            nuevos_asientos = datos.get("asientos")
            if nuevos_asientos is None:
                cursor.execute("""
                    SELECT numero_asiento FROM asientos_vuelo WHERE reserva_id = %s
                """, (reserva_id,))
                nuevos_asientos = [row["numero_asiento"] for row in cursor.fetchall()]

            nueva_cantidad = len(nuevos_asientos)
            if nueva_cantidad <= 0:
                raise Exception("Debe seleccionar al menos un asiento")

            cursor.execute("""
                SELECT id, precio, asientos_disponibles, fecha, estado
                FROM vuelos
                WHERE id = %s
                FOR UPDATE
            """, (nuevo_vuelo_id,))
            nuevo_vuelo = cursor.fetchone()

            if nuevo_vuelo is None or not nuevo_vuelo["estado"]:
                raise Exception("El vuelo seleccionado no está disponible o no existe")

            fecha_nuevo_vuelo = nuevo_vuelo["fecha"]
            if isinstance(fecha_nuevo_vuelo, str):
                from datetime import datetime
                fecha_nuevo_vuelo = datetime.strptime(fecha_nuevo_vuelo, "%Y-%m-%d").date()
            if fecha_nuevo_vuelo < date.today():
                raise Exception("El nuevo vuelo seleccionado ya pasó")

            # 4. Check seats availability and free old ones
            cursor.execute("""
                UPDATE asientos_vuelo
                SET estado = 'DISPONIBLE',
                    reserva_id = NULL
                WHERE reserva_id = %s
            """, (reserva_id,))

            cursor.execute("""
                UPDATE vuelos
                SET asientos_disponibles = asientos_disponibles + %s
                WHERE id = %s
            """, (reserva["cantidad_asientos"], reserva["vuelo_id"]))

            cursor.execute("""
                SELECT id, precio, asientos_disponibles
                FROM vuelos
                WHERE id = %s
                FOR UPDATE
            """, (nuevo_vuelo_id,))
            nuevo_vuelo = cursor.fetchone()

            if nuevo_vuelo["asientos_disponibles"] < nueva_cantidad:
                raise Exception("No existen asientos suficientes disponibles en el vuelo seleccionado")

            cursor.execute("""
                SELECT COUNT(*) as cnt
                FROM asientos_vuelo
                WHERE vuelo_id = %s
                  AND numero_asiento = ANY(%s)
                  AND estado = 'DISPONIBLE'
            """, (nuevo_vuelo_id, nuevos_asientos))
            cnt = cursor.fetchone()["cnt"]

            if cnt != nueva_cantidad:
                raise Exception("Uno o más de los asientos seleccionados no están disponibles")

            # 5. Reserve new seats
            cursor.execute("""
                UPDATE asientos_vuelo
                SET estado = 'RESERVADO',
                    reserva_id = %s
                WHERE vuelo_id = %s
                  AND numero_asiento = ANY(%s)
            """, (reserva_id, nuevo_vuelo_id, nuevos_asientos))

            cursor.execute("""
                UPDATE vuelos
                SET asientos_disponibles = asientos_disponibles - %s,
                    version = version + 1
                WHERE id = %s
            """, (nueva_cantidad, nuevo_vuelo_id))

            nuevo_total = float(nuevo_vuelo["precio"]) * nueva_cantidad

            # 6. Update the reservation details
            cursor.execute("""
                UPDATE reservas
                SET vuelo_id = %s,
                    cantidad_asientos = %s,
                    total = %s
                WHERE id = %s
            """, (nuevo_vuelo_id, nueva_cantidad, nuevo_total, reserva_id))

            conexion.commit()

            return {
                "id": reserva_id,
                "vuelo_id": nuevo_vuelo_id,
                "cantidad_asientos": nueva_cantidad,
                "total": nuevo_total,
                "asientos": nuevos_asientos,
                "mensaje": "Reserva modificada correctamente"
            }

        except Exception as e:
            conexion.rollback()
            raise e

        finally:
            cursor.close()
            conexion.close()
