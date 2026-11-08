from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class LoginResponseModel:
    mensaje: str
    usuario: Dict[str, Any]
    token: str
    expiracion: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "mensaje": self.mensaje,
            "usuario": self.usuario,
            "token": self.token,
            "expiracion": self.expiracion,
        }
