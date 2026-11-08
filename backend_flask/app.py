from flask import Flask, request, jsonify
from flask_cors import CORS

from services.registro_service import RegistroService, ErrorRegistro

from services.auth_service import AuthService
from services.vuelo_service import VueloService
from services.reserva_service import ReservaService
from services.asiento_service import AsientoService
from services.admin_vuelo_service import AdminVueloService

app = Flask(__name__)
CORS(app)

auth_service = AuthService()
vuelo_service = VueloService()
reserva_service = ReservaService()
asiento_service = AsientoService()
admin_vuelo_service = AdminVueloService()

def obtener_usuario_desde_token():
    try:
        auth_header = request.headers.get("Authorization")

        print("obtener")

        if not auth_header:
            return None, jsonify({"error": "Token no enviado"}), 401

        if not auth_header.startswith("Bearer "):
            return None, jsonify({"error": "Formato de token inválido"}), 401

        token = auth_header.replace("Bearer ", "")
        usuario = auth_service.validar_token(token)

        if usuario is None:
            return None, jsonify({"error": "Token inválido o expirado"}), 401
        print("sasdasdsad")
        return usuario, None, None
    except Exception as e:
        print("Error al validar token:", repr(e))
        return None, jsonify({"error": "Error al validar token", "detalle": str(e)}), 500   

@app.route("/")
def inicio():
    return jsonify({
        "mensaje": "API AeroTech Reservas funcionando",
        "arquitectura": "Flutter + Flask + Render + Supabase"
    })


@app.route("/api/usuarios/registro", methods=["POST"])
def _error_registro(e: ErrorRegistro):
    return jsonify({"error": str(e), **e.extra}), e.estado_http


@app.route("/api/registro/enviar-codigo", methods=["POST"])
def registro_enviar_codigo():
    datos = request.get_json(silent=True) or {}
    try:
        return jsonify(RegistroService.enviar_codigo(datos.get("correo"))), 200
    except ErrorRegistro as e:
        return _error_registro(e)
    except Exception:
        app.logger.exception("Error interno enviando código de registro")
        return jsonify({"error": "No se pudo enviar el código"}), 500


@app.route("/api/registro/verificar-codigo", methods=["POST"])
def registro_verificar_codigo():
    datos = request.get_json(silent=True) or {}
    try:
        resultado = RegistroService.verificar_codigo(datos.get("correo"), datos.get("codigo"))
        return jsonify(resultado), 200
    except ErrorRegistro as e:
        return _error_registro(e)
    except Exception:
        app.logger.exception("Error interno verificando código de registro")
        return jsonify({"error": "No se pudo verificar el código"}), 500


@app.route("/api/registro/completar", methods=["POST"])
def registro_completar():
    datos = request.get_json(silent=True)
    try:
        return jsonify(RegistroService.completar(datos)), 201
    except ErrorRegistro as e:
        return _error_registro(e)
    except Exception:
        app.logger.exception("Error interno completando registro")
        return jsonify({"error": "No se pudo crear la cuenta"}), 500


@app.route("/api/auth/login", methods=["POST"])
def login():
    datos = request.get_json(silent=True)

    if not datos:
        return jsonify({"error": "No se recibió JSON válido"}), 400

    usuario = datos.get("usuario")
    password = datos.get("password")

    if not usuario or not password:
        return jsonify({"error": "Usuario y contraseña son obligatorios"}), 400

    try:
        resultado = auth_service.login(usuario, password)

        if resultado is None:
            return jsonify({"error": "Credenciales inválidas"}), 401
        if resultado.get("correo_pendiente"):
            return jsonify({
                "error": "Debes verificar tu correo antes de iniciar sesión",
                "codigo": "CORREO_NO_VERIFICADO"
            }), 403

        return jsonify(resultado), 200

    except Exception as e:
        return jsonify({
            "error": "No se pudo iniciar sesión",
            "detalle": str(e)
        }), 500


@app.route("/api/vuelos", methods=["GET"])
def vuelos():
    print("vuelos????????????????????????????????????????????????????????????????????")
    usuario, error, codigo = obtener_usuario_desde_token()
    print(error, codigo)

    if error:
        return error, codigo

    origen = request.args.get("origen")
    destino = request.args.get("destino")
    fecha = request.args.get("fecha")
    fecha_inicio = request.args.get("fecha_inicio")
    fecha_fin = request.args.get("fecha_fin")

    try:
        vuelos_disponibles = vuelo_service.buscar_vuelos(
            origen=origen,
            destino=destino,
            fecha=fecha,
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin
        )
        return jsonify(vuelos_disponibles), 200

    except Exception as e:
        return jsonify({
            "error": "No se pudieron obtener los vuelos",
            "detalle": str(e)
        }), 500


@app.route("/api/reservas", methods=["POST"])
def reservar():
    usuario, error, codigo = obtener_usuario_desde_token()

    if error:
        return error, codigo

    datos = request.get_json(silent=True)

    if not datos:
        return jsonify({"error": "No se recibió JSON válido"}), 400

    vuelo_id = datos.get("vuelo_id")
    cantidad_asientos = datos.get("cantidad_asientos")

    if not vuelo_id or not cantidad_asientos:
        return jsonify({"error": "vuelo_id y cantidad_asientos son obligatorios"}), 400

    try:
        reserva = reserva_service.crear_reserva(
            usuario["id"],
            int(vuelo_id),
            int(cantidad_asientos)
        )

        return jsonify({
            "mensaje": "Reserva registrada correctamente",
            "reserva": reserva
        }), 201

    except Exception as e:
        return jsonify({
            "error": "No se pudo registrar la reserva",
            "detalle": str(e)
        }), 400


