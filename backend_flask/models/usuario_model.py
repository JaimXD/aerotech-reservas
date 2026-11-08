from dataclasses import dataclass
from typing import Optional, Dict, Any

@dataclass
class UsuarioModel:
    id: Optional[int]
    usuario: str
    nombre_completo: str
    correo: str
    cedula: Optional[str] = None
    estado: bool = True

    @staticmethod
    def from_row(row: Dict[str, Any]) -> "UsuarioModel":
        return UsuarioModel(
            id=row.get("id"),
            usuario=row.get("usuario", ""),
            nombre_completo=row.get("nombre_completo", ""),
            correo=row.get("correo", ""),
            cedula=row.get("cedula"),
            estado=row.get("estado", True),
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "usuario": self.usuario,
            "nombre_completo": self.nombre_completo,
            "correo": self.correo,
            "cedula": self.cedula,
            "estado": self.estado,
        }
