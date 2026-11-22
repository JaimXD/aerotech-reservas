from dataclasses import dataclass
from typing import Dict, Any, Optional


@dataclass
class AsientoModel:
    id: int
    vuelo_id: int
    numero_asiento: str
    estado: str
    reserva_id: Optional[int]
    en_mi_carrito: bool = False

    @staticmethod
    def from_row(row: Dict[str, Any]) -> "AsientoModel":
        return AsientoModel(
            id=row["id"],
            vuelo_id=row["vuelo_id"],
            numero_asiento=row["numero_asiento"],
            estado=row["estado"],
            reserva_id=row["reserva_id"],
            en_mi_carrito=bool(row.get("en_mi_carrito", False))
        )

    def to_dict(self):
        return {
            "id": self.id,
            "vuelo_id": self.vuelo_id,
            "numero_asiento": self.numero_asiento,
            "estado": self.estado,
            "reserva_id": self.reserva_id,
            "en_mi_carrito": self.en_mi_carrito
        }