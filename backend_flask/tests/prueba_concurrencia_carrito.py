"""
Prueba de concurrencia del carrito (bloqueo temporal de asientos).

Varios usuarios intentan apartar EL MISMO asiento en el MISMO instante.
Resultado esperado en cada ronda: 1 usuario lo consigue (200) y el resto
recibe 409 Conflict.

Uso (con el backend corriendo):
    python tests/prueba_concurrencia_carrito.py --vuelo 1
    python tests/prueba_concurrencia_carrito.py --vuelo 1 --asientos 3B 3C
    python tests/prueba_concurrencia_carrito.py --vuelo 1 --vencimiento
    python tests/prueba_concurrencia_carrito.py --vuelo 1 --doble-pago
"""

import argparse
import getpass
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

import requests

ARCHIVO_RESULTADOS = Path(__file__).with_name("resultados_concurrencia_carrito.txt")
_lineas = []


def log(texto=""):
    """Imprime y guarda la línea para el archivo de evidencia."""
    print(texto)
    _lineas.append(texto)


# ════════════════════════════════════════════════════════════════
#  Cliente de la API (un objeto por usuario)
# ════════════════════════════════════════════════════════════════

class Cliente:
    def __init__(self, base_url, usuario, token):
        self.base_url = base_url
        self.usuario = usuario
        self.headers = {"Authorization": f"Bearer {token}"}

    @staticmethod
    def iniciar_sesion(base_url, usuario, password):
        r = requests.post(
            f"{base_url}/api/auth/login",
            json={"usuario": usuario, "password": password},
            timeout=15,
        )
        if r.status_code != 200:
            raise RuntimeError(f"No se pudo iniciar sesión con '{usuario}': {r.status_code} {r.text[:150]}")
        return Cliente(base_url, usuario, r.json()["token"])

    def apartar(self, vuelo_id, asientos):
        return requests.post(
            f"{self.base_url}/api/carrito/items",
            headers=self.headers,
            json={"vuelo_id": vuelo_id, "asientos": asientos},
            timeout=30,
        )

    def carrito(self):
        return requests.get(f"{self.base_url}/api/carrito", headers=self.headers, timeout=15).json()

    def vaciar(self):
        requests.delete(f"{self.base_url}/api/carrito", headers=self.headers, timeout=15)

    def confirmar(self):
        return requests.post(f"{self.base_url}/api/carrito/confirmar", headers=self.headers, json={}, timeout=30)

    def estado_asiento(self, vuelo_id, numero):
        r = requests.get(f"{self.base_url}/api/vuelos/{vuelo_id}/asientos", headers=self.headers, timeout=15)
        for a in r.json():
            if a["numero_asiento"] == numero:
                return a["estado"], a.get("en_mi_carrito", False)
        return None, False


def pedir_usuarios(base_url, cantidad):
    """Pide usuario y contraseña por consola (no quedan escritos en el código)."""
    clientes = []
    print(f"Ingresa {cantidad} usuarios de prueba (deben tener el correo verificado).")
    while len(clientes) < cantidad:
        usuario = input(f"  Usuario {len(clientes) + 1}: ").strip()
        password = getpass.getpass("  Contraseña: ")
        try:
            clientes.append(Cliente.iniciar_sesion(base_url, usuario, password))
            print("  Sesión iniciada.\n")
        except Exception as e:
            print(f"  {e}\n")
    return clientes


def asientos_libres(cliente, vuelo_id, cantidad):
    r = requests.get(f"{cliente.base_url}/api/vuelos/{vuelo_id}/asientos", headers=cliente.headers, timeout=15)
    r.raise_for_status()
    libres = [a["numero_asiento"] for a in r.json() if a["estado"] == "DISPONIBLE" and not a.get("en_mi_carrito")]
    if len(libres) < cantidad:
        raise RuntimeError(f"El vuelo {vuelo_id} solo tiene {len(libres)} asientos libres")
    return libres[:cantidad]


# ════════════════════════════════════════════════════════════════
#  Prueba 1: carrera por el mismo asiento
# ════════════════════════════════════════════════════════════════

