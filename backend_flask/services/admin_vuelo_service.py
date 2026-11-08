import psycopg2.extras
from database import Database


class AdminVueloService:

    def crear_vuelo_con_asientos(self, datos):
        from datetime import datetime, date
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            # 1. Validate seats
            cantidad_asientos = int(datos["cantidad_asientos"])
            if cantidad_asientos <= 0:
                raise Exception("La cantidad de asientos debe ser mayor a cero")

            # 2. Validate price
            precio = float(datos["precio"])
            if precio <= 0:
                raise Exception("El precio del vuelo debe ser mayor a cero y no puede ser negativo")

            # 3. Validate dates
            try:
                fecha_dep = datetime.strptime(datos["fecha"], "%Y-%m-%d").date()
            except ValueError:
                raise Exception("Formato de fecha de salida inválido (debe ser YYYY-MM-DD)")

            try:
                fecha_arr = datetime.strptime(datos["fecha_llegada"], "%Y-%m-%d").date()
            except ValueError:
                raise Exception("Formato de fecha de llegada inválido (debe ser YYYY-MM-DD)")

            hoy = date.today()
            if fecha_dep < hoy:
                raise Exception("No se puede crear un vuelo con fecha de salida anterior a hoy")

            if fecha_arr < fecha_dep:
                raise Exception("La fecha de llegada no puede ser anterior a la fecha de salida")

            # 4. Validate times if same day
            if fecha_arr == fecha_dep:
                try:
                    time_format = "%H:%M" if len(datos["hora_salida"]) == 5 else "%H:%M:%S"
                    t_salida = datetime.strptime(datos["hora_salida"], time_format).time()
                except ValueError:
                    raise Exception("Formato de hora de salida inválido (debe ser HH:MM)")

                try:
                    time_arr_format = "%H:%M" if len(datos["hora_llegada"]) == 5 else "%H:%M:%S"
                    t_llegada = datetime.strptime(datos["hora_llegada"], time_arr_format).time()
                except ValueError:
                    raise Exception("Formato de hora de llegada inválido (debe ser HH:MM)")

                if t_llegada <= t_salida:
                    raise Exception("La hora de llegada debe ser posterior a la hora de salida para vuelos en el mismo día")

            cursor.execute("""
                INSERT INTO vuelos (
                    aerolinea,
                    origen,
                    destino,
                    fecha,
                    fecha_llegada,
                    hora_salida,
                    hora_llegada,
                    precio,
                    asientos_disponibles,
                    estado
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE)
                RETURNING id, aerolinea, origen, destino, fecha, fecha_llegada, hora_salida, hora_llegada, precio, asientos_disponibles
            """, (
                datos["aerolinea"],
                datos["origen"],
                datos["destino"],
                datos["fecha"],
                datos["fecha_llegada"],
                datos["hora_salida"],
                datos["hora_llegada"],
                precio,
                cantidad_asientos
            ))

            vuelo = cursor.fetchone()
            vuelo_id = vuelo["id"]

            asientos = self.generar_asientos(cantidad_asientos)

            for numero_asiento in asientos:
                cursor.execute("""
                    INSERT INTO asientos_vuelo (
                        vuelo_id,
                        numero_asiento,
                        estado
                    )
                    VALUES (%s, %s, 'DISPONIBLE')
                """, (
                    vuelo_id,
                    numero_asiento
                ))

            conexion.commit()

            return {
                "id": vuelo["id"],
                "aerolinea": vuelo["aerolinea"],
                "origen": vuelo["origen"],
                "destino": vuelo["destino"],
                "fecha": str(vuelo["fecha"]),
                "fecha_llegada": str(vuelo["fecha_llegada"]),
                "hora_salida": str(vuelo["hora_salida"]),
                "hora_llegada": str(vuelo["hora_llegada"]),
                "precio": float(vuelo["precio"]),
                "asientos_disponibles": vuelo["asientos_disponibles"],
                "asientos_generados": asientos
            }

        except Exception as e:
            conexion.rollback()
            raise e

        finally:
            cursor.close()
            conexion.close()

    def generar_asientos(self, cantidad):
        letras = ["A", "B", "C", "D"]
        asientos = []

        fila = 1

        while len(asientos) < cantidad:
            for letra in letras:
                if len(asientos) < cantidad:
                    asientos.append(f"{fila}{letra}")
            fila += 1

        return asientos