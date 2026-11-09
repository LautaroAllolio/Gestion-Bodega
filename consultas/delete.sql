/* ============================================================
   consultas/delete.sql
   TPI Bases de Datos - Bodegas del Atuel
   Etapa 5 - Borrado de datos (D1 a D6)

   Cada consigna se resuelve dentro de BEGIN ... ROLLBACK para no
   alterar el dataset. Los controles previos y posteriores permiten
   ver el estado de las filas y el tag "DELETE n" de psql informa
   cuantas filas se borraron.

   Valores concretos tomados de db/dump_completo.sql.gz:
     - D1: comprobantes de socios anteriores a 2021-11-08
     - D2: cepas sin uso en VinoCepa y sin uso en Parcela
     - D3: localidad Lujan de Cuyo (id_localidad = 4), sala 4
     - D4: socios sin compras con alta anterior a 2021-11-08
     - D5: ingresos procesados anteriores a 2025-11-08
     - D6: socios sin compras de San Rafael (id_localidad = 1)

   Las fechas se calculan con CURRENT_DATE, tal como pide la
   consigna. Los conteos indicados son los esperados al 2026-11-08.
   ============================================================ */


/* ============================================================
   D1 - Borrar los comprobantes con mas de 5 anios de antiguedad
        asociados a clientes socios del club.
   Estrategia: identificar los comprobantes en una tabla temporal
   y borrarlos por PK. DetalleVenta se elimina por ON DELETE CASCADE.
   ============================================================ */

BEGIN;

-- Guardar los comprobantes objetivo para los controles
DROP TABLE IF EXISTS tmp_d1;
CREATE TEMP TABLE tmp_d1 (nro_comprobante integer) ON COMMIT DROP;

INSERT INTO tmp_d1 (nro_comprobante)
SELECT cv.nro_comprobante
  FROM ComprobanteVenta cv
  JOIN SocioClub sc ON sc.id_cliente = cv.id_cliente
 WHERE cv.fecha < CURRENT_DATE - INTERVAL '5 years';

-- Control previo: comprobantes y renglones que se van a borrar
SELECT COUNT(*)                    AS comprobantes_a_borrar,
       COUNT(DISTINCT cv.id_cliente) AS clientes_socios,
       ROUND(SUM(cv.total), 2)     AS importe_total,
       MIN(cv.fecha)               AS fecha_min,
       MAX(cv.fecha)               AS fecha_max
  FROM ComprobanteVenta cv
  JOIN tmp_d1 t ON t.nro_comprobante = cv.nro_comprobante;

SELECT COUNT(*) AS renglones_a_borrar
  FROM DetalleVenta dv
  JOIN tmp_d1 t ON t.nro_comprobante = dv.nro_comprobante;

-- DML: el borrado de la cabecera arrastra DetalleVenta por CASCADE
DELETE FROM ComprobanteVenta cv
USING tmp_d1 t
WHERE cv.nro_comprobante = t.nro_comprobante;

-- Control posterior: no deben quedar cabeceras ni renglones objetivo
SELECT COUNT(*) AS comprobantes_restantes
  FROM ComprobanteVenta cv
  JOIN tmp_d1 t ON t.nro_comprobante = cv.nro_comprobante;

SELECT COUNT(*) AS renglones_restantes
  FROM DetalleVenta dv
  JOIN tmp_d1 t ON t.nro_comprobante = dv.nro_comprobante;

SELECT COUNT(*) AS comprobantes_totales FROM ComprobanteVenta;
SELECT COUNT(*) AS renglones_totales   FROM DetalleVenta;

ROLLBACK;


/* ============================================================
   D2 - Eliminar las cepas que no componen ningun vino ni estan
        plantadas en ninguna parcela.
   Estrategia: NOT EXISTS sobre VinoCepa y Parcela.
   En este dataset las 12 cepas estan usadas en al menos una de
   las dos relaciones, por lo que el borrado afecta 0 filas.
   ============================================================ */

