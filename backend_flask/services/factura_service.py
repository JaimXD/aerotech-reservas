from datetime import date
from decimal import Decimal, ROUND_HALF_UP
import xml.etree.ElementTree as ET

import psycopg2.extras
from database import Database


class ErrorFactura(Exception):
    """Error de negocio al generar la factura (lleva su código HTTP)."""

    def __init__(self, mensaje, codigo=400):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.codigo = codigo


class FacturaService:
    IVA = Decimal("0.15")          # 15 % (Ecuador)
    SERIE = "P001"                 # Punto de emisión
    EMISOR = "AeroTech Reservas"

    def generar_factura_xml(self, usuario, reserva_id):
        """Devuelve (xml, nombre_archivo) de la factura de una reserva del usuario."""
        datos = self._obtener_reserva(usuario["id"], reserva_id)

        if datos is None:
            raise ErrorFactura("Reserva no encontrada", 404)

        if datos["estado"] != "ACTIVA":
            raise ErrorFactura("No se puede generar la factura de una reserva cancelada")

        xml = self.construir_xml(usuario, datos, date.today())
        nombre = f"factura_{datos['codigo_reserva']}.xml"
        return xml, nombre

    # ─────────────────────────── Datos ───────────────────────────

    def _obtener_reserva(self, usuario_id, reserva_id):
        conexion = Database.obtener_conexion()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        try:
            cursor.execute("""
                SELECT
                    r.id, r.codigo_reserva, r.cantidad_asientos, r.total,
                    r.estado, r.fecha_reserva,
                    v.aerolinea, v.origen, v.destino, v.fecha,
                    v.hora_salida, v.hora_llegada,
                    COALESCE(
                        ARRAY_AGG(av.numero_asiento ORDER BY av.numero_asiento)
                        FILTER (WHERE av.numero_asiento IS NOT NULL),
                        ARRAY[]::VARCHAR[]
                    ) AS asientos
                FROM reservas r
                INNER JOIN vuelos v ON v.id = r.vuelo_id
                LEFT JOIN asientos_vuelo av ON av.reserva_id = r.id
                WHERE r.id = %s AND r.usuario_id = %s
                GROUP BY r.id, v.id
            """, (reserva_id, usuario_id))
            return cursor.fetchone()

        finally:
            cursor.close()
            conexion.close()

    # ──────────────────────────── XML ────────────────────────────

    @staticmethod
    def _dinero(valor):
        return Decimal(str(valor)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

    def construir_xml(self, usuario, datos, fecha_emision):
        cantidad = int(datos["cantidad_asientos"]) or 1
        subtotal = self._dinero(datos["total"])
        precio_unitario = self._dinero(subtotal / cantidad)
        iva = self._dinero(subtotal * self.IVA)
        total = subtotal + iva
        asientos = list(datos["asientos"] or [])

        factura = ET.Element("factura")

        def hijo(padre, etiqueta, texto="", **atributos):
            nodo = ET.SubElement(padre, etiqueta, {k: str(v) for k, v in atributos.items()})
            nodo.text = str(texto)
            return nodo

        hijo(factura, "numero", f"{self.SERIE}-{int(datos['id']):06d}")
        hijo(factura, "fecha", fecha_emision.isoformat())

        emisor = ET.SubElement(factura, "emisor")
        hijo(emisor, "nombre", self.EMISOR)

        cliente = ET.SubElement(factura, "cliente")
        hijo(cliente, "nombre", usuario.get("nombre_completo") or usuario.get("usuario"))
        hijo(cliente, "usuario", usuario.get("usuario", ""))
        hijo(cliente, "correo", usuario.get("correo", ""))

        reserva = ET.SubElement(factura, "reserva")
        hijo(reserva, "codigo", datos["codigo_reserva"])
        hijo(reserva, "fecha_reserva", str(datos["fecha_reserva"])[:10])

        vuelo = ET.SubElement(factura, "vuelo")
        hijo(vuelo, "aerolinea", datos["aerolinea"])
        hijo(vuelo, "origen", datos["origen"])
        hijo(vuelo, "destino", datos["destino"])
        hijo(vuelo, "fecha", str(datos["fecha"]))
        hijo(vuelo, "hora_salida", str(datos["hora_salida"])[:5])
        hijo(vuelo, "hora_llegada", str(datos["hora_llegada"])[:5])

        detalle = ET.SubElement(factura, "detalle")
        item = ET.SubElement(detalle, "item")
        hijo(item, "descripcion", f"Pasaje aéreo {datos['origen']} - {datos['destino']}")
        hijo(item, "asientos", ", ".join(asientos))
        hijo(item, "cantidad", cantidad)
        hijo(item, "precio_unitario", precio_unitario)
        hijo(item, "subtotal", subtotal)

        hijo(factura, "subtotal", subtotal)
        hijo(factura, "iva", iva, porcentaje=int(self.IVA * 100))
        hijo(factura, "total", total)

        ET.indent(factura, space="  ")
        cuerpo = ET.tostring(factura, encoding="unicode")
        return '<?xml version="1.0" encoding="UTF-8"?>\n' + cuerpo + "\n"
