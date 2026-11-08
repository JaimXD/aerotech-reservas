from dataclasses import dataclass
from typing import Dict, Any, Optional

@dataclass
class ReservaModel:
    id: int
    codigo_reserva: str
    cantidad_asientos: int
    total: float
    estado: str
    fecha_reserva: Optional[str] = None
    aerolinea: Optional[str] = None
    origen: Optional[str] = None
    destino: Optional[str] = None
    fecha_vuelo: Optional[str] = None
    hora_salida: Optional[str] = None
    hora_llegada: Optional[str] = None

    @staticmethod
    def from_row(row: Dict[str, Any]) -> "ReservaModel":
        return ReservaModel(
            id=row["id"],
            codigo_reserva=row["codigo_reserva"],
            cantidad_asientos=row["cantidad_asientos"],
            total=float(row["total"]),
            estado=row["estado"],
            fecha_reserva=str(row.get("fecha_reserva")) if row.get("fecha_reserva") else None,
            aerolinea=row.get("aerolinea"),
            origen=row.get("origen"),
            destino=row.get("destino"),
            fecha_vuelo=str(row.get("fecha")) if row.get("fecha") else None,
            hora_salida=str(row.get("hora_salida")) if row.get("hora_salida") else None,
            hora_llegada=str(row.get("hora_llegada")) if row.get("hora_llegada") else None,
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "codigo_reserva": self.codigo_reserva,
            "cantidad_asientos": self.cantidad_asientos,
            "total": self.total,
            "estado": self.estado,
            "fecha_reserva": self.fecha_reserva,
            "aerolinea": self.aerolinea,
            "origen": self.origen,
            "destino": self.destino,
            "fecha_vuelo": self.fecha_vuelo,
            "hora_salida": self.hora_salida,
            "hora_llegada": self.hora_llegada,
        }
