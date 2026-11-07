/* ============================================================
   db/tests/verificacion_etapa3.sql
   Verificación de integridad de la carga masiva de la Etapa 3.

   Ejecutar con:
       psql -U postgres -d bodega_seed -v ON_ERROR_STOP=1 \
         -f db/tests/verificacion_etapa3.sql
   ============================================================ */

\set ON_ERROR_STOP on
\pset pager off
\pset format aligned

SET search_path TO public;

\echo '=== VERIFICACION ETAPA 3 ==='

CREATE TEMP VIEW verificacion_etapa3 AS
SELECT 'stockdeposito_negativo'::text AS control, count(*)::bigint AS resultado, 0::bigint AS esperado
  FROM stockdeposito
 WHERE cantidad < 0

UNION ALL
SELECT 'stocksala_negativo', count(*), 0
  FROM stocksala
 WHERE cantidad < 0

UNION ALL
SELECT 'detalleventa_subtotal_inconsistente', count(*), 0
  FROM detalleventa
 WHERE subtotal IS DISTINCT FROM
       ROUND(cantidad * precio_unitario * (1 - descuento_aplicado / 100), 2)

UNION ALL
SELECT 'comprobante_subtotal_inconsistente', count(*), 0
  FROM comprobanteventa c
  LEFT JOIN (
        SELECT nro_comprobante,
               ROUND(SUM(cantidad * precio_unitario), 2) AS bruto,
               ROUND(SUM(subtotal), 2) AS neto
          FROM detalleventa
         GROUP BY nro_comprobante
  ) d ON d.nro_comprobante = c.nro_comprobante
 WHERE c.subtotal IS DISTINCT FROM COALESCE(d.bruto, 0)

UNION ALL
SELECT 'comprobante_descuento_inconsistente', count(*), 0
  FROM comprobanteventa c
  LEFT JOIN (
        SELECT nro_comprobante,
               ROUND(SUM(cantidad * precio_unitario), 2) AS bruto,
               ROUND(SUM(subtotal), 2) AS neto
          FROM detalleventa
         GROUP BY nro_comprobante
  ) d ON d.nro_comprobante = c.nro_comprobante
 WHERE c.descuento IS DISTINCT FROM COALESCE(d.bruto, 0) - COALESCE(d.neto, 0)

UNION ALL
SELECT 'comprobante_total_inconsistente', count(*), 0
  FROM comprobanteventa c
  LEFT JOIN (
        SELECT nro_comprobante,
               ROUND(SUM(subtotal), 2) AS neto
          FROM detalleventa
         GROUP BY nro_comprobante
  ) d ON d.nro_comprobante = c.nro_comprobante
 WHERE c.total IS DISTINCT FROM COALESCE(d.neto, 0)

UNION ALL
SELECT 'comprobante_sin_detalle', count(*), 0
  FROM comprobanteventa c
 WHERE NOT EXISTS (
       SELECT 1 FROM detalleventa d
        WHERE d.nro_comprobante = c.nro_comprobante
 )

UNION ALL
SELECT 'vino_corte_distinto_100', count(*), 0
  FROM (
        SELECT v.codigo_vino
          FROM vino v
          LEFT JOIN vinocepa vc ON vc.codigo_vino = v.codigo_vino
         GROUP BY v.codigo_vino
        HAVING COALESCE(SUM(vc.porcentaje_corte), 0) <> 100
  ) x

UNION ALL
SELECT 'detalleventa_sin_comprobante', count(*), 0
  FROM detalleventa d
 WHERE NOT EXISTS (
       SELECT 1 FROM comprobanteventa c
        WHERE c.nro_comprobante = d.nro_comprobante
 )

UNION ALL
SELECT 'detalleventa_sin_vino', count(*), 0
  FROM detalleventa d
 WHERE NOT EXISTS (
       SELECT 1 FROM vino v
        WHERE v.codigo_vino = d.codigo_vino
 )

UNION ALL
SELECT 'detalleingreso_sin_ingreso', count(*), 0
  FROM detalleingreso d
 WHERE NOT EXISTS (
       SELECT 1 FROM ingreso i
        WHERE i.id_ingreso = d.id_ingreso
 )

UNION ALL
SELECT 'detalleingreso_sin_vino', count(*), 0
  FROM detalleingreso d
 WHERE NOT EXISTS (
       SELECT 1 FROM vino v
        WHERE v.codigo_vino = d.codigo_vino
 )

UNION ALL
SELECT 'detalletransferencia_sin_transferencia', count(*), 0
  FROM detalletransferencia d
 WHERE NOT EXISTS (
       SELECT 1 FROM transferencia t
        WHERE t.nro_transferencia = d.nro_transferencia
 )

UNION ALL
SELECT 'detalletransferencia_sin_vino', count(*), 0
  FROM detalletransferencia d
 WHERE NOT EXISTS (
       SELECT 1 FROM vino v
        WHERE v.codigo_vino = d.codigo_vino
 )

UNION ALL
SELECT 'loteuva_sin_parcela', count(*), 0
  FROM loteuva l
 WHERE NOT EXISTS (
       SELECT 1 FROM parcela p
        WHERE p.id_finca = l.id_finca
          AND p.nro_parcela = l.nro_parcela
 )

UNION ALL
SELECT 'cliente_sin_localidad', count(*), 0
  FROM cliente c
 WHERE NOT EXISTS (
       SELECT 1 FROM localidad l
        WHERE l.id_localidad = c.id_localidad
 )

UNION ALL
SELECT 'empleado_sin_sala', count(*), 0
  FROM empleado e
 WHERE NOT EXISTS (
       SELECT 1 FROM saladeventa s
        WHERE s.id_sala = e.id_sala
 )

UNION ALL
SELECT 'vino_sin_bodega', count(*), 0
  FROM vino v
 WHERE NOT EXISTS (
       SELECT 1 FROM bodega b
        WHERE b.cuit = v.cuit_bodega
 )

UNION ALL
SELECT 'permiso_sin_exportador', count(*), 0
  FROM permisoexportacion p
 WHERE NOT EXISTS (
       SELECT 1 FROM exportador e
        WHERE e.id_cliente = p.id_cliente
 )

UNION ALL
SELECT 'fks_no_validadas', count(*), 0
  FROM pg_constraint
 WHERE contype = 'f'
   AND NOT convalidated

UNION ALL
SELECT 'triggers_usuario_deshabilitados', count(*), 0
  FROM pg_trigger t
  JOIN pg_class c ON c.oid = t.tgrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE NOT t.tgisinternal
   AND t.tgenabled = 'D'
   AND n.nspname = current_schema()

UNION ALL
SELECT 'localidades_sin_encargado', count(*), 0
  FROM localidad
 WHERE cuit_encargado IS NULL;

SELECT control,
       resultado,
       esperado,
       CASE WHEN resultado = esperado THEN 'OK' ELSE 'FALLA' END AS estado
  FROM verificacion_etapa3
 ORDER BY control;

DO $$
DECLARE
    v_fallas bigint;
BEGIN
    SELECT count(*) INTO v_fallas
      FROM verificacion_etapa3
     WHERE resultado <> esperado;

    IF v_fallas > 0 THEN
        RAISE EXCEPTION 'Verificación falló: % controles con diferencias', v_fallas;
    END IF;
END
$$;

\echo 'Verificación OK: todos los controles en cero.'