def carrera(clientes, vuelo_id, asiento):
    """Todos los usuarios piden el asiento a la vez (una barrera los sincroniza)."""
    barrera = threading.Barrier(len(clientes))

    def intentar(cliente):
        barrera.wait()  # nadie sale hasta que todos están listos
        inicio = time.perf_counter()
        r = cliente.apartar(vuelo_id, [asiento])
        return {
            "usuario": cliente.usuario,
            "status": r.status_code,
            "ms": (time.perf_counter() - inicio) * 1000,
            "mensaje": r.json().get("error", "Apartado en el carrito") if r.content else "",
        }

    with ThreadPoolExecutor(max_workers=len(clientes)) as pool:
        return list(pool.map(intentar, clientes))


def prueba_carrera(clientes, vuelo_id, asientos):
    log("PRUEBA 1: varios usuarios apartan el mismo asiento al mismo tiempo")
    log("-" * 70)
    resultados = []

    for ronda, asiento in enumerate(asientos, start=1):
        respuestas = carrera(clientes, vuelo_id, asiento)
        ganadores = [r for r in respuestas if r["status"] == 200]
        rechazados = [r for r in respuestas if r["status"] == 409]

        log(f"\nRonda {ronda} - vuelo {vuelo_id}, asiento {asiento}")
        for r in sorted(respuestas, key=lambda x: x["status"]):
            log(f"  {r['usuario']:<15} HTTP {r['status']}  {r['ms']:7.1f} ms  {r['mensaje']}")

        # Cómo ve el asiento cada usuario después de la carrera
        vistas_ok = True
        for c in clientes:
            estado, mio = c.estado_asiento(vuelo_id, asiento)
            es_ganador = any(g["usuario"] == c.usuario for g in ganadores)
            esperado = ("DISPONIBLE", True) if es_ganador else ("BLOQUEADO", False)
            vistas_ok &= (estado, mio) == esperado
            log(f"  {c.usuario:<15} ve el asiento como {estado}{' (en su carrito)' if mio else ''}")

        paso = len(ganadores) == 1 and len(rechazados) == len(clientes) - 1 and vistas_ok
        log(f"  Resultado: {'[OK]' if paso else '[FALLO]'} "
            f"{len(ganadores)} ganador, {len(rechazados)} rechazados con 409")
        resultados.append((asiento, paso, ganadores[0]["usuario"] if ganadores else None))

    return resultados


# ════════════════════════════════════════════════════════════════
#  Prueba 2 (opcional): el bloqueo vence solo
# ════════════════════════════════════════════════════════════════

def prueba_vencimiento(clientes, vuelo_id, asiento, ganador):
    log("\nPRUEBA 2: el bloqueo vence solo y el asiento vuelve a estar libre")
    log("-" * 70)
    dueno = next(c for c in clientes if c.usuario == ganador)
    otro = next(c for c in clientes if c.usuario != ganador)

    r = otro.apartar(vuelo_id, [asiento])
    log(f"  Antes de vencer: {otro.usuario} intenta {asiento} -> HTTP {r.status_code}")
    antes_ok = r.status_code == 409

    log("  Esperando a que venza el bloqueo (máx. 11 min).")
    log("  Para no esperar, puedes ejecutar en Supabase:")
    log("    UPDATE asientos_vuelo SET bloqueado_hasta = NOW() WHERE bloqueado_por IS NOT NULL;")
    limite = time.time() + 11 * 60
    while time.time() < limite:
        items = dueno.carrito()["items"]
        item = next((i for i in items if i["vuelo"]["id"] == vuelo_id and asiento in i["asientos"]), None)
        if item is None:
            break
        print(f"\r  Faltan {item['segundos_restantes'] // 60:02d}:{item['segundos_restantes'] % 60:02d}   ", end="")
        time.sleep(5)
    print()

    r = otro.apartar(vuelo_id, [asiento])
    log(f"  Después de vencer: {otro.usuario} intenta {asiento} -> HTTP {r.status_code}")
    paso = antes_ok and r.status_code == 200
    log(f"  Resultado: {'[OK]' if paso else '[FALLO]'}")
    return paso


# ════════════════════════════════════════════════════════════════
#  Prueba 3 (opcional): doble clic en "Confirmar y pagar"
# ════════════════════════════════════════════════════════════════

