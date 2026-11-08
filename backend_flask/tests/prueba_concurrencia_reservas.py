import requests
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE_URL = "http://127.0.0.1:5000"

CREDENCIALES = {
    "usuario": "ana",
    "password": "12345"
}


def obtener_token():
    r = requests.post(f"{BASE_URL}/api/auth/login", json=CREDENCIALES, timeout=10)
    if r.status_code != 200:
        raise Exception(f"No se pudo iniciar sesión: {r.status_code} {r.text}")
    return r.json()["token"]


def reservar(token, vuelo_id, cantidad, numero):
    inicio = time.time()
    try:
        r = requests.post(
            f"{BASE_URL}/api/reservas",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            json={"vuelo_id": vuelo_id, "cantidad_asientos": cantidad},
            timeout=30
        )
        fin = time.time()
        return {
            "n": numero,
            "status": r.status_code,
            "ok": r.status_code in [200, 201],
            "tiempo": fin - inicio,
            "respuesta": r.text[:300]
        }
    except Exception as e:
        fin = time.time()
        return {"n": numero, "status": 0, "ok": False, "tiempo": fin - inicio, "respuesta": str(e)}


def ejecutar(hilos=20, vuelo_id=1, cantidad=1):
    token = obtener_token()
    resultados = []
    inicio_total = time.time()
    with ThreadPoolExecutor(max_workers=hilos) as executor:
        tareas = [executor.submit(reservar, token, vuelo_id, cantidad, i) for i in range(1, hilos + 1)]
        for t in as_completed(tareas):
            resultados.append(t.result())
    fin_total = time.time()
    exitosas = sum(1 for r in resultados if r["ok"])
    fallidas = len(resultados) - exitosas
    promedio = sum(r["tiempo"] for r in resultados) / len(resultados)
    print("====================================")
    print(f"PRUEBA DE CONCURRENCIA: {hilos} HILOS")
    print("====================================")
    print(f"Solicitudes enviadas: {len(resultados)}")
    print(f"Exitosas: {exitosas}")
    print(f"Fallidas: {fallidas}")
    print(f"Tiempo promedio: {promedio:.4f}s")
    print(f"Tiempo total: {(fin_total - inicio_total):.4f}s")
    print("\nEjemplos de respuestas fallidas:")
    for r in resultados:
        if not r["ok"]:
            print(f"Status {r['status']}: {r['respuesta']}")
            break


if __name__ == "__main__":
    ejecutar(hilos=20, vuelo_id=1, cantidad=1)
