"""Prueba de Resend sin crear usuarios, OTP ni tocar la base de datos.
Ejecutar desde backend_flask con: python probar_resend.py tu_correo@ejemplo.com
"""
import sys
from dotenv import load_dotenv

load_dotenv()

from services.email_service import EmailService  # noqa: E402


def main():
    if len(sys.argv) != 2 or "@" not in sys.argv[1]:
        print("Uso: python probar_resend.py tu_correo@ejemplo.com")
        return 2
    try:
        id_mensaje = EmailService.enviar_prueba(sys.argv[1])
    except Exception as exc:
        # No mostramos ni token ni cabeceras de autenticación.
        print(f"Error enviando correo: {exc}")
        return 1
    print("Resend aceptó el envío correctamente.")
    print(f"ID de mensaje: {id_mensaje}")
    print("Revisa el correo de destino y el panel Resend > Emails para comprobar su entrega.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
