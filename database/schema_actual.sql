--
-- PostgreSQL database dump
--

\restrict NyYAn3l1WYcgqdUGYtZH4LZYxUmBfn2CBXhyEITcfgjxe55X6zyONuOGTS5vPu8

-- Dumped from database version 17.11
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: crear_reserva_asientos_segura(bigint, bigint, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crear_reserva_asientos_segura(p_usuario_id bigint, p_vuelo_id bigint, p_asientos text[]) RETURNS TABLE(reserva_id bigint, codigo_reserva character varying, total numeric, estado character varying)
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


--
-- Name: crear_reserva_segura(bigint, bigint, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crear_reserva_segura(p_usuario_id bigint, p_vuelo_id bigint, p_cantidad_asientos integer) RETURNS TABLE(reserva_id bigint, codigo_reserva character varying, total numeric, estado character varying)
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: asientos_vuelo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asientos_vuelo (
    id bigint NOT NULL,
    vuelo_id bigint NOT NULL,
    numero_asiento character varying(10) NOT NULL,
    estado character varying(20) DEFAULT 'DISPONIBLE'::character varying,
    reserva_id bigint
);


--
-- Name: asientos_vuelo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.asientos_vuelo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: asientos_vuelo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.asientos_vuelo_id_seq OWNED BY public.asientos_vuelo.id;


--
-- Name: reservas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservas (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    vuelo_id bigint NOT NULL,
    codigo_reserva character varying(50) NOT NULL,
    cantidad_asientos integer NOT NULL,
    total numeric(10,2) NOT NULL,
    estado character varying(20) DEFAULT 'ACTIVA'::character varying,
    fecha_reserva timestamp without time zone DEFAULT now()
);


--
-- Name: reservas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservas_id_seq OWNED BY public.reservas.id;


--
-- Name: tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tokens (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    token text NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT now(),
    fecha_expiracion timestamp with time zone NOT NULL,
    activo boolean DEFAULT true
);


--
-- Name: tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tokens_id_seq OWNED BY public.tokens.id;


--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuarios (
    id bigint NOT NULL,
    usuario character varying(50) NOT NULL,
    password_hash character varying(256) NOT NULL,
    nombre_completo character varying(100) NOT NULL,
    correo character varying(100) NOT NULL,
    cedula character varying(20) NOT NULL,
    estado boolean DEFAULT true,
    fecha_creacion timestamp without time zone DEFAULT now(),
    rol character varying(20) DEFAULT 'user'::character varying NOT NULL,
    correo_verificado boolean DEFAULT false NOT NULL
);


--
-- Name: usuarios_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usuarios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usuarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.usuarios_id_seq OWNED BY public.usuarios.id;


--
-- Name: verificaciones_correo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.verificaciones_correo (
    usuario_id bigint NOT NULL,
    codigo_hash character(64) NOT NULL,
    expira_en timestamp with time zone NOT NULL,
    intentos integer DEFAULT 0 NOT NULL,
    ultimo_envio timestamp with time zone DEFAULT now() NOT NULL,
    ventana_inicio timestamp with time zone DEFAULT now() NOT NULL,
    envios_en_ventana integer DEFAULT 1 NOT NULL,
    CONSTRAINT verificaciones_correo_envios_en_ventana_check CHECK ((envios_en_ventana >= 0)),
    CONSTRAINT verificaciones_correo_intentos_check CHECK (((intentos >= 0) AND (intentos <= 5)))
);


--
-- Name: vuelos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vuelos (
    id bigint NOT NULL,
    aerolinea character varying(100) NOT NULL,
    origen character varying(100) NOT NULL,
    destino character varying(100) NOT NULL,
    fecha date NOT NULL,
    hora_salida time without time zone NOT NULL,
    hora_llegada time without time zone NOT NULL,
    precio numeric(10,2) NOT NULL,
    asientos_disponibles integer NOT NULL,
    estado boolean DEFAULT true,
    version integer DEFAULT 1,
    fecha_llegada date NOT NULL
);


--
-- Name: vuelos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vuelos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vuelos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vuelos_id_seq OWNED BY public.vuelos.id;


--
-- Name: asientos_vuelo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asientos_vuelo ALTER COLUMN id SET DEFAULT nextval('public.asientos_vuelo_id_seq'::regclass);


--
-- Name: reservas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas ALTER COLUMN id SET DEFAULT nextval('public.reservas_id_seq'::regclass);


--
-- Name: tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens ALTER COLUMN id SET DEFAULT nextval('public.tokens_id_seq'::regclass);


--
-- Name: usuarios id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios ALTER COLUMN id SET DEFAULT nextval('public.usuarios_id_seq'::regclass);


--
-- Name: vuelos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vuelos ALTER COLUMN id SET DEFAULT nextval('public.vuelos_id_seq'::regclass);


--
-- Name: asientos_vuelo asientos_vuelo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asientos_vuelo
    ADD CONSTRAINT asientos_vuelo_pkey PRIMARY KEY (id);


--
-- Name: asientos_vuelo asientos_vuelo_vuelo_id_numero_asiento_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asientos_vuelo
    ADD CONSTRAINT asientos_vuelo_vuelo_id_numero_asiento_key UNIQUE (vuelo_id, numero_asiento);


--
-- Name: reservas reservas_codigo_reserva_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_codigo_reserva_key UNIQUE (codigo_reserva);


--
-- Name: reservas reservas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: usuarios usuarios_correo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_correo_key UNIQUE (correo);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: usuarios usuarios_usuario_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_usuario_key UNIQUE (usuario);


--
-- Name: verificaciones_correo verificaciones_correo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verificaciones_correo
    ADD CONSTRAINT verificaciones_correo_pkey PRIMARY KEY (usuario_id);


--
-- Name: vuelos vuelos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vuelos
    ADD CONSTRAINT vuelos_pkey PRIMARY KEY (id);


--
-- Name: asientos_vuelo asientos_vuelo_reserva_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asientos_vuelo
    ADD CONSTRAINT asientos_vuelo_reserva_id_fkey FOREIGN KEY (reserva_id) REFERENCES public.reservas(id);


--
-- Name: asientos_vuelo asientos_vuelo_vuelo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asientos_vuelo
    ADD CONSTRAINT asientos_vuelo_vuelo_id_fkey FOREIGN KEY (vuelo_id) REFERENCES public.vuelos(id);


--
-- Name: reservas reservas_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id);


--
-- Name: reservas reservas_vuelo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_vuelo_id_fkey FOREIGN KEY (vuelo_id) REFERENCES public.vuelos(id);


--
-- Name: tokens tokens_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: verificaciones_correo verificaciones_correo_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verificaciones_correo
    ADD CONSTRAINT verificaciones_correo_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: asientos_vuelo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.asientos_vuelo ENABLE ROW LEVEL SECURITY;

--
-- Name: reservas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reservas ENABLE ROW LEVEL SECURITY;

--
-- Name: tokens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

--
-- Name: verificaciones_correo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.verificaciones_correo ENABLE ROW LEVEL SECURITY;

--
-- Name: vuelos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vuelos ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict NyYAn3l1WYcgqdUGYtZH4LZYxUmBfn2CBXhyEITcfgjxe55X6zyONuOGTS5vPu8