@app.route("/api/reservas/mis-reservas", methods=["GET"])
def mis_reservas():
    usuario, error, codigo = obtener_usuario_desde_token()

    if error:
        return error, codigo

    try:
        reservas = reserva_service.listar_mis_reservas(usuario["id"])
        return jsonify(reservas), 200

    except Exception as e:
        return jsonify({
            "error": "No se pudieron obtener las reservas",
            "detalle": str(e)
        }), 500


@app.route("/api/reservas/<int:reserva_id>/cancelar", methods=["PUT"])
def cancelar(reserva_id):
    usuario, error, codigo = obtener_usuario_desde_token()

    if error:
        return error, codigo

    try:
        resultado = reserva_service.cancelar_reserva(usuario["id"], reserva_id)

        if resultado is None:
            return jsonify({"error": "Reserva no encontrada"}), 404

        if resultado == "NO_ACTIVA":
            return jsonify({"error": "La reserva no se encuentra activa"}), 400

        return jsonify({"mensaje": "Reserva cancelada correctamente"}), 200

    except Exception as e:
        return jsonify({
            "error": "No se pudo cancelar la reserva",
            "detalle": str(e)
        }), 400

@app.route("/reservas/<int:reserva_id>", methods=["PUT"])
@app.route("/api/reservas/<int:reserva_id>", methods=["PUT"])
def editar_reserva(reserva_id):
    usuario, error, codigo = obtener_usuario_desde_token()

    if error:
        return error, codigo

    datos = request.get_json(silent=True)

    if not datos:
        return jsonify({"error": "No se recibió JSON válido"}), 400

    try:
        resultado = reserva_service.editar_reserva(usuario["id"], reserva_id, datos)
        return jsonify(resultado), 200

    except Exception as e:
        return jsonify({
            "error": "No se pudo modificar la reserva",
            "detalle": str(e)
        }), 400

@app.route("/api/vuelos/<int:vuelo_id>/asientos", methods=["GET"])
def listar_asientos_vuelo(vuelo_id):
    usuario, error, codigo = obtener_usuario_desde_token()

    if error:
        return error, codigo

    try:
        asientos = asiento_service.listar_asientos_por_vuelo(vuelo_id)

        return jsonify(asientos), 200

    except Exception as e:
        return jsonify({
            "error": "No se pudieron obtener los asientos del vuelo",
            "detalle": str(e)
        }), 500
    
@app.route("/api/reservas/asientos", methods=["POST"])
def reservar_asientos():
    usuario, error, codigo = obtener_usuario_desde_token()

    if error:
        return error, codigo

    datos = request.get_json(silent=True)

    if not datos:
        return jsonify({
            "error": "No se recibió JSON válido"
        }), 400

    vuelo_id = datos.get("vuelo_id")
    asientos = datos.get("asientos")

    if not vuelo_id:
        return jsonify({
            "error": "El campo vuelo_id es obligatorio"
        }), 400

    if not isinstance(asientos, list) or len(asientos) == 0:
        return jsonify({
            "error": "Debe seleccionar al menos un asiento"
        }), 400

    try:
        reserva = asiento_service.crear_reserva_con_asientos(
            usuario["id"],
            int(vuelo_id),
            asientos
        )

        return jsonify({
            "mensaje": "Reserva registrada correctamente",
            "reserva": reserva
        }), 201

    except Exception as e:
        print("ERROR EN RESERVAR ASIENTOS:", repr(e))
        return jsonify({
            "error": "No se pudo registrar la reserva",
            "detalle": str(e)
        }), 400

@app.route("/api/admin/vuelos", methods=["POST"])
def crear_vuelo():
    usuario, error, codigo = obtener_usuario_desde_token()

    if error:
        return error, codigo

    if usuario.get("role") != "admin" and usuario.get("tipo_usuario") != "admin":
        return jsonify({"error": "No autorizado: se requiere rol de administrador"}), 403

    datos = request.get_json(silent=True)

    if not datos:
        return jsonify({
            "error": "No se recibió JSON válido"
        }), 400

    campos = [
        "aerolinea",
        "origen",
        "destino",
        "fecha",
        "fecha_llegada",
        "hora_salida",
        "hora_llegada",
        "precio",
        "cantidad_asientos"
    ]

    for campo in campos:
        if datos.get(campo) is None or datos.get(campo) == "":
            return jsonify({
                "error": f"El campo {campo} es obligatorio"
            }), 400

    try:
        vuelo = admin_vuelo_service.crear_vuelo_con_asientos(datos)

        return jsonify({
            "mensaje": "Vuelo creado correctamente",
            "vuelo": vuelo
        }), 201

    except Exception as e:
        return jsonify({
            "error": "No se pudo crear el vuelo",
            "detalle": str(e)
        }), 400

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