def prueba_doble_pago(cliente, vuelo_id, asiento):
    log("\nPRUEBA 3: el mismo usuario confirma el pago dos veces al mismo tiempo")
    log("-" * 70)
    cliente.vaciar()
    r = cliente.apartar(vuelo_id, [asiento])
    if r.status_code != 200:
        log(f"  No se pudo apartar {asiento}: HTTP {r.status_code}")
        return False

    barrera = threading.Barrier(2)

    def pagar(_):
        barrera.wait()
        return cliente.confirmar()

    with ThreadPoolExecutor(max_workers=2) as pool:
        respuestas = list(pool.map(pagar, range(2)))

    creadas = 0
    for r in respuestas:
        datos = r.json()
        n = len(datos.get("confirmadas", []))
        creadas += n
        log(f"  HTTP {r.status_code}  reservas creadas: {n}  {datos.get('error', '')}")

    paso = creadas == 1
    log(f"  Resultado: {'[OK]' if paso else '[FALLO]'} se creó {creadas} reserva (se esperaba 1)")
    log("  Nota: esta prueba crea una reserva real; cancélala en 'Mis reservas'.")
    return paso


# ════════════════════════════════════════════════════════════════
#  Programa principal
# ════════════════════════════════════════════════════════════════

def main():
    p = argparse.ArgumentParser(description="Prueba de concurrencia del carrito")
    p.add_argument("--url", default="http://127.0.0.1:5000", help="URL del backend")
    p.add_argument("--vuelo", type=int, required=True, help="ID del vuelo a probar")
    p.add_argument("--usuarios", type=int, default=3, help="Cuántos usuarios compiten (mín. 2)")
    p.add_argument("--asientos", nargs="*", help="Asientos a disputar (por defecto, los primeros libres)")
    p.add_argument("--rondas", type=int, default=3, help="Rondas si no indicas asientos")
    p.add_argument("--vencimiento", action="store_true", help="Probar que el bloqueo vence solo")
    p.add_argument("--doble-pago", action="store_true", help="Probar doble clic en pagar (crea una reserva)")
    args = p.parse_args()

    if args.usuarios < 2:
        p.error("Se necesitan al menos 2 usuarios")

    clientes = pedir_usuarios(args.url, args.usuarios)
    resumen = []

    try:
        for c in clientes:
            c.vaciar()  # empezar con los carritos vacíos

        asientos = args.asientos or asientos_libres(clientes[0], args.vuelo, args.rondas)

        log("=" * 70)
        log("PRUEBA DE CONCURRENCIA - CARRITO CON BLOQUEO TEMPORAL (10 min)")
        log(f"Fecha: {datetime.now():%Y-%m-%d %H:%M:%S}   Backend: {args.url}")
        log(f"Usuarios: {', '.join(c.usuario for c in clientes)}")
        log("=" * 70)

        rondas = prueba_carrera(clientes, args.vuelo, asientos)
        resumen += [(f"Carrera por {a}", ok) for a, ok, _ in rondas]

        if args.vencimiento and rondas[0][2]:
            resumen.append(("Vencimiento del bloqueo",
                            prueba_vencimiento(clientes, args.vuelo, rondas[0][0], rondas[0][2])))

        if args.doble_pago:
            libre = asientos_libres(clientes[0], args.vuelo, 1)[0]
            resumen.append(("Doble pago", prueba_doble_pago(clientes[0], args.vuelo, libre)))

    finally:
        for c in clientes:
            c.vaciar()  # liberar todo lo apartado durante la prueba

    log("\n" + "=" * 70)
    log("RESUMEN")
    for nombre, ok in resumen:
        log(f"  {'[OK]   ' if ok else '[FALLO]'} {nombre}")
    total_ok = sum(ok for _, ok in resumen)
    log(f"\n{total_ok} de {len(resumen)} pruebas pasaron.")
    log("=" * 70)

    ARCHIVO_RESULTADOS.write_text("\n".join(_lineas), encoding="utf-8")
    print(f"\nEvidencia guardada en: {ARCHIVO_RESULTADOS}")


if __name__ == "__main__":
    main()
