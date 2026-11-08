import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()


class Database:
    @staticmethod
    def obtener_conexion():
        try:
            print("==== DATOS DE CONEXIÓN ====")
            print("DB_HOST:", os.getenv("DB_HOST"))
            print("DB_NAME:", os.getenv("DB_NAME", "postgres"))
            print("DB_USER:", os.getenv("DB_USER", "postgres"))
            print("DB_PORT:", os.getenv("DB_PORT", "5432"))
            print("DB_PASSWORD existe:", os.getenv("DB_PASSWORD") is not None)
            print("===========================")

            conexion = psycopg2.connect(
                host=os.getenv("DB_HOST"),
                database=os.getenv("DB_NAME", "postgres"),
                user=os.getenv("DB_USER", "postgres"),
                password=os.getenv("DB_PASSWORD"),
                port=os.getenv("DB_PORT", "5432"),
                sslmode=os.getenv("DB_SSLMODE", "require"),
                connect_timeout=10
            )

            print("Conexión a Supabase exitosa")
            return conexion

        except Exception as e:
            print("ERROR AL CONECTAR CON SUPABASE:")
            print(repr(e))
            raise e