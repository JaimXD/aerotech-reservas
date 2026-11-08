--
-- PostgreSQL database dump
--

\restrict xhzQYT3nyo29cPgkbpL8rbtJWIPJiHY1cLfDM1Kx4NCXZU524yVQZaCiFL62qiG

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
-- Data for Name: vuelos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (1, 'AeroAndes', 'Quito', 'Guayaquil', '2026-06-10', '08:00:00', '09:00:00', 85.00, 20, true, 1, '2026-06-10');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (2, 'AeroAndes', 'Quito', 'Cuenca', '2026-06-10', '10:30:00', '11:30:00', 95.00, 15, true, 1, '2026-06-10');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (3, 'SkyEcuador', 'Guayaquil', 'Quito', '2026-06-11', '14:00:00', '15:00:00', 80.00, 25, true, 1, '2026-06-11');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (4, 'Condor Air', 'Manta', 'Quito', '2026-06-12', '07:00:00', '08:10:00', 110.00, 10, true, 1, '2026-06-12');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (5, 'Amazonía Air', 'Quito', 'Coca', '2026-06-13', '06:30:00', '07:20:00', 120.00, 8, true, 1, '2026-06-13');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (6, 'Latam Ecuador', 'Quito', 'Loja', '2026-06-14', '09:15:00', '10:20:00', 130.00, 12, true, 1, '2026-06-14');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (7, 'Avianca Ecuador', 'Guayaquil', 'Cuenca', '2026-06-15', '16:00:00', '17:00:00', 90.00, 18, true, 1, '2026-06-15');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (36, 'AeroAndes', 'Quito', 'Cuenca', '2026-11-06', '10:30:00', '11:30:00', 95.00, 15, true, 1, '2026-11-06');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (38, 'SkyEcuador', 'Guayaquil', 'Quito', '2026-11-07', '14:00:00', '15:00:00', 80.00, 25, true, 1, '2026-11-07');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (39, 'Amazonia Air', 'Quito', 'Coca', '2026-11-09', '06:30:00', '07:20:00', 120.00, 8, true, 1, '2026-11-09');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (40, 'Condor Air', 'Manta', 'Quito', '2026-11-08', '07:00:00', '08:10:00', 110.00, 10, true, 1, '2026-11-08');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (41, 'Avianca Ecuador', 'Guayaquil', 'Cuenca', '2026-11-11', '16:00:00', '17:00:00', 90.00, 18, true, 1, '2026-11-11');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (42, 'Latam Ecuador', 'Quito', 'Loja', '2026-11-10', '09:15:00', '10:20:00', 130.00, 12, true, 1, '2026-11-10');
INSERT INTO public.vuelos (id, aerolinea, origen, destino, fecha, hora_salida, hora_llegada, precio, asientos_disponibles, estado, version, fecha_llegada) VALUES (37, 'AeroAndes', 'Quito', 'Guayaquil', '2026-11-05', '08:00:00', '09:00:00', 85.00, 16, true, 3, '2026-11-05');


