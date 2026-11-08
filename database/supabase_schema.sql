CREATE TABLE IF NOT EXISTS usuarios (
    id BIGSERIAL PRIMARY KEY,
    usuario VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(256) NOT NULL,
    nombre_completo VARCHAR(100) NOT NULL,
    correo VARCHAR(100) NOT NULL UNIQUE,
    cedula VARCHAR(20) NOT NULL,
    estado BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tokens (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token VARCHAR(200) NOT NULL,
    fecha_creacion TIMESTAMP DEFAULT NOW(),
    fecha_expiracion TIMESTAMP NOT NULL,
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS vuelos (
    id BIGSERIAL PRIMARY KEY,
    aerolinea VARCHAR(100) NOT NULL,
    origen VARCHAR(100) NOT NULL,
    destino VARCHAR(100) NOT NULL,
    fecha DATE NOT NULL,
    hora_salida TIME NOT NULL,
    hora_llegada TIME NOT NULL,
    precio NUMERIC(10,2) NOT NULL,
    asientos_disponibles INT NOT NULL,
    estado BOOLEAN DEFAULT TRUE,
    version INT DEFAULT 1
);

CREATE TABLE IF NOT EXISTS reservas (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT NOT NULL REFERENCES usuarios(id),
    vuelo_id BIGINT NOT NULL REFERENCES vuelos(id),
    codigo_reserva VARCHAR(50) NOT NULL UNIQUE,
    cantidad_asientos INT NOT NULL,
    total NUMERIC(10,2) NOT NULL,
    estado VARCHAR(20) DEFAULT 'ACTIVA',
    fecha_reserva TIMESTAMP DEFAULT NOW()
);


INSERT INTO vuelos
(aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles)
VALUES
('AeroAndes', 'Quito', 'Guayaquil', '2026-06-10', '08:00', '09:00', 85.00, 20),
('AeroAndes', 'Quito', 'Cuenca', '2026-06-10', '10:30', '11:30', 95.00, 15),
('SkyEcuador', 'Guayaquil', 'Quito', '2026-06-11', '14:00', '15:00', 80.00, 25),
('Condor Air', 'Manta', 'Quito', '2026-06-12', '07:00', '08:10', 110.00, 10),
('Amazonía Air', 'Quito', 'Coca', '2026-06-13', '06:30', '07:20', 120.00, 8),
('Latam Ecuador', 'Quito', 'Loja', '2026-06-14', '09:15', '10:20', 130.00, 12),
('Avianca Ecuador', 'Guayaquil', 'Cuenca', '2026-06-15', '16:00', '17:00', 90.00, 18);



CREATE OR REPLACE FUNCTION crear_reserva_segura(
    p_usuario_id BIGINT,
    p_vuelo_id BIGINT,
    p_cantidad_asientos INT
)
RETURNS TABLE (
    reserva_id BIGINT,
    codigo_reserva VARCHAR,
    total NUMERIC,
    estado VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_precio NUMERIC(10,2);
    v_asientos INT;
    v_total NUMERIC(10,2);
    v_reserva_id BIGINT;
    v_codigo VARCHAR(50);
BEGIN
    SELECT v.precio, v.asientos_disponibles
    INTO v_precio, v_asientos
    FROM vuelos v
    WHERE v.id = p_vuelo_id
      AND v.estado = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vuelo no encontrado o inactivo';
    END IF;

    IF p_cantidad_asientos <= 0 THEN
        RAISE EXCEPTION 'La cantidad de asientos debe ser mayor a cero';
    END IF;

    IF v_asientos < p_cantidad_asientos THEN
        RAISE EXCEPTION 'No existen asientos disponibles suficientes';
    END IF;

    v_total := v_precio * p_cantidad_asientos;
    v_codigo := 'RES-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISSMS') || '-' || p_usuario_id;

    INSERT INTO reservas (
        usuario_id,
        vuelo_id,
        codigo_reserva,
        cantidad_asientos,
        total,
        estado
    )
    VALUES (
        p_usuario_id,
        p_vuelo_id,
        v_codigo,
        p_cantidad_asientos,
        v_total,
        'ACTIVA'
    )
    RETURNING id INTO v_reserva_id;

    UPDATE vuelos v
    SET asientos_disponibles = v.asientos_disponibles - p_cantidad_asientos,
        version = v.version + 1
    WHERE v.id = p_vuelo_id;

    RETURN QUERY
    SELECT 
        v_reserva_id,
        v_codigo,
        v_total,
        'ACTIVA'::VARCHAR;
END;
$$;

CREATE TABLE asientos_vuelo (
    id BIGSERIAL PRIMARY KEY,
    vuelo_id BIGINT NOT NULL REFERENCES vuelos(id),
    numero_asiento VARCHAR(10) NOT NULL,
    estado VARCHAR(20) DEFAULT 'DISPONIBLE',
    reserva_id BIGINT NULL REFERENCES reservas(id),
    UNIQUE (vuelo_id, numero_asiento)
);


CREATE OR REPLACE FUNCTION crear_reserva_asientos_segura(
    p_usuario_id BIGINT,
    p_vuelo_id BIGINT,
    p_asientos TEXT[]
)
RETURNS TABLE (
    reserva_id BIGINT,
    codigo_reserva VARCHAR,
    total NUMERIC,
    estado VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_precio NUMERIC(10,2);
    v_cantidad_asientos INT;
    v_asientos_disponibles INT;
    v_total NUMERIC(10,2);
    v_reserva_id BIGINT;
    v_codigo VARCHAR(50);
    v_total_asientos_encontrados INT;
    v_total_asientos_disponibles INT;
BEGIN
    v_cantidad_asientos := array_length(p_asientos, 1);

    IF v_cantidad_asientos IS NULL OR v_cantidad_asientos <= 0 THEN
        RAISE EXCEPTION 'Debe seleccionar al menos un asiento';
    END IF;

    SELECT v.precio, v.asientos_disponibles
    INTO v_precio, v_asientos_disponibles
    FROM vuelos v
    WHERE v.id = p_vuelo_id
      AND v.estado = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vuelo no encontrado o inactivo';
    END IF;

    IF v_asientos_disponibles < v_cantidad_asientos THEN
        RAISE EXCEPTION 'No existen asientos suficientes disponibles';
    END IF;

    -- 1. Lock the specific seat rows for update safely (WITHOUT aggregates)
    PERFORM 1
    FROM asientos_vuelo av
    WHERE av.vuelo_id = p_vuelo_id
      AND av.numero_asiento = ANY(p_asientos)
    FOR UPDATE;

    -- 2. Count matching seats
    SELECT COUNT(*)
    INTO v_total_asientos_encontrados
    FROM asientos_vuelo av
    WHERE av.vuelo_id = p_vuelo_id
      AND av.numero_asiento = ANY(p_asientos);

    IF v_total_asientos_encontrados <> v_cantidad_asientos THEN
        RAISE EXCEPTION 'Uno o más asientos no existen para este vuelo';
    END IF;

    -- 3. Count available seats
    SELECT COUNT(*)
    INTO v_total_asientos_disponibles
    FROM asientos_vuelo av
    WHERE av.vuelo_id = p_vuelo_id
      AND av.numero_asiento = ANY(p_asientos)
      AND av.estado = 'DISPONIBLE';

    IF v_total_asientos_disponibles <> v_cantidad_asientos THEN
        RAISE EXCEPTION 'Uno o más asientos ya no están disponibles';
    END IF;

    v_total := v_precio * v_cantidad_asientos;
    v_codigo := 'RES-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISSMS') || '-' || p_usuario_id;

    INSERT INTO reservas (
        usuario_id,
        vuelo_id,
        codigo_reserva,
        cantidad_asientos,
        total,
        estado
    )
    VALUES (
        p_usuario_id,
        p_vuelo_id,
        v_codigo,
        v_cantidad_asientos,
        v_total,
        'ACTIVA'
    )
    RETURNING id INTO v_reserva_id;

    UPDATE asientos_vuelo av
    SET estado = 'RESERVADO',
        reserva_id = v_reserva_id
    WHERE av.vuelo_id = p_vuelo_id
      AND av.numero_asiento = ANY(p_asientos);

    UPDATE vuelos v
    SET asientos_disponibles = v.asientos_disponibles - v_cantidad_asientos,
        version = v.version + 1
    WHERE v.id = p_vuelo_id;

    RETURN QUERY
    SELECT 
        v_reserva_id,
        v_codigo,
        v_total,
        'ACTIVA'::VARCHAR;
END;
$$;

ALTER TABLE tokens
ALTER COLUMN fecha_creacion TYPE TIMESTAMPTZ
USING fecha_creacion AT TIME ZONE 'UTC';

ALTER TABLE tokens
ALTER COLUMN fecha_expiracion TYPE TIMESTAMPTZ
USING fecha_expiracion AT TIME ZONE 'UTC';