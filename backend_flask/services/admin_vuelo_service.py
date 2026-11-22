import hashlib
import re
import unicodedata
from datetime import datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP

import psycopg2.extras
from database import Database


class ErrorVuelo(Exception):
    """Error de negocio con el código HTTP que debe devolver la API."""

    def __init__(self, mensaje, codigo=400):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.codigo = codigo


class AdminVueloService:
    """Gestión de vuelos del administrador: listar, ver, crear, editar,
    cancelar y reactivar."""

    # Las fechas y horas de los vuelos son hora de Ecuador; NOW() en Supabase es UTC.
    ZONA = "America/Guayaquil"
    IVA = Decimal("1.15")
    LETRAS = "ABCDEF"
    # Cabinas como las de aviones reales: asientos por fila → (mín., máx. de filas)
    #   2: Beechcraft 1900 · 3: Jetstream 32 · 4: ATR 72, Embraer 190
    #   5: Airbus A220 · 6: Airbus A320, Boeing 737
    CABINAS = {2: (4, 10), 3: (4, 10), 4: (10, 25), 5: (20, 30), 6: (20, 40)}
    PRECIO_MAXIMO = 10000
    DURACION_MAXIMA = timedelta(hours=24)
    # El vuelo comercial más corto del país (p. ej. Quito–Coca) dura ~30 min
    DURACION_MINIMA = timedelta(minutes=30)
    # Las horas van de 5 en 5 minutos, como en los horarios reales
    PASO_MINUTOS = 5
    POR_PAGINA = 10
    ESTADOS = ("PROGRAMADO", "COMPLETO", "SALIO", "CANCELADO")

    # Lo mismo que deja escribir el buscador de la app: letras (con tildes, ñ y ü),
    # números, espacios y los signos # . -  Todo lo demás se descarta.
    _NO_PERMITIDO_BUSQUEDA = re.compile(r"[^0-9A-Za-zÁÉÍÓÚÜÑáéíóúüñ #.\-]")
    LARGO_BUSQUEDA = 50

    # Nombres: igual que los campos de la app. Empiezan con letra (o número
    # en la aerolínea) y solo llevan letras, espacios y . - ' (y & en la aerolínea).
    _LETRAS = "A-Za-zÁÉÍÓÚÜÑáéíóúüñ"
    _CIUDAD = re.compile(rf"^[{_LETRAS}][{_LETRAS} .'\-]*$")
    _AEROLINEA = re.compile(rf"^[{_LETRAS}0-9][{_LETRAS}0-9 .&'\-]*$")
    _UNA_LETRA = re.compile(rf"[{_LETRAS}]")
    LARGO_NOMBRE = 40

    # ───────────────────────── Consultas base ─────────────────────────

    def _sql_vuelos(self):
        """Vuelos con sus conteos de asientos y reservas, y su estado calculado."""
        ahora = f"(NOW() AT TIME ZONE '{self.ZONA}')"
        return rf"""
            WITH a AS (
                SELECT vuelo_id,
                       COUNT(*) AS total,
                       COUNT(*) FILTER (WHERE estado = 'RESERVADO') AS vendidos,
                       COUNT(*) FILTER (WHERE estado = 'DISPONIBLE'
                                          AND bloqueado_hasta > NOW()) AS en_carritos,
                       MAX(NULLIF(regexp_replace(numero_asiento, '\D', '', 'g'), '')::int) AS filas,
                       COUNT(DISTINCT regexp_replace(numero_asiento, '\d', '', 'g')) AS por_fila
                FROM asientos_vuelo
                GROUP BY vuelo_id
            ), r AS (
                SELECT vuelo_id,
                       COUNT(*) FILTER (WHERE estado = 'ACTIVA') AS activas,
                       COUNT(*) FILTER (WHERE estado = 'CANCELADA') AS canceladas,
                       COALESCE(SUM(total) FILTER (WHERE estado = 'ACTIVA'), 0) AS ingresos
                FROM reservas
                GROUP BY vuelo_id
            )
            SELECT v.id, v.aerolinea, v.origen, v.destino, v.fecha, v.fecha_llegada,
                   v.hora_salida, v.hora_llegada, v.precio, v.asientos_disponibles,
                   COALESCE(a.total, 0) AS total,
                   COALESCE(a.vendidos, 0) AS vendidos,
                   COALESCE(a.en_carritos, 0) AS en_carritos,
                   COALESCE(a.filas, 0) AS filas,
                   COALESCE(a.por_fila, 0) AS por_fila,
                   COALESCE(r.activas, 0) AS reservas_activas,
                   COALESCE(r.canceladas, 0) AS reservas_canceladas,
                   COALESCE(r.ingresos, 0) AS ingresos,
                   (v.fecha + v.hora_salida) < {ahora} AS ya_salio,
                   CASE
                       WHEN v.estado = FALSE THEN 'CANCELADO'
                       WHEN (v.fecha + v.hora_salida) <= {ahora} THEN 'SALIO'
                       WHEN COALESCE(a.total, 0) > 0
                            AND COALESCE(a.vendidos, 0) >= a.total THEN 'COMPLETO'
                       ELSE 'PROGRAMADO'
                   END AS estado
            FROM vuelos v
            LEFT JOIN a ON a.vuelo_id = v.id
            LEFT JOIN r ON r.vuelo_id = v.id
        """

    def _con_iva(self, valor):
        return float((Decimal(valor or 0) * self.IVA).quantize(Decimal("0.01"), ROUND_HALF_UP))

    # Datos que cambia el administrador. Las compras de los clientes no los
    # tocan, así que no cuentan como un conflicto al editar.
    _CAMPOS_EDITABLES = ("aerolinea", "origen", "destino", "fecha", "fecha_llegada",
                         "hora_salida", "hora_llegada", "precio", "filas", "por_fila")

    def _huella(self, f):
        """Resumen de los datos editables del vuelo. Si cambia entre que el
        administrador abre el formulario y guarda, otro lo modificó."""
        datos = [str(f[c]) for c in self._CAMPOS_EDITABLES]
        datos.append(str(f["estado"] == "CANCELADO"))
        return hashlib.sha256("|".join(datos).encode("utf-8")).hexdigest()[:16]

    def _a_dict(self, f):
        return {
            "id": f["id"],
            "huella": self._huella(f),
            "aerolinea": f["aerolinea"],
            "origen": f["origen"],
            "destino": f["destino"],
            "fecha": str(f["fecha"]),
            "fecha_llegada": str(f["fecha_llegada"]),
            "hora_salida": str(f["hora_salida"]),
            "hora_llegada": str(f["hora_llegada"]),
            "precio": float(f["precio"]),
            "asientos_disponibles": f["asientos_disponibles"],
            "estado": f["estado"],
            "total_asientos": f["total"],
            "vendidos": f["vendidos"],
            "en_carritos": f["en_carritos"],
            "filas": f["filas"],
            "asientos_por_fila": f["por_fila"],
            "reservas_activas": f["reservas_activas"],
            "reservas_canceladas": f["reservas_canceladas"],
            "ingresos": self._con_iva(f["ingresos"]),
        }

    def _obtener(self, cursor, vuelo_id):
        cursor.execute(f"SELECT * FROM ({self._sql_vuelos()}) x WHERE x.id = %s", (vuelo_id,))
        fila = cursor.fetchone()
        if fila is None:
            raise ErrorVuelo("Vuelo no encontrado", 404)
        return fila

    # ───────────────────────── Listar ─────────────────────────

    def _limpiar_busqueda(self, q):
        """Quita caracteres no permitidos y espacios de más; None si no queda nada que buscar."""
        q = self._NO_PERMITIDO_BUSQUEDA.sub("", q or "")
        q = " ".join(q.split())[: self.LARGO_BUSQUEDA].strip()
        # Solo signos ("#", "-") todavía no es una búsqueda
        return q if any(c.isalnum() for c in q) else None

    def listar(self, estado=None, q=None, aerolinea=None, pagina=1):
        estado = (estado or "").upper() or None
        if estado and estado not in self.ESTADOS:
            raise ErrorVuelo("Estado de vuelo no válido")
        q = self._limpiar_busqueda(q)
        # "#41" o "41" buscan el vuelo número 41
        numero = q.lstrip("#").strip() if q else ""
        aerolinea = (aerolinea or "").strip() or None
        pagina = max(1, pagina or 1)

        params = {
            "q": q,
            "patron": f"%{q}%" if q else None,
            "numero": numero if numero.isdigit() else None,
            "aerolinea": aerolinea,
            "estado": estado,
            "limite": self.POR_PAGINA,
            "desde": (pagina - 1) * self.POR_PAGINA,
        }
        filtrados = f"""
            SELECT * FROM ({self._sql_vuelos()}) x
            WHERE (%(q)s IS NULL
                   OR x.origen ILIKE %(patron)s
                   OR x.destino ILIKE %(patron)s
                   OR x.aerolinea ILIKE %(patron)s
                   OR x.id::text = %(numero)s)
              AND (%(aerolinea)s IS NULL OR x.aerolinea = %(aerolinea)s)
        """

        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            # Cuántos hay en cada pestaña (con la búsqueda aplicada)
            cursor.execute(f"SELECT estado, COUNT(*) AS n FROM ({filtrados}) f GROUP BY estado", params)
            conteos = {e.lower(): 0 for e in self.ESTADOS}
            for fila in cursor.fetchall():
                conteos[fila["estado"].lower()] = fila["n"]
            conteos["todos"] = sum(conteos.values())

            # Primero los próximos (el más cercano arriba); luego los pasados (el más reciente arriba)
            cursor.execute(f"""
                SELECT * FROM ({filtrados}) f
                WHERE (%(estado)s IS NULL OR f.estado = %(estado)s)
                ORDER BY f.ya_salio,
                         CASE WHEN NOT f.ya_salio THEN f.fecha + f.hora_salida END ASC,
                         f.fecha + f.hora_salida DESC
                LIMIT %(limite)s OFFSET %(desde)s
            """, params)
            vuelos = [self._a_dict(f) for f in cursor.fetchall()]

            aerolineas, ciudades = self._opciones(cursor)

            return {
                "vuelos": vuelos,
                "total": conteos[estado.lower()] if estado else conteos["todos"],
                "pagina": pagina,
                "por_pagina": self.POR_PAGINA,
                "conteos": conteos,
                "aerolineas": aerolineas,
                "ciudades": ciudades,
            }
        finally:
            cursor.close()
            conexion.close()

    # ───────────────────────── Detalle ─────────────────────────

    @staticmethod
    def _opciones(cursor):
        """Aerolíneas y ciudades registradas, en orden alfabético."""
        cursor.execute("SELECT nombre FROM aerolineas ORDER BY nombre")
        aerolineas = [f["nombre"] for f in cursor.fetchall()]
        cursor.execute("SELECT nombre FROM ciudades ORDER BY nombre")
        ciudades = [f["nombre"] for f in cursor.fetchall()]
        return aerolineas, ciudades

    def opciones(self):
        """Para los selectores del formulario de vuelo."""
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            aerolineas, ciudades = self._opciones(cursor)
            return {"aerolineas": aerolineas, "ciudades": ciudades}
        finally:
            cursor.close()
            conexion.close()

    def detalle(self, vuelo_id):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            vuelo = self._a_dict(self._obtener(cursor, vuelo_id))

            cursor.execute(r"""
                SELECT av.numero_asiento, av.estado,
                       (av.estado = 'DISPONIBLE' AND av.bloqueado_hasta > NOW()) AS en_carrito,
                       GREATEST(0, EXTRACT(EPOCH FROM av.bloqueado_hasta - NOW()))::int AS libera_en,
                       r.codigo_reserva, u.nombre_completo
                FROM asientos_vuelo av
                LEFT JOIN reservas r ON r.id = av.reserva_id
                LEFT JOIN usuarios u ON u.id = r.usuario_id
                WHERE av.vuelo_id = %s
                ORDER BY NULLIF(regexp_replace(av.numero_asiento, '\D', '', 'g'), '')::int,
                         av.numero_asiento
            """, (vuelo_id,))
            asientos = []
            for f in cursor.fetchall():
                if f["estado"] == "RESERVADO":
                    estado = "VENDIDO"
                elif f["en_carrito"]:
                    estado = "CARRITO"
                else:
                    estado = "LIBRE"
                asientos.append({
                    "numero": f["numero_asiento"],
                    "estado": estado,
                    "cliente": f["nombre_completo"] if estado == "VENDIDO" else None,
                    "codigo": f["codigo_reserva"] if estado == "VENDIDO" else None,
                    "libera_en": f["libera_en"] if estado == "CARRITO" else None,
                })

            cursor.execute("""
                SELECT r.id, r.codigo_reserva, r.estado, r.total, r.cantidad_asientos,
                       r.fecha_reserva, u.nombre_completo, u.usuario, u.correo,
                       COALESCE(STRING_AGG(av.numero_asiento, ', ' ORDER BY av.numero_asiento), '') AS asientos
                FROM reservas r
                INNER JOIN usuarios u ON u.id = r.usuario_id
                LEFT JOIN asientos_vuelo av ON av.reserva_id = r.id
                WHERE r.vuelo_id = %s
                GROUP BY r.id, u.nombre_completo, u.usuario, u.correo
                ORDER BY (r.estado = 'ACTIVA') DESC, r.fecha_reserva DESC
            """, (vuelo_id,))
            pasajeros = [
                {
                    "reserva_id": f["id"],
                    "codigo": f["codigo_reserva"],
                    "estado": f["estado"],
                    "total": self._con_iva(f["total"]),
                    "cantidad": f["cantidad_asientos"],
                    "asientos": f["asientos"],
                    # UTC con "Z" para que Flutter la pase a la hora local
                    "fecha": f["fecha_reserva"].isoformat() + "Z",
                    "cliente": f["nombre_completo"],
                    "usuario": f["usuario"],
                    "correo": f["correo"],
                }
                for f in cursor.fetchall()
            ]

            carritos = [a["libera_en"] for a in asientos if a["estado"] == "CARRITO"]
            return {
                "vuelo": vuelo,
                "libres": sum(1 for a in asientos if a["estado"] == "LIBRE"),
                "primer_vencimiento": min(carritos) if carritos else None,
                "asientos": asientos,
                "pasajeros": pasajeros,
            }
        finally:
            cursor.close()
            conexion.close()

    # ───────────────────────── Validación ─────────────────────────

    def _texto(self, datos, campo, nombre, aerolinea=False):
        """Valida un nombre (aerolínea o ciudad) y quita los espacios de más."""
        valor = " ".join(str(datos.get(campo) or "").split())
        if not valor:
            raise ErrorVuelo(f"{nombre} es obligatorio")
        if len(valor) > self.LARGO_NOMBRE:
            raise ErrorVuelo(f"{nombre} no puede tener más de {self.LARGO_NOMBRE} caracteres")
        if aerolinea and not self._AEROLINEA.match(valor):
            raise ErrorVuelo(f"{nombre} solo puede tener letras, números, espacios y los signos . - & '")
        if not aerolinea and not self._CIUDAD.match(valor):
            raise ErrorVuelo(f"{nombre} solo puede tener letras, espacios y los signos . - '")
        if len(self._UNA_LETRA.findall(valor)) < 2:
            raise ErrorVuelo(f"{nombre} debe tener al menos 2 letras")
        return valor

    @staticmethod
    def _fecha_hora(fecha, hora, nombre):
        try:
            dia = datetime.strptime(str(fecha), "%Y-%m-%d").date()
        except ValueError:
            raise ErrorVuelo(f"La fecha de {nombre} no es válida (AAAA-MM-DD)")
        hora = str(hora or "")
        try:
            h = datetime.strptime(hora[:5], "%H:%M").time()
        except ValueError:
            raise ErrorVuelo(f"La hora de {nombre} no es válida (HH:MM)")
        return dia, h, datetime.combine(dia, h)

    @staticmethod
    def _clave(texto):
        """Texto para comparar nombres sin tildes ni mayúsculas: "Quíto" → "quito"."""
        sin_tildes = "".join(c for c in unicodedata.normalize("NFD", texto)
                             if unicodedata.category(c) != "Mn")
        return " ".join(sin_tildes.lower().split())

    # Misma expresión que el índice único de las tablas aerolineas y ciudades
    _SIN_TILDES = "translate(lower({}), 'áéíóúüñ', 'aeiouun')"

    def _registrar(self, cursor, tabla, nombre):
        """Devuelve el nombre tal como está en la tabla (aerolineas o ciudades).
        Si es nuevo lo agrega; si ya existe escrito con otras tildes o
        mayúsculas ("amazonia air", "quíto"), devuelve el registrado
        ("Amazonía Air", "Quito")."""
        cursor.execute(f"INSERT INTO {tabla} (nombre) VALUES (%s) ON CONFLICT DO NOTHING",
                       (nombre,))
        cursor.execute(
            f"SELECT nombre FROM {tabla} "
            f"WHERE {self._SIN_TILDES.format('nombre')} = {self._SIN_TILDES.format('%s')}",
            (nombre,))
        return cursor.fetchone()["nombre"]

    def _registrar_nombres(self, cursor, d):
        """Deja la aerolínea, el origen y el destino como están registrados."""
        d["aerolinea"] = self._registrar(cursor, "aerolineas", d["aerolinea"])
        d["origen"] = self._registrar(cursor, "ciudades", d["origen"])
        d["destino"] = self._registrar(cursor, "ciudades", d["destino"])

    def _validar(self, cursor, datos):
        """Valida y normaliza los datos del formulario."""
        aerolinea = self._texto(datos, "aerolinea", "La aerolínea", aerolinea=True)
        origen = self._texto(datos, "origen", "El origen")
        destino = self._texto(datos, "destino", "El destino")
        if self._clave(origen) == self._clave(destino):
            raise ErrorVuelo("El origen y el destino deben ser distintos")

        fecha, hora_salida, salida = self._fecha_hora(datos.get("fecha"), datos.get("hora_salida"), "salida")
        fecha_llegada, hora_llegada, llegada = self._fecha_hora(
            datos.get("fecha_llegada"), datos.get("hora_llegada"), "llegada")

        cursor.execute(f"SELECT (NOW() AT TIME ZONE '{self.ZONA}') AS ahora")
        ahora = cursor.fetchone()["ahora"]
        if salida <= ahora:
            raise ErrorVuelo("La salida debe ser en el futuro")
        if hora_salida.minute % self.PASO_MINUTOS or hora_llegada.minute % self.PASO_MINUTOS:
            raise ErrorVuelo(
                f"Las horas van de {self.PASO_MINUTOS} en {self.PASO_MINUTOS} minutos (08:00, 08:05…)")
        if llegada <= salida:
            raise ErrorVuelo("La llegada debe ser después de la salida")
        if llegada - salida < self.DURACION_MINIMA:
            raise ErrorVuelo("Un vuelo debe durar al menos 30 minutos")
        if llegada - salida > self.DURACION_MAXIMA:
            raise ErrorVuelo("Un vuelo no puede durar más de 24 horas")

        try:
            precio = Decimal(str(datos.get("precio"))).quantize(Decimal("0.01"), ROUND_HALF_UP)
        except Exception:
            raise ErrorVuelo("El precio no es válido")
        if not precio.is_finite():  # "NaN" o "Infinity" no fallan al convertirse
            raise ErrorVuelo("El precio no es válido")
        if precio <= 0:
            raise ErrorVuelo("El precio debe ser mayor a $0")
        if precio > self.PRECIO_MAXIMO:
            raise ErrorVuelo(f"El precio no puede superar ${self.PRECIO_MAXIMO:,}")

        try:
            filas = int(datos.get("filas"))
            por_fila = int(datos.get("asientos_por_fila"))
        except (TypeError, ValueError):
            raise ErrorVuelo("Indica las filas y los asientos por fila")
        if por_fila not in self.CABINAS:
            raise ErrorVuelo(f"Los asientos por fila deben estar entre 2 y {len(self.LETRAS)}")
        minimo, maximo = self.CABINAS[por_fila]
        if not minimo <= filas <= maximo:
            raise ErrorVuelo(
                f"Con {por_fila} asientos por fila, las filas deben estar entre {minimo} y {maximo}")

        return {
            "aerolinea": aerolinea,
            "origen": origen,
            "destino": destino,
            "fecha": fecha,
            "fecha_llegada": fecha_llegada,
            "hora_salida": hora_salida,
            "hora_llegada": hora_llegada,
            "precio": precio,
            "asientos": self.generar_asientos(filas, por_fila),
        }

    def generar_asientos(self, filas, por_fila):
        """1A, 1B, 1C, 1D, 2A, ..."""
        letras = self.LETRAS[:por_fila]
        return [f"{fila}{letra}" for fila in range(1, filas + 1) for letra in letras]

    # ───────────────────────── Crear ─────────────────────────

    def crear(self, datos):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            d = self._validar(cursor, datos)
            self._registrar_nombres(cursor, d)
            cursor.execute("""
                INSERT INTO vuelos (aerolinea, origen, destino, fecha, fecha_llegada,
                                    hora_salida, hora_llegada, precio, asientos_disponibles, estado)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE)
                RETURNING id
            """, (d["aerolinea"], d["origen"], d["destino"], d["fecha"], d["fecha_llegada"],
                  d["hora_salida"], d["hora_llegada"], d["precio"], len(d["asientos"])))
            vuelo_id = cursor.fetchone()["id"]

            psycopg2.extras.execute_values(
                cursor,
                "INSERT INTO asientos_vuelo (vuelo_id, numero_asiento, estado) VALUES %s",
                [(vuelo_id, n, "DISPONIBLE") for n in d["asientos"]],
            )
            conexion.commit()
            return self._a_dict(self._obtener(cursor, vuelo_id))
        except Exception:
            conexion.rollback()
            raise
        finally:
            cursor.close()
            conexion.close()

    # ───────────────────────── Editar ─────────────────────────

    def actualizar(self, vuelo_id, datos):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            # Bloquea el vuelo: nadie compra ni aparta mientras se edita
            cursor.execute("SELECT id FROM vuelos WHERE id = %s FOR UPDATE", (vuelo_id,))
            if cursor.fetchone() is None:
                raise ErrorVuelo("Vuelo no encontrado", 404)
            actual = self._obtener(cursor, vuelo_id)

            # Control de concurrencia optimista: el formulario envía la huella
            # del vuelo que cargó. Si ya no coincide, otro administrador lo
            # cambió mientras se editaba y no se sobrescriben sus cambios.
            if datos.get("huella") != self._huella(actual):
                raise ErrorVuelo(
                    "Otro administrador modificó este vuelo mientras lo editabas. "
                    "Vuelve a abrirlo para ver los cambios.", 409)

            if actual["estado"] == "CANCELADO":
                raise ErrorVuelo("Reactiva el vuelo antes de editarlo", 409)
            if actual["estado"] == "SALIO":
                raise ErrorVuelo("No se puede editar un vuelo que ya salió", 409)

            d = self._validar(cursor, datos)
            self._registrar_nombres(cursor, d)

            cambia_ruta = (d["origen"].lower() != actual["origen"].lower()
                           or d["destino"].lower() != actual["destino"].lower())
            if cambia_ruta and actual["reservas_activas"] > 0:
                raise ErrorVuelo(
                    f"No se puede cambiar la ruta: el vuelo tiene {actual['reservas_activas']} "
                    "reserva(s) activa(s)", 409)

            # Asientos: se agregan los nuevos y se quitan los que sobran,
            # siempre que no estén vendidos ni en un carrito.
            cursor.execute("""
                SELECT numero_asiento,
                       (estado <> 'DISPONIBLE' OR bloqueado_hasta > NOW()) AS ocupado
                FROM asientos_vuelo WHERE vuelo_id = %s
            """, (vuelo_id,))
            existentes = {f["numero_asiento"]: f["ocupado"] for f in cursor.fetchall()}
            nuevos = set(d["asientos"])
            quitar = [n for n in existentes if n not in nuevos]
            agregar = [n for n in d["asientos"] if n not in existentes]

            ocupados = sorted(n for n in quitar if existentes[n])
            if ocupados:
                lista = ", ".join(ocupados[:6]) + ("…" if len(ocupados) > 6 else "")
                raise ErrorVuelo(
                    f"No se pueden quitar asientos vendidos o en un carrito ({lista})", 409)

            if quitar:
                cursor.execute(
                    "DELETE FROM asientos_vuelo WHERE vuelo_id = %s AND numero_asiento = ANY(%s)",
                    (vuelo_id, quitar))
            if agregar:
                psycopg2.extras.execute_values(
                    cursor,
                    "INSERT INTO asientos_vuelo (vuelo_id, numero_asiento, estado) VALUES %s",
                    [(vuelo_id, n, "DISPONIBLE") for n in agregar],
                )

            cursor.execute("""
                UPDATE vuelos
                SET aerolinea = %s, origen = %s, destino = %s, fecha = %s, fecha_llegada = %s,
                    hora_salida = %s, hora_llegada = %s, precio = %s,
                    asientos_disponibles = (SELECT COUNT(*) FROM asientos_vuelo
                                            WHERE vuelo_id = %s AND estado = 'DISPONIBLE'),
                    version = version + 1
                WHERE id = %s
            """, (d["aerolinea"], d["origen"], d["destino"], d["fecha"], d["fecha_llegada"],
                  d["hora_salida"], d["hora_llegada"], d["precio"], vuelo_id, vuelo_id))

            conexion.commit()
            return self._a_dict(self._obtener(cursor, vuelo_id))
        except Exception:
            conexion.rollback()
            raise
        finally:
            cursor.close()
            conexion.close()

    # ───────────────────────── Cancelar y reactivar ─────────────────────────

    def cancelar(self, vuelo_id):
        """Cancela el vuelo, sus reservas activas y libera los carritos.
        Un vuelo nunca se borra: así se conserva el historial de reservas."""
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            cursor.execute("SELECT id FROM vuelos WHERE id = %s FOR UPDATE", (vuelo_id,))
            if cursor.fetchone() is None:
                raise ErrorVuelo("Vuelo no encontrado", 404)
            actual = self._obtener(cursor, vuelo_id)
            if actual["estado"] == "CANCELADO":
                raise ErrorVuelo("El vuelo ya está cancelado", 409)
            if actual["estado"] == "SALIO":
                raise ErrorVuelo("No se puede cancelar un vuelo que ya salió", 409)

            cursor.execute("""
                UPDATE reservas SET estado = 'CANCELADA'
                WHERE vuelo_id = %s AND estado = 'ACTIVA'
                RETURNING cantidad_asientos
            """, (vuelo_id,))
            canceladas = cursor.fetchall()

            cursor.execute("""
                UPDATE asientos_vuelo
                SET estado = 'DISPONIBLE', reserva_id = NULL,
                    bloqueado_por = NULL, bloqueado_hasta = NULL
                WHERE vuelo_id = %s
            """, (vuelo_id,))
            total = cursor.rowcount

            cursor.execute("""
                UPDATE vuelos
                SET estado = FALSE, asientos_disponibles = %s, version = version + 1
                WHERE id = %s
            """, (total, vuelo_id))

            conexion.commit()
            return {
                "mensaje": "Vuelo cancelado",
                "reservas_canceladas": len(canceladas),
                "asientos_liberados": sum(f["cantidad_asientos"] for f in canceladas),
                "carritos_liberados": actual["en_carritos"],
            }
        except Exception:
            conexion.rollback()
            raise
        finally:
            cursor.close()
            conexion.close()

    def reactivar(self, vuelo_id):
        """Vuelve a poner a la venta un vuelo cancelado que aún no sale.
        Las reservas que se cancelaron siguen canceladas."""
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            cursor.execute("SELECT id FROM vuelos WHERE id = %s FOR UPDATE", (vuelo_id,))
            if cursor.fetchone() is None:
                raise ErrorVuelo("Vuelo no encontrado", 404)
            actual = self._obtener(cursor, vuelo_id)
            if actual["estado"] != "CANCELADO":
                raise ErrorVuelo("El vuelo no está cancelado", 409)
            if actual["ya_salio"]:
                raise ErrorVuelo("No se puede reactivar un vuelo cuya fecha ya pasó", 409)

            cursor.execute("UPDATE vuelos SET estado = TRUE, version = version + 1 WHERE id = %s",
                           (vuelo_id,))
            conexion.commit()
            return self._a_dict(self._obtener(cursor, vuelo_id))
        except Exception:
            conexion.rollback()
            raise
        finally:
            cursor.close()
            conexion.close()
