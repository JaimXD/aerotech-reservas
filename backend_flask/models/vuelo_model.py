from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class VueloModel:
    id: int
    aerolinea: str
    origen: str
    destino: str
    fecha: str
    hora_salida: str
    hora_llegada: str
    precio: float
    asientos_disponibles: int
    fecha_llegada: str = ""

    @staticmethod
    def from_row(row: Dict[str, Any]) -> "VueloModel":
        return VueloModel(
            id=row["id"],
            aerolinea=row["aerolinea"],
            origen=row["origen"],
            destino=row["destino"],
            fecha=str(row["fecha"]),
            hora_salida=str(row["hora_salida"]),
            hora_llegada=str(row["hora_llegada"]),
            precio=float(row["precio"]),
            asientos_disponibles=row["asientos_disponibles"],
            fecha_llegada=str(row.get("fecha_llegada", row["fecha"])),
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "aerolinea": self.aerolinea,
            "origen": self.origen,
            "destino": self.destino,
            "fecha": self.fecha,
            "hora_salida": self.hora_salida,
            "hora_llegada": self.hora_llegada,
            "precio": self.precio,
            "asientos_disponibles": self.asientos_disponibles,
            "fecha_llegada": self.fecha_llegada,
        }
