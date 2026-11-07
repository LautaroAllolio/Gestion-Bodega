/* ------------------------------------------------------------ */
/* 007_roles.sql - TPI Bases de Datos, Bodegas del Atuel        */
/* Roles y privilegios - Etapa 2                                */
/* Ejecutar después de 006_vistas.sql (PostgreSQL 14+)          */
/* ------------------------------------------------------------ */

/* Roles:
 *   bodega_propietario -> administración y objetos de la base.
 *   bodega_api         -> lectura/escritura para la API.
 *   bodega_lectura     -> solo lectura para reportes.
 *
 * Las contraseñas NO se guardan en el repositorio. En el despliegue
 * se asignan con ALTER ROLE ... PASSWORD usando variables de entorno.
 */

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bodega_propietario') THEN
        EXECUTE 'CREATE ROLE bodega_propietario LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bodega_api') THEN
        EXECUTE 'CREATE ROLE bodega_api LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bodega_lectura') THEN
        EXECUTE 'CREATE ROLE bodega_lectura LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION';
    END IF;
END
$$;

ALTER ROLE bodega_propietario WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
ALTER ROLE bodega_api         WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
ALTER ROLE bodega_lectura     WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;


/* ------------------------------------------------------------ */
/* Quitar privilegios públicos                                  */
/* ------------------------------------------------------------ */

DO $$
BEGIN
    EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database());
    EXECUTE format(
        'GRANT CONNECT ON DATABASE %I TO bodega_propietario, bodega_api, bodega_lectura',
        current_database()
    );
    EXECUTE format(
        'GRANT CREATE, TEMPORARY ON DATABASE %I TO bodega_propietario',
        current_database()
    );
END
$$;

REVOKE ALL ON SCHEMA public FROM PUBLIC;

REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;


/* ------------------------------------------------------------ */
/* bodega_propietario: control total sobre los objetos          */
/* ------------------------------------------------------------ */

GRANT USAGE, CREATE ON SCHEMA public TO bodega_propietario;

GRANT ALL PRIVILEGES ON ALL TABLES     IN SCHEMA public TO bodega_propietario;
GRANT ALL PRIVILEGES ON ALL SEQUENCES  IN SCHEMA public TO bodega_propietario;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS  IN SCHEMA public TO bodega_propietario;
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA public TO bodega_propietario;


/* ------------------------------------------------------------ */
/* bodega_api: lectura/escritura para la API                    */
/* ------------------------------------------------------------ */

GRANT USAGE ON SCHEMA public TO bodega_api;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO bodega_api;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO bodega_api;
GRANT EXECUTE ON ALL FUNCTIONS  IN SCHEMA public TO bodega_api;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO bodega_api;


/* ------------------------------------------------------------ */
/* bodega_lectura: solo lectura para reportes                   */
/* ------------------------------------------------------------ */

GRANT USAGE ON SCHEMA public TO bodega_lectura;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO bodega_lectura;

GRANT EXECUTE ON FUNCTION fn_total_comprobante(integer) TO bodega_lectura;
GRANT EXECUTE ON FUNCTION fn_stock_sala(integer, character varying) TO bodega_lectura;
GRANT EXECUTE ON FUNCTION fn_descuento_cliente(integer) TO bodega_lectura;
GRANT EXECUTE ON FUNCTION fn_antiguedad_anios(date) TO bodega_lectura;
