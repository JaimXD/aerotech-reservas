import sys
import os

# Add the backend_flask folder to path so database and utils can be imported
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import Database
from utils.seguridad import Seguridad

def insert_admin():
    admin_username = "admin"
    admin_password = "AdminPassword123"
    admin_name = "Administrador del Sistema"
    admin_email = "admin@aerotech.com"
    admin_cedula = "1721868351"  # Valid Ecuadorian ID passing validation
    admin_role = "admin"

    print("Generando hash de la contraseña...")
    password_hash = Seguridad.generar_hash(admin_password)

    print("Conectando a la base de datos...")
    conexion = Database.obtener_conexion()
    cursor = conexion.cursor()

    try:
        # Check if user already exists
        cursor.execute("SELECT id FROM usuarios WHERE usuario = %s", (admin_username,))
        row = cursor.fetchone()

        if row:
            print(f"El usuario '{admin_username}' ya existe. Actualizando credenciales y rol...")
            cursor.execute("""
                UPDATE usuarios
                SET password_hash = %s,
                    nombre_completo = %s,
                    correo = %s,
                    cedula = %s,
                    rol = %s,
                    estado = TRUE
                    correo_verificado = TRUE
                WHERE usuario = %s
            """, (password_hash, admin_name, admin_email, admin_cedula, admin_role, admin_username))
            print("Usuario administrador actualizado con éxito.")
        else:
            # Check if email already exists for another user
            cursor.execute("SELECT usuario FROM usuarios WHERE correo = %s", (admin_email,))
            email_row = cursor.fetchone()
            if email_row:
                print(f"ERROR: El correo '{admin_email}' ya está registrado con el usuario '{email_row[0]}'.")
                return

            print(f"Insertando nuevo usuario administrador '{admin_username}'...")
            cursor.execute("""
                INSERT INTO usuarios (usuario, password_hash, nombre_completo, correo, cedula, rol, estado, correo_verificado)
                VALUES (%s, %s, %s, %s, %s, %s, TRUE, TRUE)
            """, (admin_username, password_hash, admin_name, admin_email, admin_cedula, admin_role))
            print("Usuario administrador insertado con éxito.")

        conexion.commit()
        print("\n==============================================")
        print("CREDENCIALES DEL ADMINISTRADOR:")
        print(f"Usuario: {admin_username}")
        print(f"Contraseña: {admin_password}")
        print(f"Correo: {admin_email}")
        print(f"Rol: {admin_role}")
        print("==============================================")

    except Exception as e:
        conexion.rollback()
        print("ERROR:", e)
    finally:
        cursor.close()
        conexion.close()

if __name__ == "__main__":
    insert_admin()
