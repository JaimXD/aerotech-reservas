from database import Database

try:
    conexion = Database.obtener_conexion()
    cursor = conexion.cursor()

    cursor.execute("SELECT NOW();")
    resultado = cursor.fetchone()

    print("Conexión correcta a Supabase")
    print("Fecha servidor:", resultado[0])

    cursor.close()
    conexion.close()

except Exception as e:
    print("Error de conexión:")
    print(type(e))
    print(repr(e))
    print(str(e))