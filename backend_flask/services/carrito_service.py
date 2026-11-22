from datetime import date
from decimal import Decimal, ROUND_HALF_UP

import psycopg2.extras
from database import Database
from services.reserva_service import ReservaService


class ErrorCarrito(Exception):
    """Error con mensaje para el usuario y código HTTP."""

    def __init__(self, mensaje, codigo=400, asientos=None):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.codigo = codigo
        self.asientos = asientos or []


class CarritoService:
    """
    El carrito son los asientos que el usuario tiene apartados.

    Un asiento está apartado cuando bloqueado_por = usuario y
    bloqueado_hasta > NOW(). Al pasar los 10 minutos queda libre solo.
    """

    MINUTOS_BLOQUEO = 10
    MAX_ASIENTOS_POR_VUELO = 6
    IVA = Decimal("0.15")

    # ───────────────────────── Consultar ─────────────────────────

    def obtener(self, usuario_id):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            return self._leer_carrito(cursor, usuario_id)
        finally:
            cursor.close()
            conexion.close()

    def _leer_carrito(self, cursor, usuario_id):
        cursor.execute("""
            SELECT
                v.id, v.aerolinea, v.origen, v.destino, v.fecha, v.fecha_llegada,
                v.hora_salida, v.hora_llegada, v.precio, v.asientos_disponibles,
                ARRAY_AGG(av.numero_asiento ORDER BY
                    CAST(regexp_replace(av.numero_asiento, '[^0-9]', '', 'g') AS INT),
                    av.numero_asiento) AS asientos,
                GREATEST(0, EXTRACT(EPOCH FROM MIN(av.bloqueado_hasta) - NOW()))::INT
                    AS segundos_restantes
            FROM asientos_vuelo av
            INNER JOIN vuelos v ON v.id = av.vuelo_id
            WHERE av.bloqueado_por = %s
              AND av.bloqueado_hasta > NOW()
              AND av.estado = 'DISPONIBLE'
            GROUP BY v.id
            ORDER BY MIN(av.bloqueado_hasta)
        """, (usuario_id,))

        items = []
        subtotal = Decimal("0")

        for fila in cursor.fetchall():
            asientos = list(fila["asientos"])
            precio = Decimal(fila["precio"])
            subtotal_item = precio * len(asientos)
            subtotal += subtotal_item

            items.append({
                "vuelo": {
                    "id": fila["id"],
                    "aerolinea": fila["aerolinea"],
                    "origen": fila["origen"],
                    "destino": fila["destino"],
                    "fecha": str(fila["fecha"]),
                    "fecha_llegada": str(fila["fecha_llegada"] or fila["fecha"]),
                    "hora_salida": str(fila["hora_salida"]),
                    "hora_llegada": str(fila["hora_llegada"]),
                    "precio": float(precio),
                    "asientos_disponibles": fila["asientos_disponibles"],
                },
                "asientos": asientos,
                "subtotal": float(subtotal_item),
                "segundos_restantes": fila["segundos_restantes"],
            })

        return {
            "items": items,
            "minutos_bloqueo": self.MINUTOS_BLOQUEO,
            **self._totales(subtotal),
        }

    def _totales(self, subtotal):
        subtotal = subtotal.quantize(Decimal("0.01"), ROUND_HALF_UP)
        iva = (subtotal * self.IVA).quantize(Decimal("0.01"), ROUND_HALF_UP)
        return {
            "subtotal": float(subtotal),
            "porcentaje_iva": int(self.IVA * 100),
            "iva": float(iva),
            "total": float(subtotal + iva),
        }

    # ───────────────────────── Agregar ─────────────────────────

    def agregar(self, usuario_id, vuelo_id, asientos):
        asientos = self._validar_asientos(asientos)

        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            # 1. Bloquear la fila del vuelo: dos personas que aparten asientos
            #    del mismo vuelo a la vez se atienden una después de la otra.
            cursor.execute("""
                SELECT id, fecha, estado
                FROM vuelos
                WHERE id = %s
                FOR UPDATE
            """, (vuelo_id,))
            vuelo = cursor.fetchone()

            if vuelo is None or not vuelo["estado"]:
                raise ErrorCarrito("El vuelo no existe o no está disponible", 404)

            if vuelo["fecha"] < date.today():
                raise ErrorCarrito("Este vuelo ya salió")

            # 2. Bloquear los asientos pedidos y ver si alguien más los tiene.
            cursor.execute("""
                SELECT
                    numero_asiento,
                    (estado <> 'DISPONIBLE'
                     OR (bloqueado_hasta > NOW() AND bloqueado_por <> %s)) AS tomado
                FROM asientos_vuelo
                WHERE vuelo_id = %s
                  AND numero_asiento = ANY(%s)
                FOR UPDATE
            """, (usuario_id, vuelo_id, asientos))
            filas = cursor.fetchall()

            if len(filas) != len(asientos):
                raise ErrorCarrito("Uno o más asientos no existen en este vuelo")

            tomados = sorted(f["numero_asiento"] for f in filas if f["tomado"])
            if tomados:
                texto = ", ".join(tomados)
                raise ErrorCarrito(
                    f"El asiento {texto} acaba de ser tomado por otra persona. Elige otro."
                    if len(tomados) == 1 else
                    f"Los asientos {texto} acaban de ser tomados por otra persona. Elige otros.",
                    409,
                    tomados,
                )

            # 3. Si ya tenía asientos de este vuelo en el carrito, se conserva
            #    la hora de vencimiento (cambiar asientos no reinicia el reloj).
            cursor.execute("""
                SELECT MIN(bloqueado_hasta) AS hasta
                FROM asientos_vuelo
                WHERE vuelo_id = %s
                  AND bloqueado_por = %s
                  AND bloqueado_hasta > NOW()
            """, (vuelo_id, usuario_id))
            hasta_actual = cursor.fetchone()["hasta"]

            # 4. Soltar los asientos de este vuelo que ya no eligió.
            cursor.execute("""
                UPDATE asientos_vuelo
                SET bloqueado_por = NULL,
                    bloqueado_hasta = NULL
                WHERE vuelo_id = %s
                  AND bloqueado_por = %s
                  AND NOT (numero_asiento = ANY(%s))
            """, (vuelo_id, usuario_id, asientos))

            # 5. Apartar los asientos elegidos.
            cursor.execute("""
                UPDATE asientos_vuelo
                SET bloqueado_por = %s,
                    bloqueado_hasta = COALESCE(
                        %s::timestamptz,
                        NOW() + make_interval(mins => %s)
                    )
                WHERE vuelo_id = %s
                  AND numero_asiento = ANY(%s)
            """, (usuario_id, hasta_actual, self.MINUTOS_BLOQUEO, vuelo_id, asientos))

            conexion.commit()
            return self._leer_carrito(cursor, usuario_id)

        except Exception:
            conexion.rollback()
            raise

        finally:
            cursor.close()
            conexion.close()

    def _validar_asientos(self, asientos):
        if not isinstance(asientos, list) or not asientos:
            raise ErrorCarrito("Debe seleccionar al menos un asiento")

        limpios = []
        for a in asientos:
            if not isinstance(a, str) or not a.strip():
                raise ErrorCarrito("Asiento no válido")
            numero = a.strip().upper()
            if numero not in limpios:
                limpios.append(numero)

        if len(limpios) > self.MAX_ASIENTOS_POR_VUELO:
            raise ErrorCarrito(
                f"Puedes apartar hasta {self.MAX_ASIENTOS_POR_VUELO} asientos por vuelo"
            )
        return limpios

    # ───────────────────────── Quitar ─────────────────────────

    def quitar(self, usuario_id, vuelo_id):
        return self._liberar(usuario_id, vuelo_id)

    def vaciar(self, usuario_id):
        return self._liberar(usuario_id, None)

    def _liberar(self, usuario_id, vuelo_id):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            cursor.execute("""
                UPDATE asientos_vuelo
                SET bloqueado_por = NULL,
                    bloqueado_hasta = NULL
                WHERE bloqueado_por = %s
                  AND (%s::BIGINT IS NULL OR vuelo_id = %s)
            """, (usuario_id, vuelo_id, vuelo_id))
            conexion.commit()
            return self._leer_carrito(cursor, usuario_id)
        except Exception:
            conexion.rollback()
            raise
        finally:
            cursor.close()
            conexion.close()

    # ───────────────────────── Confirmar y pagar ─────────────────────────

    def confirmar(self, usuario_id, vuelos_esperados=None):
        """
        Crea una reserva por cada vuelo del carrito. Cada vuelo se confirma
        por separado: si uno falla (por ejemplo, otro usuario tomó el asiento
        cuando venció el bloqueo), los demás se confirman igual.
        """
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        creadas = []
        fallidas = []

        try:
            carrito = self._leer_carrito(cursor, usuario_id)
            conexion.commit()

            en_carrito = {item["vuelo"]["id"] for item in carrito["items"]}

            # Vuelos que el usuario veía en su carrito pero cuyo tiempo ya venció.
            for vuelo_id in vuelos_esperados or []:
                if vuelo_id not in en_carrito:
                    fallidas.append({
                        "vuelo_id": vuelo_id,
                        "motivo": "Se acabó el tiempo de 10 minutos y los asientos se liberaron.",
                    })

            if not carrito["items"] and not fallidas:
                raise ErrorCarrito("Tu carrito está vacío")

            for item in carrito["items"]:
                vuelo = item["vuelo"]
                try:
                    cursor.execute("""
                        SELECT reserva_id
                        FROM crear_reserva_asientos_segura(%s, %s, %s)
                    """, (usuario_id, vuelo["id"], item["asientos"]))
                    creadas.append(cursor.fetchone()["reserva_id"])
                    conexion.commit()
                except Exception as e:
                    conexion.rollback()
                    fallidas.append({
                        "vuelo_id": vuelo["id"],
                        "origen": vuelo["origen"],
                        "destino": vuelo["destino"],
                        "asientos": item["asientos"],
                        "motivo": self._motivo(e),
                    })
        finally:
            cursor.close()
            conexion.close()

        # Datos completos de las reservas creadas (mismo formato que Mis reservas)
        reservas = []
        if creadas:
            todas = ReservaService().listar_mis_reservas(usuario_id)
            reservas = [r for r in todas if r["id"] in creadas]

        subtotal = sum((Decimal(str(r["total"])) for r in reservas), Decimal("0"))

        return {
            "confirmadas": reservas,
            "fallidas": fallidas,
            **self._totales(subtotal),
        }

    @staticmethod
    def _motivo(error):
        texto = str(error)
        if "ya no están disponibles" in texto:
            return "Asiento ya ocupado, elige otro."
        if "suficientes" in texto:
            return "Ya no quedan asientos suficientes en este vuelo."
        if "inactivo" in texto:
            return "El vuelo ya no está disponible."
        return "No se pudo confirmar este vuelo."