BEGIN;

-- Control previo: uso de cada cepa
SELECT c.id_cepa,
       c.nombre,
       c.tipo,
       (SELECT COUNT(*) FROM VinoCepa vc WHERE vc.id_cepa = c.id_cepa) AS vinos,
       (SELECT COUNT(*) FROM Parcela p  WHERE p.id_cepa  = c.id_cepa) AS parcelas,
       CASE
           WHEN NOT EXISTS (SELECT 1 FROM VinoCepa vc WHERE vc.id_cepa = c.id_cepa)
            AND NOT EXISTS (SELECT 1 FROM Parcela p  WHERE p.id_cepa  = c.id_cepa)
           THEN 'SI'
           ELSE 'NO'
       END AS borrable
  FROM Cepa c
 ORDER BY c.id_cepa;

-- DML
DELETE FROM Cepa c
 WHERE NOT EXISTS (SELECT 1 FROM VinoCepa vc WHERE vc.id_cepa = c.id_cepa)
   AND NOT EXISTS (SELECT 1 FROM Parcela p  WHERE p.id_cepa  = c.id_cepa);

-- Control posterior
SELECT COUNT(*) AS cepas_restantes FROM Cepa;

SELECT COUNT(*) AS cepas_borrables_restantes
  FROM Cepa c
 WHERE NOT EXISTS (SELECT 1 FROM VinoCepa vc WHERE vc.id_cepa = c.id_cepa)
   AND NOT EXISTS (SELECT 1 FROM Parcela p  WHERE p.id_cepa  = c.id_cepa);

ROLLBACK;


/* ============================================================
   D3 - La sala de una localidad determinada fue dada de baja:
        eliminar los empleados no encargados de esa sala que
        trabajaron menos de dos anios.
   Parametros: id_localidad = 4 (Lujan de Cuyo), id_sala = 4.
   Cambiar ambos valores para probar otra sala/localidad.
   Estrategia: fn_antiguedad_anios(fecha_ingreso) < 2.
   ============================================================ */

BEGIN;

-- Control previo: empleados de la sala y su antiguedad
SELECT e.cuit,
       e.nombre,
       e.fecha_ingreso,
       fn_antiguedad_anios(e.fecha_ingreso) AS antiguedad,
       e.id_sala,
       s.calle,
       s.id_localidad,
       l.nombre AS localidad,
       CASE
           WHEN fn_antiguedad_anios(e.fecha_ingreso) < 2
            AND NOT EXISTS (
                  SELECT 1
                    FROM Localidad encargada
                   WHERE encargada.cuit_encargado = e.cuit
                )
           THEN 'SI'
           ELSE 'NO'
       END AS borrable
  FROM Empleado e
  JOIN SalaDeVenta s ON s.id_sala = e.id_sala
  JOIN Localidad l   ON l.id_localidad = s.id_localidad
 WHERE e.id_sala = 4
 ORDER BY e.fecha_ingreso, e.cuit;

-- DML
DELETE FROM Empleado e
USING SalaDeVenta s
WHERE e.id_sala = s.id_sala
  AND s.id_localidad = 4
  AND e.id_sala = 4
  AND fn_antiguedad_anios(e.fecha_ingreso) < 2
  AND NOT EXISTS (
        SELECT 1
          FROM Localidad l
         WHERE l.cuit_encargado = e.cuit
      );

-- Control posterior: no quedan empleados borrables con menos de 2 anios
SELECT COUNT(*) AS empleados_sala_4 FROM Empleado WHERE id_sala = 4;

SELECT COUNT(*) AS empleados_borrables_menos_2_restantes
  FROM Empleado e
  JOIN SalaDeVenta s ON s.id_sala = e.id_sala
 WHERE e.id_sala = 4
   AND s.id_localidad = 4
   AND fn_antiguedad_anios(e.fecha_ingreso) < 2
   AND NOT EXISTS (
         SELECT 1
           FROM Localidad l
          WHERE l.cuit_encargado = e.cuit
       );