--
-- Data for Name: asientos_vuelo; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (1, 1, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (2, 1, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (3, 1, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (4, 1, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (5, 1, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (6, 1, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (7, 1, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (8, 1, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (9, 1, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (10, 1, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (11, 1, '3C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (12, 1, '3D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (13, 1, '4A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (14, 1, '4B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (15, 1, '4C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (16, 1, '4D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (17, 1, '5A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (18, 1, '5B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (19, 1, '5C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (20, 1, '5D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (21, 2, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (22, 2, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (23, 2, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (24, 2, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (25, 2, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (26, 2, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (27, 2, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (28, 2, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (29, 2, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (30, 2, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (31, 2, '3C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (32, 2, '3D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (33, 2, '4A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (34, 2, '4B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (35, 2, '4C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (36, 3, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (37, 3, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (38, 3, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (39, 3, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (40, 3, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (41, 3, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (42, 3, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (43, 3, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (44, 3, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (45, 3, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (46, 3, '3C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (47, 3, '3D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (48, 3, '4A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (49, 3, '4B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (50, 3, '4C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (51, 3, '4D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (52, 3, '5A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (53, 3, '5B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (54, 3, '5C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (55, 3, '5D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (56, 3, '6A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (57, 3, '6B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (58, 3, '6C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (59, 3, '6D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (60, 3, '7A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (61, 4, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (62, 4, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (63, 4, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (64, 4, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (65, 4, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (66, 4, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (67, 4, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (68, 4, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (69, 4, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (70, 4, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (71, 5, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (72, 5, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (73, 5, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (74, 5, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (75, 5, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (76, 5, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (77, 5, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (78, 5, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (79, 6, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (80, 6, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (81, 6, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (82, 6, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (83, 6, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (84, 6, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (85, 6, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (86, 6, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (87, 6, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (88, 6, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (89, 6, '3C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (90, 6, '3D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (91, 7, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (92, 7, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (93, 7, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (94, 7, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (95, 7, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (96, 7, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (97, 7, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (98, 7, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (99, 7, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (100, 7, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (101, 7, '3C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (102, 7, '3D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (103, 7, '4A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (104, 7, '4B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (105, 7, '4C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (106, 7, '4D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (107, 7, '5A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (108, 7, '5B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (109, 36, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (110, 36, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (111, 36, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (112, 36, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (113, 36, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (114, 36, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (115, 36, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (116, 36, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (117, 36, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (118, 36, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (119, 36, '3C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (120, 36, '3D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (121, 36, '4A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (122, 36, '4B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (123, 36, '4C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (124, 37, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (125, 37, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (130, 37, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (131, 37, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (132, 37, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (133, 37, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (134, 37, '3C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (135, 37, '3D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (136, 37, '4A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (129, 37, '2B', 'RESERVADO', 2);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (137, 37, '4B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (138, 37, '4C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (139, 37, '4D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (140, 37, '5A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (141, 37, '5B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (142, 37, '5C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (143, 37, '5D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (144, 38, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (145, 38, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (146, 38, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (147, 38, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (148, 38, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (149, 38, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (150, 38, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (151, 38, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (152, 38, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (153, 38, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (154, 38, '3C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (155, 38, '3D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (156, 38, '4A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (157, 38, '4B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (158, 38, '4C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (159, 38, '4D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (160, 38, '5A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (161, 38, '5B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (162, 38, '5C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (163, 38, '5D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (164, 38, '6A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (165, 38, '6B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (166, 38, '6C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (167, 38, '6D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (168, 38, '7A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (169, 39, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (170, 39, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (171, 39, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (172, 39, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (173, 39, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (174, 39, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (175, 39, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (176, 39, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (177, 40, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (178, 40, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (179, 40, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (180, 40, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (181, 40, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (182, 40, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (183, 40, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (184, 40, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (185, 40, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (186, 40, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (187, 41, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (188, 41, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (189, 41, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (190, 41, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (191, 41, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (192, 41, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (193, 41, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (194, 41, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (195, 41, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (196, 41, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (197, 41, '3C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (198, 41, '3D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (199, 41, '4A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (200, 41, '4B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (201, 41, '4C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (202, 41, '4D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (203, 41, '5A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (204, 41, '5B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (205, 42, '1A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (206, 42, '1B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (207, 42, '1C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (208, 42, '1D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (209, 42, '2A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (210, 42, '2B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (211, 42, '2C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (212, 42, '2D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (213, 42, '3A', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (214, 42, '3B', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (215, 42, '3C', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (216, 42, '3D', 'DISPONIBLE', NULL);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (126, 37, '1C', 'RESERVADO', 1);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (127, 37, '1D', 'RESERVADO', 1);
INSERT INTO public.asientos_vuelo (id, vuelo_id, numero_asiento, estado, reserva_id) VALUES (128, 37, '2A', 'RESERVADO', 1);


--
-- Name: asientos_vuelo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.asientos_vuelo_id_seq', 216, true);


--
-- Name: vuelos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vuelos_id_seq', 42, true);


--
-- PostgreSQL database dump complete
--

\unrestrict xhzQYT3nyo29cPgkbpL8rbtJWIPJiHY1cLfDM1Kx4NCXZU524yVQZaCiFL62qiG