-- Los encargados que cumplen el criterio de antiguedad se preservan por RN-02.
SELECT COUNT(DISTINCT e.cuit) AS encargados_preservados
  FROM Empleado e
  JOIN SalaDeVenta s ON s.id_sala = e.id_sala
 WHERE e.id_sala = 4
   AND s.id_localidad = 4
   AND fn_antiguedad_anios(e.fecha_ingreso) < 2
   AND EXISTS (
         SELECT 1
           FROM Localidad l
          WHERE l.cuit_encargado = e.cuit
       );

ROLLBACK;


/* ============================================================
   D4 - Borrar los clientes socios que nunca compraron y se dieron
        de alta hace mas de 5 anios.
   Estrategia: SocioClub + NOT EXISTS en ComprobanteVenta +
   fecha_alta < CURRENT_DATE - 5 years.
   SocioClub se elimina por ON DELETE CASCADE.
   ============================================================ */

BEGIN;

-- Guardar los clientes objetivo para los controles
DROP TABLE IF EXISTS tmp_d4;
CREATE TEMP TABLE tmp_d4 (id_cliente integer) ON COMMIT DROP;

INSERT INTO tmp_d4 (id_cliente)
SELECT c.id_cliente
  FROM Cliente c
  JOIN SocioClub sc ON sc.id_cliente = c.id_cliente
 WHERE c.tipo_cliente = 'Socio'
   AND c.fecha_alta < CURRENT_DATE - INTERVAL '5 years'
   AND NOT EXISTS (
       SELECT 1
         FROM ComprobanteVenta cv
        WHERE cv.id_cliente = c.id_cliente
   );

-- Control previo
SELECT COUNT(*) AS socios_a_borrar
  FROM tmp_d4;

SELECT COUNT(*) AS filas_socioclub_a_borrar
  FROM SocioClub sc
  JOIN tmp_d4 t ON t.id_cliente = sc.id_cliente;

SELECT c.id_cliente, c.apellido, c.nombre, c.fecha_alta, c.id_localidad
  FROM Cliente c
  JOIN tmp_d4 t ON t.id_cliente = c.id_cliente
 ORDER BY c.fecha_alta, c.id_cliente
 LIMIT 5;

-- DML: el borrado de Cliente arrastra SocioClub por CASCADE
DELETE FROM Cliente c
USING tmp_d4 t
WHERE c.id_cliente = t.id_cliente;

-- Control posterior
SELECT COUNT(*) AS clientes_restantes
  FROM Cliente c
  JOIN tmp_d4 t ON t.id_cliente = c.id_cliente;

SELECT COUNT(*) AS socioclub_restantes
  FROM SocioClub sc
  JOIN tmp_d4 t ON t.id_cliente = sc.id_cliente;

SELECT COUNT(*) AS comprobantes_de_esos_clientes
  FROM ComprobanteVenta cv
  JOIN tmp_d4 t ON t.id_cliente = cv.id_cliente;

SELECT COUNT(*) AS socios_totales FROM SocioClub;

ROLLBACK;


/* ============================================================
   D5 - Eliminar los ingresos en estado procesado de hace mas de
        365 dias.
   Estrategia: borrar la cabecera; DetalleIngreso se elimina por
   ON DELETE CASCADE. El trigger RN-12 permite el borrado en cascada
   porque la cabecera ya no existe cuando se borra el renglon.
   ============================================================ */

BEGIN;

-- Guardar los ingresos objetivo para los controles
DROP TABLE IF EXISTS tmp_d5;
CREATE TEMP TABLE tmp_d5 (id_ingreso integer) ON COMMIT DROP;

INSERT INTO tmp_d5 (id_ingreso)
SELECT i.id_ingreso
  FROM Ingreso i
 WHERE i.estado = 'procesado'
   AND i.fecha < CURRENT_DATE - INTERVAL '365 days';

-- Control previo
SELECT COUNT(*)                    AS ingresos_a_borrar,
       COUNT(DISTINCT i.id_transporte) AS transportistas,
       COUNT(DISTINCT i.cuit_bodega)   AS bodegas,
       MIN(i.fecha)                AS fecha_min,
       MAX(i.fecha)                AS fecha_max
  FROM Ingreso i
  JOIN tmp_d5 t ON t.id_ingreso = i.id_ingreso;

SELECT COUNT(*)                              AS renglones_a_borrar,
       COALESCE(SUM(di.cantidad_botellas), 0) AS botellas
  FROM DetalleIngreso di
  JOIN tmp_d5 t ON t.id_ingreso = di.id_ingreso;

-- DML: el borrado de la cabecera arrastra DetalleIngreso por CASCADE
DELETE FROM Ingreso i
USING tmp_d5 t
WHERE i.id_ingreso = t.id_ingreso;

-- Control posterior
SELECT COUNT(*) AS ingresos_restantes
  FROM Ingreso i
  JOIN tmp_d5 t ON t.id_ingreso = i.id_ingreso;

SELECT COUNT(*) AS renglones_restantes
  FROM DetalleIngreso di
  JOIN tmp_d5 t ON t.id_ingreso = di.id_ingreso;

SELECT COUNT(*) AS ingresos_totales FROM Ingreso;
SELECT COUNT(*) AS renglones_totales FROM DetalleIngreso;

ROLLBACK;


/* ============================================================
   D6 - Borrar los clientes socios sin compras que viven en una
        localidad especifica.
   Parametro: id_localidad = 1 (San Rafael).
   Cambiar el valor para probar otra localidad.
   Estrategia: SocioClub + NOT EXISTS en ComprobanteVenta.
   SocioClub se elimina por ON DELETE CASCADE.
   ============================================================ */

BEGIN;

-- Guardar los clientes objetivo para los controles
DROP TABLE IF EXISTS tmp_d6;
CREATE TEMP TABLE tmp_d6 (id_cliente integer) ON COMMIT DROP;

INSERT INTO tmp_d6 (id_cliente)
SELECT c.id_cliente
  FROM Cliente c
  JOIN SocioClub sc ON sc.id_cliente = c.id_cliente
 WHERE c.tipo_cliente = 'Socio'
   AND c.id_localidad = 1
   AND NOT EXISTS (
       SELECT 1
         FROM ComprobanteVenta cv
        WHERE cv.id_cliente = c.id_cliente
   );

-- Control previo
SELECT COUNT(*) AS socios_a_borrar
  FROM tmp_d6;

SELECT COUNT(*) AS filas_socioclub_a_borrar
  FROM SocioClub sc
  JOIN tmp_d6 t ON t.id_cliente = sc.id_cliente;

SELECT c.id_cliente, c.apellido, c.nombre, c.fecha_alta, c.id_localidad
  FROM Cliente c
  JOIN tmp_d6 t ON t.id_cliente = c.id_cliente
 ORDER BY c.id_cliente
 LIMIT 5;

-- DML: el borrado de Cliente arrastra SocioClub por CASCADE
DELETE FROM Cliente c
USING tmp_d6 t
WHERE c.id_cliente = t.id_cliente;

-- Control posterior
SELECT COUNT(*) AS clientes_restantes
  FROM Cliente c
  JOIN tmp_d6 t ON t.id_cliente = c.id_cliente;

SELECT COUNT(*) AS socioclub_restantes
  FROM SocioClub sc
  JOIN tmp_d6 t ON t.id_cliente = sc.id_cliente;

SELECT COUNT(*) AS comprobantes_de_esos_clientes
  FROM ComprobanteVenta cv
  JOIN tmp_d6 t ON t.id_cliente = cv.id_cliente;

SELECT COUNT(*) AS socios_totales FROM SocioClub;

ROLLBACK;
