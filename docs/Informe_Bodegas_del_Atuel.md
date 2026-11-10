# Informe Técnico y Diccionario de Datos

## Sistema de Gestión y Distribución «Bodegas del Atuel»

| Dato | Detalle |
|---|---|
| Cátedra | Bases de Datos |
| Carrera | Ingeniería en Sistemas de Información |
| Facultad | UTN Facultad Regional San Rafael |
| Ciclo lectivo | 2026 |
| Motor de base de datos | PostgreSQL 14 o superior |
| Documento | Informe técnico consolidado y diccionario de datos |
| Alcance | Etapas 1 a 8 del Trabajo Práctico Integrador; Etapa 9 parcial |
| Fuente de verdad | Código SQL versionado en `db/migrations/` y `consultas/`; API en `api/`; front en `front/`; despliegue en `docker-compose.yml`; dataset reproducible en `db/seed/` |

> **Nota metodológica.** Este informe se deriva del código efectivamente presente en el repositorio. Cuando la narrativa de `docs/informe.md` difiere del SQL, prevalece el SQL. No se describen componentes que no estén implementados en el repositorio.

---

## 1. Introducción y alcance actual

### 1.1 Descripción del sistema

«Bodegas del Atuel» es una empresa vitivinícola ficticia que integra la producción de uva, la elaboración de vino y su distribución y venta a través de una red de salas de venta. El sistema modelado cubre:

- La organización geográfica y comercial: departamentos, localidades, salas de venta y empleados.
- La producción agrícola: fincas, parcelas, cepas, lotes de uva, campañas y análisis de calidad.
- La elaboración y el catálogo: bodegas, vinos, composición de cepas, maridajes y precios.
- La gestión de clientes: socios del club, distribuidores y exportadores, con sus permisos de exportación.
- La operación de ventas: comprobantes y renglones de venta con descuentos por tipo de cliente.
- La logística y el stock: transportistas, ingresos al depósito central, transferencias a las salas y stock por vino.
- La auditoría de cambios de precio.

El diseño persigue que las reglas de negocio vivan dentro de la base de datos y se cumplan con independencia de la aplicación que la utilice.

### 1.2 Estado del desarrollo según el repositorio

El repositorio contiene implementadas las Etapas 1 a 8 de la guía `docs/TPI_Bodegas_del_Atuel.md`. La Etapa 8 es un despliegue local con Docker Compose, no un despliegue en la nube. La Etapa 9 queda parcial: están la documentación y las pruebas, pero la demo en vivo y la defensa oral no forman parte del repositorio.

| Etapa de la guía | Estado | Evidencia en el repositorio |
|---|---|---|
| 1. Modelado | Implementada | `db/migrations/001_esquema.sql`, `002_constraints.sql`, DER y esquema relacional en `docs/` |
| 2. Integridad y lógica en la base | Implementada | `003_funciones.sql` a `007_roles.sql`; pruebas RN-01 a RN-15 en `db/tests/db_tests.sql` |
| 3. Carga masiva | Implementada | `db/seed/` con catálogos CSV, `load.py`, `README.md`, `benchmark_report.json` y `report_local.json`; `db/tests/verificacion_etapa3.sql`; volcado versionado |
| 4. Índices y rendimiento | Implementada | `db/migrations/008_indices.sql`; mediciones y planes documentados en `docs/informe.md` |
| 5. Consultas SQL | Implementada | `consultas/insert.sql`, `update.sql`, `delete.sql` y `select.sql`; consignas I1–I6, U1–U6, D1–D6 y S1–S12 |
| 6. API REST | Implementada | `api/` con FastAPI, routers, reportes, traducción de SQLSTATE y 17 pruebas |
| 7. Front | Implementada | `front/` con React, Vite, TypeScript, React Router y Recharts; cinco pantallas |
| 8. Despliegue | Parcial | `docker-compose.yml` con `db`, `db-init`, `api` y `front`; no hay despliegue en nube, backups operativos ni conexión cifrada de producción |
| 9. Documentación y defensa | Parcial | `docs/informe.md` como bitácora por etapas, `docs/capturas/` como evidencia y este documento consolidado; la demo en vivo no está en el repositorio |

**Verificación del alcance.** Se revisaron `db/migrations/001_esquema.sql` a `008_indices.sql`, `db/tests/`, `db/seed/`, `consultas/`, `api/`, `front/`, `tests/` y `docker-compose.yml`. La Etapa 4 tiene índices y mediciones; la Etapa 6 tiene API y pruebas; la Etapa 7 tiene front compilable y servido por Nginx; la Etapa 8 tiene un stack local reproducible. No se encontró un despliegue en nube.

### 1.3 Componentes cubiertos en este entregable

| Componente | Cantidad | Artefacto principal |
|---|---:|---|
| Tablas | 31 | `db/migrations/001_esquema.sql` |
| Tipos enumerados | 1 | `estado_documento` |
| Dominios | 1 | `cuit_dom` |
| Funciones | 4 | `db/migrations/003_funciones.sql` |
| Procedimientos almacenados | 2 | `db/migrations/004_procedimientos.sql` |
| Triggers | 11 | `db/migrations/005_triggers.sql` |
| Vistas | 3 | `db/migrations/006_vistas.sql` |
| Roles | 3 | `db/migrations/007_roles.sql` |
| Consultas SQL resueltas | 30 (I1–I6, U1–U6, D1–D6, S1–S12) | `consultas/` |
| Reglas de negocio probadas | 15 (RN-01 a RN-15) | `db/tests/db_tests.sql` |
| Controles del cargador | 15 | `db/seed/report_local.json`, `load.py` |
| Controles independientes de carga | 22 | `db/tests/verificacion_etapa3.sql` |
| Estrategias de carga comparadas | 3 (`copy`, `executemany`, `individual`) | `db/seed/benchmark_report.json` |
| Filas cargadas (escala 1.0) | 745.569 | `db/seed/README.md`, `report_local.json` |
| Pruebas automatizadas de API | 17 | `tests/test_api.py` |
| Pantallas del front | 5 | `front/src/pages/` |
| Servicios de Docker Compose | 4 (`db`, `db-init`, `api`, `front`) | `docker-compose.yml` |

La Etapa 3 se documenta en la sección 5 con el nivel de detalle que pide la guía: catálogos reales del Anexo B, generador reproducible con semilla fija `20261101`, orden topológico de carga, tratamiento de triggers, comparación de estrategias de inserción, tiempos, consultas de control y volcado versionado. La Etapa 5 se documenta en la sección 6, porque sus cuatro archivos de consultas forman parte del entregable y permiten verificar el comportamiento del modelo y de las reglas sobre el dataset cargado. La Etapa 7 se documenta en la sección 7, con la arquitectura del front, sus pantallas y la verificación de integración.

### 1.4 Alcance excluido

Quedan fuera del alcance los siguientes aspectos, que no están implementados en el repositorio:

- El despliegue en la nube, la conexión cifrada, los backups operativos y la restauración en producción. El `docker-compose.yml` es un despliegue local.
- La demo en vivo y la defensa oral.

La autenticación de usuarios tampoco forma parte del front: la API se consume sin login y las credenciales se resuelven por variables de entorno del contenedor. Las observaciones sobre diferencias o límites del esquema se presentan en la sección 4.8 y reflejan el estado real del código.

### 1.5 Fuentes y criterio de verdad

| Fuente | Uso en este informe |
|---|---|
| `db/migrations/001_esquema.sql` | Tablas, columnas, tipos, claves primarias y foráneas base |
| `db/migrations/002_constraints.sql` | `UNIQUE`, `CHECK`, `DEFAULT` y acciones referenciales |
| `db/migrations/003_funciones.sql` | Funciones de cálculo y consulta |
| `db/migrations/004_procedimientos.sql` | Procedimientos transaccionales |
| `db/migrations/005_triggers.sql` | Triggers de integridad, auditoría y estados |
| `db/migrations/006_vistas.sql` | Vistas de reporte |
| `db/migrations/007_roles.sql` | Roles y privilegios |
| `db/tests/db_tests.sql` | Casos de prueba de RN-01 a RN-15 |
| `db/tests/verificacion_etapa3.sql` | 22 controles posteriores a la carga masiva |
| `consultas/insert.sql`, `update.sql`, `delete.sql`, `select.sql` | Consignas DML y DQL de la Etapa 5 |
| `docs/capturas/` | Evidencia de configuración, carga, verificación y concurrencia |
| `docs/informe.md` | Contexto de decisiones y bitácora por etapa |
| `db/seed/README.md` | Catálogos, volúmenes, reproducibilidad, triggers y estrategia de carga |
| `db/seed/load.py`, `db/seed/requirements.txt` | Generador, CLI, validaciones y dependencias de la carga |
| `db/seed/report_local.json` | Conteos, tiempos y 15 controles de la corrida local real |
| `db/seed/benchmark_report.json` | Comparación de `copy`, `executemany` e `individual` por tabla |
| `db/dump_completo.sql.gz` | Volcado completo de la base cargada (con salvedad de la sección 5.7) |
| `api/` | API REST, acceso a datos, routers, reportes y pruebas de integración |
| `front/` | SPA React, capa de API, componentes y cinco pantallas |
| `tests/test_api.py` | 17 pruebas automatizadas de la API |
| `docker-compose.yml`, `front/Dockerfile`, `front/nginx.conf` | Stack local y publicación del front |
| `README.md` | Puesta en marcha, migraciones, carga, pruebas, front, volcado y restauración |

---

## 2. Modelo Entidad-Relación y esquema relacional

### 2.1 Visión general

El modelo se organiza en siete dominios funcionales:

1. **Geografía y red comercial:** `Departamento`, `Localidad`, `SalaDeVenta`, `Empleado`.
2. **Producción agrícola:** `Finca`, `Parcela`, `Cepa`, `LoteUva`, `AnalisisCalidad`.
3. **Elaboración y catálogo:** `Bodega`, `Vino`, `VinoCepa`, `Maridaje`, `VinoMaridaje`.
4. **Clientes:** `Cliente`, `SocioClub`, `Distribuidor`, `Exportador`, `PermisoExportacion`.
5. **Ventas:** `ComprobanteVenta`, `DetalleVenta`.
6. **Logística y stock:** `Transportista`, `TransportistaLocalidad`, `DepositoCentral`, `Ingreso`, `DetalleIngreso`, `Transferencia`, `DetalleTransferencia`, `StockDeposito`, `StockSala`.
7. **Auditoría:** `AuditoriaPrecio`.

![DER de Bodegas del Atuel](Diagrama%20DER/DER_BODEGA_2.0.drawio.png)

El DER editable se encuentra en `docs/Diagrama DER/DER_BODEGA_2.0.drawio`; el esquema relacional, en `docs/Diagrama Relacional/`.

### 2.2 Relaciones y cardinalidades principales

| Relación | Cardinalidad | Implementación relacional |
|---|---|---|
| Departamento — Localidad | 1:N lógica | `Localidad` no tiene FK a `Departamento`; la relación se usa en `Finca` y como referencia geográfica |
| Departamento — Finca | 1:N | `Finca.id_departamento → Departamento.id_departamento` |
| Localidad — SalaDeVenta | 1:N | `SalaDeVenta.id_localidad → Localidad.id_localidad`, `NOT NULL` |
| Localidad — Empleado encargado | 1:1 lógica | `Localidad.cuit_encargado → Empleado.cuit`, nullable; dependencia circular resuelta con `SET NULL` |
| SalaDeVenta — Empleado | 1:N | `Empleado.id_sala → SalaDeVenta.id_sala`, `NOT NULL` |
| Finca — Parcela | 1:N | Entidad débil; PK compuesta `(nro_parcela, id_finca)` y FK a `Finca` |
| Cepa — Parcela | 1:N | `Parcela.id_cepa → Cepa.id_cepa` |
| Parcela — LoteUva | 1:N | FK compuesta `(nro_parcela, id_finca)`; `UNIQUE (id_finca, nro_parcela, campania)` limita a una cosecha por campaña |
| LoteUva — AnalisisCalidad | 1:N | `AnalisisCalidad.id_lote → LoteUva.id_lote` |
| Bodega — LoteUva | 1:N | `LoteUva.cuit_bodega → Bodega.cuit` |
| Bodega — Vino | 1:N | `Vino.cuit_bodega → Bodega.cuit` |
| Bodega — Ingreso | 1:N | `Ingreso.cuit_bodega → Bodega.cuit` |
| Vino — Cepa | N:M con atributo | `VinoCepa(codigo_vino, id_cepa, porcentaje_corte)` |
| Vino — Maridaje | N:M | `VinoMaridaje(codigo_vino, id_maridaje)` |
| Cliente — ComprobanteVenta | 1:N | `ComprobanteVenta.id_cliente → Cliente.id_cliente` |
| SalaDeVenta — ComprobanteVenta | 1:N | `ComprobanteVenta.id_sala → SalaDeVenta.id_sala` |
| ComprobanteVenta — DetalleVenta | 1:N | Renglón débil; PK `(nro_comprobante, codigo_vino)` |
| Vino — DetalleVenta | 1:N | `DetalleVenta.codigo_vino → Vino.codigo_vino` |
| Exportador — PermisoExportacion | 1:N | `PermisoExportacion.id_cliente → Exportador.id_cliente` |
| Transportista — Localidad | N:M | `TransportistaLocalidad(id_transporte, id_localidad)` |
| Transportista — Ingreso | 1:N | `Ingreso.id_transporte → Transportista.id_transporte` |
| DepositoCentral — Ingreso | 1:N | `Ingreso.id_deposito → DepositoCentral.id_deposito` |
| Ingreso — DetalleIngreso | 1:N | Renglón débil; PK `(id_ingreso, codigo_vino)` |
| SalaDeVenta — Transferencia | 1:N | `Transferencia.id_sala_solicitante → SalaDeVenta.id_sala` |
| DepositoCentral — Transferencia | 1:N | `Transferencia.id_deposito → DepositoCentral.id_deposito` |
| Transferencia — DetalleTransferencia | 1:N | Renglón débil; PK `(nro_transferencia, codigo_vino)` |
| Vino — StockDeposito | 1:N | PK `(id_deposito, codigo_vino)` |
| Vino — StockSala | 1:N | PK `(id_sala, codigo_vino)` |
| Vino — AuditoriaPrecio | 1:N | `AuditoriaPrecio.codigo_vino → Vino.codigo_vino` |

### 2.3 Resolución de relaciones N:M

| Relación N:M | Tabla intermedia | Clave primaria | Atributos propios |
|---|---|---|---|
| Vino — Cepa | `VinoCepa` | `(codigo_vino, id_cepa)` | `porcentaje_corte` |
| Vino — Maridaje | `VinoMaridaje` | `(codigo_vino, id_maridaje)` | Ninguno |
| Transportista — Localidad | `TransportistaLocalidad` | `(id_transporte, id_localidad)` | Ninguno |
| Comprobante — Vino | `DetalleVenta` | `(nro_comprobante, codigo_vino)` | `cantidad`, `precio_unitario`, `descuento_aplicado`, `subtotal` |
| Ingreso — Vino | `DetalleIngreso` | `(id_ingreso, codigo_vino)` | `cantidad_botellas` |
| Transferencia — Vino | `DetalleTransferencia` | `(nro_transferencia, codigo_vino)` | `cantidad` |
| Sala — Vino | `StockSala` | `(id_sala, codigo_vino)` | `cantidad` |
| Depósito — Vino | `StockDeposito` | `(id_deposito, codigo_vino)` | `cantidad` |

Los renglones de comprobante, ingreso y transferencia se modelan como relaciones débiles de su cabecera: no existen sin ella y su clave incorpora la clave del documento. `StockSala` y `StockDeposito` son relaciones asociativas con atributo `cantidad`, no entidades independientes.

### 2.4 Entidad débil Parcela

`Parcela` no existe sin su finca. Su clave primaria es compuesta:

```text
PK_Parcela = (nro_parcela, id_finca)
```

El número de parcela solo es único dentro de la finca. La FK `id_finca → Finca(id_finca)` es `ON DELETE CASCADE`: al eliminar una finca se eliminan sus parcelas. Sin embargo, `LoteUva` referencia a `Parcela` con `ON DELETE NO ACTION`, por lo que una finca con lotes de uva asociados no puede eliminarse mientras existan esos lotes.

### 2.5 Jerarquía de Cliente

La jerarquía se resolvió con **supertipo más subtipos**:

```text
Cliente (id_cliente)
├── SocioClub      (id_cliente PK/FK, numero_socio UNIQUE)
├── Distribuidor   (id_cliente PK/FK, zona_cobertura, nro_habilitacion)
└── Exportador     (id_cliente PK/FK, pais_destino_principal)
                     └── PermisoExportacion (id_permiso, id_cliente FK)
```

El supertipo `Cliente` concentra los datos comunes: apellido, nombre, CUIT, tipo y número de documento, dirección, localidad, fecha de alta y descuento. Cada subtipo agrega solo sus atributos propios y comparte la clave primaria con el supertipo. El borrado de un cliente arrastra sus subtipos y, en el caso de un exportador, sus permisos, mediante `ON DELETE CASCADE`.

La columna `Cliente.tipo_cliente` se valida con `CHECK (tipo_cliente IN ('Socio', 'Distribuidor', 'Exportador'))`, pero el esquema no impone por sí mismo que exista exactamente un subtipo coincidente. Esa correspondencia se controla en la carga y en la lógica de aplicación; se documenta como límite en la sección 4.8.

### 2.6 Normalización hasta tercera forma normal

El esquema se contrastó contra las tres primeras formas normales. No se detectaron grupos repetidos ni dependencias parciales o transitivas que obliguen a dividir tablas; las únicas redundancias son atributos derivados persistidos de forma controlada, que se justifican en la sección 4.3.

| Forma normal | Criterio | Verificación en el esquema |
|---|---|---|
| 1FN | Valores atómicos, sin grupos repetidos | Todas las columnas son escalares. Los renglones de comprobante, ingreso y transferencia se modelan como tablas propias, no como listas dentro de la cabecera. `cuit_dom` es un valor atómico validado por dominio. |
| 2FN | Ningún atributo no clave depende de parte de una clave compuesta | En `DetalleVenta`, `cantidad`, `precio_unitario`, `descuento_aplicado` y `subtotal` dependen de la pareja `(nro_comprobante, codigo_vino)`. Lo mismo ocurre en `DetalleIngreso`, `DetalleTransferencia`, `VinoCepa` (`porcentaje_corte`), `StockSala`, `StockDeposito`, `Parcela` y `TransportistaLocalidad`. |
| 3FN | Ningún atributo no clave depende de otro atributo no clave | Los datos de localidad, departamento, bodega, cliente, sala y vino se separaron en sus propias tablas. `Finca` referencia `Departamento`; `Vino` referencia `Bodega`; `ComprobanteVenta` referencia `Cliente` y `SalaDeVenta`; `DetalleVenta` referencia `Vino` y no repite nombre, añada ni graduación. |

**Excepciones deliberadas.** `ComprobanteVenta.subtotal`, `ComprobanteVenta.descuento`, `ComprobanteVenta.total`, `DetalleVenta.subtotal`, `StockDeposito.cantidad` y `StockSala.cantidad` son atributos derivados que se persisten por valor histórico u operativo. No son una desnormalización descontrolada: se calculan y mantienen con funciones, triggers y procedimientos (sección 4.3), y `verificacion_etapa3.sql` comprueba que coincidan con sus fuentes.

**Límite conocido.** La jerarquía de clientes está normalizada por supertipo y subtipos, pero el esquema no impone que `Cliente.tipo_cliente` coincida con el subtipo existente. Esa dependencia semántica se controla en la carga y en la aplicación, y se documenta en las secciones 2.5 y 4.8.

### 2.7 Nombres físicos en PostgreSQL

PostgreSQL pliega a minúsculas los identificadores no citados. Por lo tanto, los nombres físicos de las tablas son:

`analisiscalidad`, `auditoriaprecio`, `bodega`, `cepa`, `cliente`, `comprobanteventa`, `departamento`, `depositocentral`, `detalleingreso`, `detalletransferencia`, `detalleventa`, `distribuidor`, `empleado`, `exportador`, `finca`, `ingreso`, `localidad`, `loteuva`, `maridaje`, `parcela`, `permisoexportacion`, `saladeventa`, `socioclub`, `stockdeposito`, `stocksala`, `transferencia`, `transportista`, `transportistalocalidad`, `vino`, `vinocepa`, `vinomaridaje`.

En el diccionario se indica el nombre lógico y, entre paréntesis, el nombre físico.

---

## 3. Diccionario de datos

### 3.1 Convenciones

- **Columna:** nombre físico del campo.
- **Tipo de dato:** tipo declarado en PostgreSQL. `SERIAL` implica `INTEGER` con secuencia y `NOT NULL`.
- **Restricciones:** `PK`, `FK`, `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT` y acciones `ON DELETE` / `ON UPDATE` cuando corresponden.
- **Descripción:** significado de negocio del campo.
- `cuit_dom` es un dominio definido como `VARCHAR(11)` con `CHECK (VALUE ~ '^[0-9]{11}$')`.
- `estado_documento` es un tipo enumerado con los valores `en_confeccion`, `terminado` y `procesado`.
- Los importes se almacenan con `NUMERIC(p,s)`, nunca con `FLOAT`.

### 3.2 Tipos propios

| Tipo | Definición | Uso |
|---|---|---|
| `estado_documento` | `ENUM ('en_confeccion', 'terminado', 'procesado')` | `Ingreso.estado`, `Transferencia.estado` |
| `cuit_dom` | `VARCHAR(11)` con `CHECK (VALUE ~ '^[0-9]{11}$')` | `Bodega.cuit`, `Empleado.cuit`, `Cliente.cuit`, `Transportista.cuit`, `Ingreso.cuit_bodega`, `LoteUva.cuit_bodega`, `Vino.cuit_bodega`, `Localidad.cuit_encargado` |

### 3.3 Geografía y red comercial

#### 3.3.1 Departamento (`departamento`)

Departamentos de Mendoza usados para ubicar fincas.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_departamento` | `INTEGER` | `PK`, `NOT NULL` | Identificador del departamento. |
| `nombre` | `VARCHAR(50)` | `NOT NULL` | Nombre del departamento. |
| `provincia` | `VARCHAR(50)` | `NOT NULL` | Provincia a la que pertenece el departamento. |

#### 3.3.2 Localidad (`localidad`)

Localidades donde se ubican las salas y los clientes.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_localidad` | `SERIAL` | `PK`, `NOT NULL` | Identificador interno de la localidad. |
| `nombre` | `VARCHAR(50)` | `NOT NULL` | Nombre de la localidad. |
| `provincia` | `VARCHAR(50)` | `NOT NULL` | Provincia de la localidad. |
| `codigo_postal` | `VARCHAR(50)` | `NOT NULL` | Código postal. |
| `cuit_encargado` | `cuit_dom` | `NULL`, `FK → Empleado(cuit)` `ON DELETE SET NULL` `ON UPDATE CASCADE` | CUIT del empleado encargado regional de la localidad. |

**Restricciones de tabla:** `UNIQUE (nombre, provincia)` como clave candidata natural.

#### 3.3.3 SalaDeVenta (`saladeventa`)

Salas de venta de la red comercial.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_sala` | `SERIAL` | `PK`, `NOT NULL` | Identificador de la sala. |
| `calle` | `VARCHAR(50)` | `NOT NULL` | Calle de la dirección de la sala. |
| `dia_cierre` | `VARCHAR(50)` | `NOT NULL`, `CHECK (dia_cierre IN ('Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo','Ninguno'))` | Día de cierre semanal. |
| `id_localidad` | `INTEGER` | `NOT NULL`, `FK → Localidad(id_localidad)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Localidad donde se ubica la sala. |
| `numero_calle` | `INTEGER` | `NOT NULL` | Número de la dirección. |

#### 3.3.4 Empleado (`empleado`)

Empleados que trabajan en una sala.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `cuit` | `cuit_dom` | `PK`, `NOT NULL` | CUIT del empleado; clave natural. |
| `nombre` | `VARCHAR(50)` | `NOT NULL` | Nombre del empleado. |
| `fecha_ingreso` | `DATE` | `NOT NULL` | Fecha de ingreso laboral. |
| `salario` | `NUMERIC(12,2)` | `NOT NULL`, `CHECK (salario > 0)` | Salario del empleado. |
| `id_sala` | `INTEGER` | `NOT NULL`, `FK → SalaDeVenta(id_sala)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Sala en la que trabaja. |

### 3.4 Producción agrícola

#### 3.4.1 Finca (`finca`)

Fincas donde se cultiva la uva.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_finca` | `SERIAL` | `PK`, `NOT NULL` | Identificador de la finca. |
| `nombre` | `VARCHAR(50)` | `NOT NULL` | Nombre de la finca. |
| `superficie_total` | `NUMERIC(10,2)` | `NOT NULL`, `CHECK (superficie_total > 0)` | Superficie total en hectáreas. |
| `id_departamento` | `INTEGER` | `NOT NULL`, `FK → Departamento(id_departamento)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Departamento donde se ubica la finca. |

#### 3.4.2 Parcela (`parcela`)

Entidad débil de `Finca`. Cada parcela tiene una única cepa plantada.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `nro_parcela` | `INTEGER` | `PK` (compuesta), `NOT NULL` | Número de parcela dentro de la finca. |
| `id_finca` | `INTEGER` | `PK` (compuesta), `NOT NULL`, `FK → Finca(id_finca)` `ON DELETE CASCADE` `ON UPDATE NO ACTION` | Finca a la que pertenece la parcela. |
| `superficie` | `NUMERIC(10,2)` | `NOT NULL`, `CHECK (superficie > 0)` | Superficie de la parcela en hectáreas. |
| `anio_plantacion` | `INTEGER` | `NOT NULL`, `CHECK (anio_plantacion BETWEEN 1900 AND 2100)` | Año de plantación. |
| `id_cepa` | `INTEGER` | `NOT NULL`, `FK → Cepa(id_cepa)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Cepa plantada en la parcela. |

**Restricción de tabla:** `PK (nro_parcela, id_finca)`.

#### 3.4.3 Cepa (`cepa`)

Catálogo de cepas.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_cepa` | `INTEGER` | `PK`, `NOT NULL` | Identificador de la cepa. Se carga con IDs explícitos del catálogo. |
| `nombre` | `VARCHAR(50)` | `NOT NULL` | Nombre de la cepa, por ejemplo Malbec o Chardonnay. |
| `tipo` | `VARCHAR(50)` | `NOT NULL`, `CHECK (tipo IN ('Tinta','Blanca','Rosada'))` | Tipo de cepa. |

#### 3.4.4 LoteUva (`loteuva`)

Lote de uva cosechado en una parcela y campaña, entregado a una bodega.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_lote` | `SERIAL` | `PK`, `NOT NULL` | Identificador interno del lote. |
| `nro_lote` | `INTEGER` | `NOT NULL` | Número de lote de negocio. |
| `fecha_cosecha` | `DATE` | `NOT NULL` | Fecha de cosecha. |
| `kilos` | `NUMERIC(10,2)` | `NOT NULL`, `CHECK (kilos > 0)` | Kilos cosechados. |
| `cuit_bodega` | `cuit_dom` | `NOT NULL`, `FK → Bodega(cuit)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Bodega a la que se entregó el lote. |
| `nro_parcela` | `INTEGER` | `NOT NULL`, `FK` compuesta `(nro_parcela, id_finca) → Parcela` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Número de parcela de origen. |
| `id_finca` | `INTEGER` | `NOT NULL`, `FK` compuesta `(nro_parcela, id_finca) → Parcela` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Finca de origen. |
| `campania` | `INTEGER` | `NOT NULL` | Año de cosecha o campaña. |

**Restricción de tabla:** `UNIQUE (id_finca, nro_parcela, campania)`, que impide más de una cosecha de la misma parcela en la misma campaña.

#### 3.4.5 AnalisisCalidad (`analisiscalidad`)

Análisis de calidad practicados a un lote de uva.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_analisis` | `SERIAL` | `PK`, `NOT NULL` | Identificador del análisis. |
| `id_lote` | `INTEGER` | `NOT NULL`, `FK → LoteUva(id_lote)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Lote analizado. |
| `fecha` | `DATE` | `NOT NULL` | Fecha del análisis. |
| `grado_brix` | `NUMERIC(4,2)` | `NOT NULL` | Grado Brix medido. |
| `ph` | `NUMERIC(4,2)` | `NOT NULL` | pH medido. |
| `acidez_total` | `NUMERIC(5,2)` | `NOT NULL` | Acidez total en g/L. |

### 3.5 Elaboración y catálogo

#### 3.5.1 Bodega (`bodega`)

Bodegas del grupo que elaboran vinos.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `cuit` | `cuit_dom` | `PK`, `NOT NULL` | CUIT de la bodega; clave natural. |
| `razon_social` | `VARCHAR(50)` | `NOT NULL` | Razón social. |
| `calle_bodega` | `VARCHAR(50)` | `NULL` | Calle del domicilio. |
| `num_calle_bodega` | `VARCHAR(50)` | `NULL` | Número del domicilio. |

#### 3.5.2 Vino (`vino`)

Catálogo de vinos elaborados por las bodegas.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `codigo_vino` | `VARCHAR(50)` | `PK`, `NOT NULL` | Código de negocio del vino; clave natural. |
| `nombre_comercial` | `VARCHAR(50)` | `NOT NULL` | Nombre comercial. |
| `tipo` | `VARCHAR(50)` | `NOT NULL`, `CHECK (tipo IN ('Tinto','Blanco','Rosado','Espumante'))` | Tipo de vino. |
| `anada` | `INTEGER` | `NOT NULL`, `CHECK (anada BETWEEN 1900 AND 2100)` | Añada del vino. |
| `presentacion_ml` | `INTEGER` | `NOT NULL` | Volumen de la presentación en mililitros. |
| `graduacion_alcoholica` | `NUMERIC(4,2)` | `NOT NULL`, `CHECK (graduacion_alcoholica BETWEEN 5 AND 20)` | Graduación alcohólica en grados. |
| `precio_venta` | `NUMERIC(12,2)` | `NOT NULL`, `CHECK (precio_venta > 0)` | Precio de venta único para toda la red. |
| `cuit_bodega` | `cuit_dom` | `NOT NULL`, `FK → Bodega(cuit)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Bodega elaboradora. |

**Restricción de tabla:** `UNIQUE (nombre_comercial, anada, presentacion_ml)`, que evita duplicar la misma presentación y añada de un vino.

#### 3.5.3 VinoCepa (`vinocepa`)

Composición de cada vino por cepa.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `codigo_vino` | `VARCHAR(50)` | `PK` (compuesta), `NOT NULL`, `FK → Vino(codigo_vino)` `ON DELETE CASCADE` `ON UPDATE CASCADE` | Vino compuesto. |
| `id_cepa` | `INTEGER` | `PK` (compuesta), `NOT NULL`, `FK → Cepa(id_cepa)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Cepa que compone el vino. |
| `porcentaje_corte` | `NUMERIC(5,2)` | `NOT NULL`, `CHECK (porcentaje_corte > 0 AND porcentaje_corte <= 100)` | Porcentaje de corte de la cepa en el vino. |

**Restricción de tabla:** `PK (codigo_vino, id_cepa)`. La suma de porcentajes por vino se valida con un constraint trigger diferido.

#### 3.5.4 Maridaje (`maridaje`)

Catálogo de maridajes recomendados.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_maridaje` | `SERIAL` | `PK`, `NOT NULL` | Identificador del maridaje. |
| `nombre` | `VARCHAR(50)` | `NOT NULL` | Nombre del maridaje, por ejemplo «carnes rojas». |
| `temperatura_servicio` | `NUMERIC(4,1)` | `NOT NULL`, `CHECK (temperatura_servicio BETWEEN 5 AND 25)` | Temperatura de servicio sugerida en °C. |

#### 3.5.5 VinoMaridaje (`vinomaridaje`)

Relación N:M entre vinos y maridajes.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `codigo_vino` | `VARCHAR(50)` | `PK` (compuesta), `NOT NULL`, `FK → Vino(codigo_vino)` `ON DELETE CASCADE` `ON UPDATE CASCADE` | Vino. |
| `id_maridaje` | `INTEGER` | `PK` (compuesta), `NOT NULL`, `FK → Maridaje(id_maridaje)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Maridaje recomendado. |

**Restricción de tabla:** `PK (codigo_vino, id_maridaje)`.

### 3.6 Clientes

#### 3.6.1 Cliente (`cliente`)

Supertipo de la jerarquía de clientes.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_cliente` | `SERIAL` | `PK`, `NOT NULL` | Identificador interno del cliente; clave subrogada. |
| `apellido` | `VARCHAR(50)` | `NOT NULL` | Apellido o razón social. |
| `nombre` | `VARCHAR(50)` | `NULL` | Nombre de pila; puede ser nulo para personas jurídicas. |
| `cuit` | `cuit_dom` | `NOT NULL` | CUIT del cliente. No tiene restricción `UNIQUE` en el esquema. |
| `tipo_cliente` | `VARCHAR(50)` | `NOT NULL`, `CHECK (tipo_cliente IN ('Socio','Distribuidor','Exportador'))` | Tipo de cliente. |
| `tipo_documento` | `VARCHAR(50)` | `NOT NULL` | Tipo de documento. |
| `nro_documento` | `VARCHAR(50)` | `NOT NULL` | Número de documento. |
| `calle_cliente` | `VARCHAR(50)` | `NOT NULL` | Calle de la dirección. |
| `nro_calle_cliente` | `INTEGER` | `NOT NULL` | Número de la dirección. |
| `id_localidad` | `INTEGER` | `NOT NULL`, `FK → Localidad(id_localidad)` `ON DELETE RESTRICT` `ON UPDATE NO ACTION` | Localidad del cliente. |
| `fecha_alta` | `DATE` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Fecha de alta. |
| `descuento_porcentaje` | `NUMERIC(5,2)` | `NOT NULL`, `CHECK (descuento_porcentaje BETWEEN 0 AND 100)` | Descuento aplicable al cliente. |

#### 3.6.2 SocioClub (`socioclub`)

Subtipo de cliente para socios del club.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_cliente` | `INTEGER` | `PK`, `NOT NULL`, `FK → Cliente(id_cliente)` `ON DELETE CASCADE` `ON UPDATE NO ACTION` | Cliente socio. |
| `numero_socio` | `INTEGER` | `NOT NULL`, `UNIQUE` | Número de socio del club. |

#### 3.6.3 Distribuidor (`distribuidor`)

Subtipo de cliente para distribuidores.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_cliente` | `INTEGER` | `PK`, `NOT NULL`, `FK → Cliente(id_cliente)` `ON DELETE CASCADE` `ON UPDATE NO ACTION` | Cliente distribuidor. |
| `zona_cobertura` | `VARCHAR(50)` | `NOT NULL` | Zona de cobertura. |
| `nro_habilitacion` | `VARCHAR(50)` | `NOT NULL` | Número de habilitación. |

#### 3.6.4 Exportador (`exportador`)

Subtipo de cliente para exportadores.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_cliente` | `INTEGER` | `PK`, `NOT NULL`, `FK → Cliente(id_cliente)` `ON DELETE CASCADE` `ON UPDATE NO ACTION` | Cliente exportador. |
| `pais_destino_principal` | `VARCHAR(50)` | `NOT NULL` | País de destino principal. |

#### 3.6.5 PermisoExportacion (`permisoexportacion`)

Permisos de exportación de cada exportador.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_permiso` | `SERIAL` | `PK`, `NOT NULL` | Identificador del permiso. |
| `id_cliente` | `INTEGER` | `NOT NULL`, `FK → Exportador(id_cliente)` `ON DELETE CASCADE` `ON UPDATE NO ACTION` | Exportador titular. |
| `codigo_permiso` | `VARCHAR(50)` | `NOT NULL` | Código del permiso. |
| `fecha_emision` | `DATE` | `NOT NULL` | Fecha de emisión. |
| `fecha_vencimiento` | `DATE` | `NOT NULL`, `CHECK (fecha_vencimiento > fecha_emision)` | Fecha de vencimiento, posterior a la emisión. |

### 3.7 Ventas

#### 3.7.1 ComprobanteVenta (`comprobanteventa`)

Cabecera de cada venta.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `nro_comprobante` | `SERIAL` | `PK`, `NOT NULL` | Número de comprobante; clave subrogada. |
| `fecha` | `DATE` | `NOT NULL` | Fecha de la venta. |
| `id_cliente` | `INTEGER` | `NOT NULL`, `FK → Cliente(id_cliente)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Cliente que realizó la compra. |
| `id_sala` | `INTEGER` | `NOT NULL`, `FK → SalaDeVenta(id_sala)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Sala donde se realizó la venta. |
| `subtotal` | `NUMERIC(12,2)` | `NOT NULL`, `CHECK (subtotal >= 0)` | Suma bruta de los renglones sin descuento. Mantenido por trigger. |
| `descuento` | `NUMERIC(12,2)` | `NOT NULL` | Descuento total en monto. Mantenido por trigger. |
| `total` | `NUMERIC(12,2)` | `NOT NULL`, `CHECK (total >= 0)` | Total neto del comprobante. Mantenido por trigger. |

**Nota:** `subtotal`, `descuento` y `total` son atributos derivados persistidos. Se completan y recalculan con los triggers de `DetalleVenta`; no se cargan manualmente en la operación normal.

#### 3.7.2 DetalleVenta (`detalleventa`)

Renglones de un comprobante de venta.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `nro_comprobante` | `INTEGER` | `PK` (compuesta), `NOT NULL`, `FK → ComprobanteVenta(nro_comprobante)` `ON DELETE CASCADE` `ON UPDATE CASCADE` | Comprobante al que pertenece el renglón. |
| `codigo_vino` | `VARCHAR(50)` | `PK` (compuesta), `NOT NULL`, `FK → Vino(codigo_vino)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Vino vendido. |
| `cantidad` | `INTEGER` | `NOT NULL`, `CHECK (cantidad > 0)` | Cantidad de botellas. |
| `precio_unitario` | `NUMERIC(12,2)` | `NOT NULL`, `CHECK (precio_unitario > 0)` | Precio vigente al momento de la venta. Lo copia el trigger. |
| `descuento_aplicado` | `NUMERIC(5,2)` | `NOT NULL` | Porcentaje de descuento del cliente al momento de la venta. Lo copia el trigger. |
| `subtotal` | `NUMERIC(12,2)` | `NOT NULL`, `CHECK (subtotal > 0)` | Subtotal del renglón con descuento. Lo calcula el trigger. |

**Restricción de tabla:** `PK (nro_comprobante, codigo_vino)`.

### 3.8 Logística y stock

#### 3.8.1 Transportista (`transportista`)

Empresas de transporte que trasladan ingresos.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_transporte` | `SERIAL` | `PK`, `NOT NULL` | Identificador del transportista. |
| `razon_social` | `VARCHAR(50)` | `NOT NULL` | Razón social. |
| `cuit` | `cuit_dom` | `NOT NULL`, `UNIQUE` | CUIT del transportista. |
| `email` | `VARCHAR(50)` | `NOT NULL` | Correo electrónico. |
| `telefono` | `VARCHAR(50)` | `NOT NULL` | Teléfono. |
| `calle_transporte` | `VARCHAR(50)` | `NOT NULL` | Calle del domicilio. |
| `nro_calle_transporte` | `VARCHAR(50)` | `NOT NULL` | Número del domicilio. |

#### 3.8.2 TransportistaLocalidad (`transportistalocalidad`)

Cobertura geográfica de cada transportista.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_transporte` | `INTEGER` | `PK` (compuesta), `NOT NULL`, `FK → Transportista(id_transporte)` `ON DELETE CASCADE` `ON UPDATE NO ACTION` | Transportista. |
| `id_localidad` | `INTEGER` | `PK` (compuesta), `NOT NULL`, `FK → Localidad(id_localidad)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Localidad cubierta. |

**Restricción de tabla:** `PK (id_transporte, id_localidad)`.

#### 3.8.3 DepositoCentral (`depositocentral`)

Depósito central que recibe la producción y abastece a las salas.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_deposito` | `SERIAL` | `PK`, `NOT NULL` | Identificador del depósito. |
| `nombre` | `VARCHAR(50)` | `NOT NULL` | Nombre del depósito. |

#### 3.8.4 Ingreso (`ingreso`)

Cabecera de ingreso de vinos al depósito central.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_ingreso` | `SERIAL` | `PK`, `NOT NULL` | Identificador del ingreso. |
| `fecha` | `DATE` | `NOT NULL` | Fecha del ingreso. |
| `estado` | `estado_documento` | `NOT NULL`, `DEFAULT 'en_confeccion'` | Estado del ingreso. |
| `id_transporte` | `INTEGER` | `NOT NULL`, `FK → Transportista(id_transporte)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Transportista que efectuó el traslado. |
| `cuit_bodega` | `cuit_dom` | `NOT NULL`, `FK → Bodega(cuit)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Bodega de origen. |
| `id_deposito` | `INTEGER` | `NOT NULL`, `FK → DepositoCentral(id_deposito)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Depósito de destino. |

#### 3.8.5 DetalleIngreso (`detalleingreso`)

Renglones de un ingreso.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_ingreso` | `INTEGER` | `PK` (compuesta), `NOT NULL`, `FK → Ingreso(id_ingreso)` `ON DELETE CASCADE` `ON UPDATE CASCADE` | Ingreso al que pertenece el renglón. |
| `codigo_vino` | `VARCHAR(50)` | `PK` (compuesta), `NOT NULL`, `FK → Vino(codigo_vino)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Vino ingresado. |
| `cantidad_botellas` | `INTEGER` | `NOT NULL`, `CHECK (cantidad_botellas > 0)` | Cantidad de botellas. |

**Restricción de tabla:** `PK (id_ingreso, codigo_vino)`.

#### 3.8.6 Transferencia (`transferencia`)

Cabecera de solicitud de transferencia de vinos del depósito a una sala.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `nro_transferencia` | `SERIAL` | `PK`, `NOT NULL` | Número de transferencia. |
| `id_sala_solicitante` | `INTEGER` | `NOT NULL`, `FK → SalaDeVenta(id_sala)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Sala que solicita los vinos. |
| `id_deposito` | `INTEGER` | `NOT NULL`, `FK → DepositoCentral(id_deposito)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Depósito de origen. |
| `fecha_confeccion` | `DATE` | `NOT NULL` | Fecha de confección. El trigger la fuerza a `CURRENT_DATE` y prohíbe su modificación. |
| `estado` | `estado_documento` | `NOT NULL`, `DEFAULT 'en_confeccion'` | Estado de la transferencia. |

#### 3.8.7 DetalleTransferencia (`detalletransferencia`)

Renglones de una transferencia.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `nro_transferencia` | `INTEGER` | `PK` (compuesta), `NOT NULL`, `FK → Transferencia(nro_transferencia)` `ON DELETE CASCADE` `ON UPDATE CASCADE` | Transferencia a la que pertenece el renglón. |
| `codigo_vino` | `VARCHAR(50)` | `PK` (compuesta), `NOT NULL`, `FK → Vino(codigo_vino)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Vino solicitado. |
| `cantidad` | `INTEGER` | `NOT NULL`, `CHECK (cantidad > 0)` | Cantidad solicitada. |

**Restricción de tabla:** `PK (nro_transferencia, codigo_vino)`.

#### 3.8.8 StockDeposito (`stockdeposito`)

Stock de cada vino en el depósito central.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_deposito` | `INTEGER` | `PK` (compuesta), `NOT NULL`, `FK → DepositoCentral(id_deposito)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Depósito. |
| `codigo_vino` | `VARCHAR(50)` | `PK` (compuesta), `NOT NULL`, `FK → Vino(codigo_vino)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Vino. |
| `cantidad` | `INTEGER` | `NOT NULL`, `CHECK (cantidad >= 0)` | Botellas disponibles. |

**Restricción de tabla:** `PK (id_deposito, codigo_vino)`.

#### 3.8.9 StockSala (`stocksala`)

Stock de cada vino en cada sala.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_sala` | `INTEGER` | `PK` (compuesta), `NOT NULL`, `FK → SalaDeVenta(id_sala)` `ON DELETE NO ACTION` `ON UPDATE NO ACTION` | Sala. |
| `codigo_vino` | `VARCHAR(50)` | `PK` (compuesta), `NOT NULL`, `FK → Vino(codigo_vino)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Vino. |
| `cantidad` | `INTEGER` | `NOT NULL`, `CHECK (cantidad >= 0)` | Botellas disponibles. |

**Restricción de tabla:** `PK (id_sala, codigo_vino)`.

### 3.9 Auditoría

#### 3.9.1 AuditoriaPrecio (`auditoriaprecio`)

Registro histórico de cambios de precio de los vinos.

| Columna | Tipo de dato | Restricciones | Descripción |
|---|---|---|---|
| `id_auditoria` | `SERIAL` | `PK`, `NOT NULL` | Identificador del registro de auditoría. |
| `codigo_vino` | `VARCHAR(50)` | `NOT NULL`, `FK → Vino(codigo_vino)` `ON DELETE RESTRICT` `ON UPDATE CASCADE` | Vino cuyo precio cambió. |
| `precio_anterior` | `NUMERIC(12,2)` | `NOT NULL`, `CHECK (precio_anterior > 0)` | Precio antes del cambio. |
| `precio_nuevo` | `NUMERIC(12,2)` | `NOT NULL`, `CHECK (precio_nuevo > 0)` | Precio después del cambio. |
| `fecha_hora` | `TIMESTAMP WITHOUT TIME ZONE` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Fecha y hora del cambio. |
| `usuario` | `VARCHAR(50)` | `NOT NULL` | Usuario de base de datos que realizó el cambio (`CURRENT_USER`). |

---

## 4. Justificación técnica de decisiones de diseño

### 4.1 Estrategia de claves: naturales y subrogadas

El esquema combina claves naturales y subrogadas según la estabilidad, el significado de negocio y el costo de propagación de cada identificador.

| Entidad | Clave | Tipo | Justificación |
|---|---|---|---|
| `Bodega` | `cuit` | Natural | Es el identificador fiscal real y estable de la bodega. Se usa en las FK de `Vino`, `LoteUva` e `Ingreso`, por lo que un cambio de CUIT se propaga con `ON UPDATE CASCADE`. |
| `Empleado` | `cuit` | Natural | Identificador laboral real y estable. Se usa además como encargado regional en `Localidad`. |
| `Vino` | `codigo_vino` | Natural | Código de negocio que aparece en renglones, stock y auditoría. Evita joins adicionales para identificar el producto. |
| `Parcela` | `(nro_parcela, id_finca)` | Natural compuesta | Entidad débil: el número de parcela solo es único dentro de su finca. La clave compuesta refleja esa dependencia. |
| `Cliente` | `id_cliente` | Subrogada | El CUIT del cliente no se declara `UNIQUE` y los datos personales pueden cambiar. El identificador interno aísla las FK de esos cambios. |
| `Localidad` | `id_localidad` | Subrogada | Se conserva `UNIQUE (nombre, provincia)` como clave candidata natural, pero el ID simplifica las FK y evita propagar nombres compuestos. |
| `ComprobanteVenta` | `nro_comprobante` | Subrogada | La numeración la administra el sistema y no depende de un dato de negocio. |
| `Ingreso` | `id_ingreso` | Subrogada | Permite identificar el documento con independencia de la fecha y del transportista. |
| `Transferencia` | `nro_transferencia` | Subrogada | Igual criterio que el ingreso. |
| `LoteUva` | `id_lote` | Subrogada | Se mantiene una clave interna, con `UNIQUE (id_finca, nro_parcela, campania)` como clave de negocio que impide duplicar la cosecha. |
| `AuditoriaPrecio` | `id_auditoria` | Subrogada | La auditoría es un historial append-only; no existe un identificador natural para cada evento. |
| `Cepa` | `id_cepa` | Subrogada explícita | Catálogo cargado con IDs determinísticos desde CSV. |
| `Maridaje` | `id_maridaje` | Subrogada | Catálogo independiente, reutilizable por varios vinos. |
| `Departamento` | `id_departamento` | Subrogada explícita | Catálogo geográfico con IDs estables. |
| `DepositoCentral` | `id_deposito` | Subrogada | Permite modelar más de un depósito en el futuro sin cambiar las FK. |
| `Transportista` | `id_transporte` | Subrogada | Se conserva `UNIQUE (cuit)` como identificador fiscal, pero las FK usan el ID interno. |
| `PermisoExportacion` | `id_permiso` | Subrogada | Un exportador puede tener varios permisos y no existe un identificador natural global. |

**Criterio general.** Se prefiere la clave natural cuando el identificador existe en el negocio, es estable y se usa directamente en las relaciones. Se prefiere la clave subrogada cuando el dato de negocio puede cambiar, no está garantizado como único o cuando la clave natural es compuesta y su propagación encarece las FK. En todos los casos, las claves naturales relevantes se protegen con `UNIQUE` o con un dominio, y las subrogadas se generan con `SERIAL`.

### 4.2 Manejo de jerarquías

La única jerarquía de especialización del modelo es la de clientes. Se optó por **supertipo más subtipos**:

- `Cliente` contiene los atributos comunes y la clave `id_cliente`.
- `SocioClub`, `Distribuidor` y `Exportador` tienen `id_cliente` como PK y FK hacia `Cliente`.
- Los atributos propios de cada subtipo quedan en su tabla y son `NOT NULL` cuando corresponden.
- El borrado de un cliente arrastra sus subtipos con `ON DELETE CASCADE`.
- `PermisoExportacion` cuelga de `Exportador`, no directamente de `Cliente`, lo que impide asignar permisos a un socio o distribuidor.

**Ventajas:**

- No se llena la tabla principal con columnas nulas.
- Cada subtipo tiene solo sus atributos obligatorios.
- Se pueden agregar nuevos subtipos sin alterar la tabla `Cliente`.
- Las FK de comprobantes apuntan siempre al supertipo, lo que simplifica las ventas.

**Desventajas y control:**

- Consultar un cliente completo requiere unir el supertipo con su subtipo.
- El esquema no impone que `tipo_cliente` coincida con el subtipo existente ni que exista exactamente un subtipo. Esa consistencia se controla en la carga y en la aplicación.
- Se descartó la tabla única porque obligaría a columnas nulas y `CHECK` condicionales. Se descartó una tabla por subtipo porque duplicaría los datos comunes y complicaría las FK de comprobantes.

Las clasificaciones `Vino.tipo`, `Cepa.tipo` y `estado_documento` no son jerarquías: son dominios cerrados que se validan con `CHECK` o con un tipo enumerado. No requieren tablas adicionales.

### 4.3 Atributos derivados y control de consistencia

Los importes y el stock se persisten físicamente por dos razones: son valores históricos que no deben cambiar retroactivamente y son consultados con frecuencia. La consistencia se garantiza con funciones y triggers, no con la aplicación.

| Atributo derivado | Dónde se almacena | Mecanismo que lo mantiene | Justificación |
|---|---|---|---|
| Precio unitario histórico | `DetalleVenta.precio_unitario` | `trg_renglon_1_completar` copia `Vino.precio_venta` al insertar | El precio del vino puede cambiar; el renglón debe conservar el precio de la venta. |
| Descuento histórico | `DetalleVenta.descuento_aplicado` | `trg_renglon_1_completar` llama a `fn_descuento_cliente` | El descuento aplicado depende del cliente y del momento; no debe recalcularse con valores futuros. |
| Subtotal del renglón | `DetalleVenta.subtotal` | `trg_renglon_1_completar` calcula `ROUND(cantidad * precio_unitario * (1 - descuento / 100), 2)` | Evita repetir la fórmula en cada consulta y conserva el importe histórico. |
| Subtotal bruto del comprobante | `ComprobanteVenta.subtotal` | `trg_renglon_3_stock_y_totales` suma `cantidad * precio_unitario` de los renglones | Es la base para calcular el descuento total. |
| Descuento total | `ComprobanteVenta.descuento` | `trg_renglon_3_stock_y_totales` calcula `subtotal_bruto - total_neto` | Expone el monto descontado sin que la aplicación lo recalcule. |
| Total del comprobante | `ComprobanteVenta.total` | `trg_renglon_3_stock_y_totales` usa `fn_total_comprobante` | La función suma los subtotales de los renglones y evita duplicar la fórmula. |
| Stock del depósito | `StockDeposito.cantidad` | `sp_procesar_ingreso` y `sp_procesar_transferencia`, con `FOR UPDATE` y `ON CONFLICT` | El stock es una magnitud operativa persistida para evitar cálculos sobre todo el historial. |
| Stock de la sala | `StockSala.cantidad` | `trg_renglon_3_stock_y_totales`, `sp_procesar_transferencia` y `trg_renglon_2_valida_stock` | Se descuenta al vender y se incrementa al transferir; nunca puede ser negativo. |
| Auditoría de precio | `AuditoriaPrecio` | `trg_vino_auditoria_precio` inserta precio anterior, nuevo, usuario y fecha | Conserva el historial de cambios aunque el precio actual se modifique. |

**Control de consistencia:**

- `fn_total_comprobante` es `STABLE` y devuelve `0` si el comprobante no tiene renglones.
- `trg_renglon_1_completar` bloquea la cabecera con `FOR UPDATE` para serializar la carga de renglones del mismo comprobante.
- `trg_renglon_2_valida_stock` bloquea la fila de `StockSala` con `FOR UPDATE` y rechaza la venta si no hay stock.
- `trg_renglon_3_stock_y_totales` descuenta el stock y recalcula los importes de la cabecera.
- Los `CHECK` impiden stock negativo y precios no positivos.
- `verificacion_etapa3.sql` controla que los subtotales, descuentos y totales coincidan con la suma de los renglones, que la composición de los vinos sume 100 y que no haya stock negativo.
- La cabecera `ComprobanteVenta` tiene columnas `NOT NULL`; en la práctica se inserta con valores provisionales en cero y los triggers los reemplazan al agregar los renglones. Es una consecuencia del diseño de triggers `AFTER INSERT` y se documenta como detalle de implementación.

**Evidencia de concurrencia.** La prueba documentada en `docs/informe.md` usa dos sesiones `psql` sobre `bodega_test` con aislamiento `READ COMMITTED`. Sin `FOR UPDATE`, ambas sesiones leen el mismo stock y la segunda venta falla al intentar descontar; con `FOR UPDATE`, la segunda sesión espera el `COMMIT` de la primera y luego ve el stock actualizado. Las capturas del escenario están en `docs/capturas/concurrencia_*.jpeg`.

### 4.4 Políticas de eliminación y actualización referencial

Las acciones referenciales se eligieron para proteger el historial y evitar borrados accidentales.

| Política | Claves foráneas afectadas | Justificación |
|---|---|---|
| `ON DELETE RESTRICT` | `Vino` referenciado por `AuditoriaPrecio`, `DetalleIngreso`, `DetalleTransferencia`, `DetalleVenta`, `StockDeposito` y `StockSala`; `Bodega` referenciada por `Ingreso`, `LoteUva` y `Vino`; `Transportista` referenciado por `Ingreso`; `Localidad` referenciada por `Cliente` y `SalaDeVenta`; `SalaDeVenta` referenciada por `Empleado`; `LoteUva` referenciado por `AnalisisCalidad` | Impide borrar maestros con movimientos o historia asociada. Es la política de RN-14 para vino, bodega y transportista. |
| `ON DELETE CASCADE` | `DetalleVenta` → `ComprobanteVenta`; `DetalleIngreso` → `Ingreso`; `DetalleTransferencia` → `Transferencia`; `SocioClub`, `Distribuidor` y `Exportador` → `Cliente`; `PermisoExportacion` → `Exportador`; `Parcela` → `Finca`; `VinoCepa` y `VinoMaridaje` → `Vino`; `TransportistaLocalidad` → `Transportista` | Se aplica solo a filas que no existen sin su padre: renglones, subtipos, permisos, parcelas y relaciones de composición o cobertura. |
| `ON DELETE SET NULL` | `Localidad.cuit_encargado` → `Empleado.cuit` | Una localidad puede quedar temporalmente sin encargado. La columna es nullable y la dependencia circular `Localidad → Empleado → SalaDeVenta → Localidad` se resuelve sin borrar la localidad. |
| `ON DELETE NO ACTION` | `ComprobanteVenta` → `Cliente` y `SalaDeVenta`; `Finca` → `Departamento`; `Ingreso` → `DepositoCentral`; `LoteUva` → `Parcela`; `Parcela` → `Cepa`; `StockDeposito` → `DepositoCentral`; `StockSala` → `SalaDeVenta`; `Transferencia` → `DepositoCentral` y `SalaDeVenta`; `TransportistaLocalidad` → `Localidad`; `VinoCepa` y `VinoMaridaje` → catálogos | Protege catálogos y cabeceras que no deben desaparecer si tienen referencias. La verificación se hace al ejecutar la operación, sin acción automática. |
| `ON UPDATE CASCADE` | Claves naturales: `Bodega.cuit`, `Vino.codigo_vino`, `Empleado.cuit`, `Localidad.id_localidad` en `SalaDeVenta`, entre otras | Propaga un cambio de identificador natural a las FK que lo usan. |
| `ON UPDATE NO ACTION` | Claves subrogadas y referencias que no deberían cambiar | Evita actualizaciones automáticas en identificadores internos. |

**Diferencia entre `RESTRICT` y `NO ACTION`.** En PostgreSQL, `RESTRICT` impide la operación inmediatamente, mientras que `NO ACTION` permite que la verificación se aplace hasta el final de la sentencia si la FK se declara diferible. En este esquema no se declaran FK diferibles, por lo que ambas políticas se comportan de forma equivalente en la práctica; la distinción se mantiene por claridad semántica: `RESTRICT` expresa una prohibición explícita y `NO ACTION` expresa una referencia sin acción automática.

**Anomalías evitadas.** Las políticas impiden:

- Borrar un vino, una bodega o un transportista con ventas, ingresos o stock asociados.
- Borrar una sala con empleados o comprobantes.
- Dejar renglones huérfanos cuando se elimina su cabecera.
- Dejar permisos de exportación o subtipos de cliente sin su cliente.
- Perder la trazabilidad de una localidad cuando se elimina su encargado.

### 4.5 Lógica de base de datos que respalda las decisiones

#### 4.5.1 Funciones

| Función | Regla | Propósito | Volatilidad |
|---|---|---|---|
| `fn_total_comprobante(p_nro_comprobante integer)` | RN-08 | Suma los subtotales de `DetalleVenta`; devuelve `0` si no hay renglones | `STABLE` |
| `fn_stock_sala(p_id_sala integer, p_codigo_vino varchar)` | RN-09 | Devuelve el stock de un vino en una sala; `0` si no existe la fila | `STABLE` |
| `fn_descuento_cliente(p_id_cliente integer)` | RN-06 | Devuelve `Cliente.descuento_porcentaje`; falla si el cliente no existe | `STABLE` |
| `fn_antiguedad_anios(p_fecha_ingreso date)` | U2 / D3 | Años cumplidos desde la fecha de ingreso hasta `CURRENT_DATE` | `STABLE` |

Ninguna función es `IMMUTABLE` porque consultan tablas o dependen de la fecha actual. No se usan funciones no determinísticas dentro de `CHECK`.

#### 4.5.2 Procedimientos almacenados

| Procedimiento | Regla | Efecto |
|---|---|---|
| `sp_procesar_ingreso(p_id_ingreso integer)` | RN-10 | Verifica que el ingreso esté `terminado`, bloquea documento, renglones y stock, suma botellas a `StockDeposito` y pasa el ingreso a `procesado` |
| `sp_procesar_transferencia(p_nro_transferencia integer)` | RN-11 | Verifica que la transferencia esté `terminada`, bloquea filas, controla stock suficiente en el depósito, descuenta del depósito, suma a `StockSala` y pasa a `procesado` |

Los procedimientos no ejecutan `COMMIT` ni `ROLLBACK`: la atomicidad la controla la transacción del llamador. El orden de bloqueo es documento → renglones → stock del depósito → stock de la sala, ordenado por `codigo_vino` para reducir el riesgo de deadlocks.

#### 4.5.3 Triggers

| Trigger | Evento | Regla | Función |
|---|---|---|---|
| `trg_renglon_1_completar` | `BEFORE INSERT` en `DetalleVenta` | RN-06, RN-08 | Completa precio, descuento y subtotal del renglón |
| `trg_renglon_2_valida_stock` | `BEFORE INSERT` en `DetalleVenta` | RN-09 | Rechaza la venta si la sala no tiene stock |
| `trg_renglon_3_stock_y_totales` | `AFTER INSERT` en `DetalleVenta` | RN-08, RN-09 | Descuenta stock y recalcula importes de la cabecera |
| `trg_ingreso_estado` | `BEFORE UPDATE OF estado` en `Ingreso` | RN-10 | Solo permite `en_confeccion → terminado → procesado` |
| `trg_transferencia_estado` | `BEFORE UPDATE OF estado` en `Transferencia` | RN-11 | Solo permite la misma secuencia de estados |
| `trg_transferencia_fecha` | `BEFORE INSERT OR UPDATE OF fecha_confeccion` en `Transferencia` | RN-11 | Fuerza la fecha actual y prohíbe modificarla |
| `trg_detalle_ingreso_bloqueo` | `BEFORE INSERT/UPDATE/DELETE` en `DetalleIngreso` | RN-12 | No admite cambios si el ingreso no está en confección |
| `trg_detalle_transferencia_bloqueo` | `BEFORE INSERT/UPDATE/DELETE` en `DetalleTransferencia` | RN-12 | No admite cambios si la transferencia no está en confección |
| `trg_vino_auditoria_precio` | `AFTER UPDATE OF precio_venta` en `Vino` | RN-13 | Registra precio anterior, nuevo, fecha y usuario |
| `trg_vinocepa_suma_100` | `CONSTRAINT TRIGGER` diferido en `VinoCepa` | RN-05 | Verifica al cerrar la transacción que la composición sume 100 |
| `trg_vino_suma_100` | `CONSTRAINT TRIGGER` diferido en `Vino` | RN-05 | Verifica que un vino recién creado tenga composición válida |

#### 4.5.4 Vistas

| Vista | Propósito |
|---|---|
| `vw_stock_total_vino` | Stock total por vino: depósito central más suma de salas |
| `vw_ventas_mensuales_sala` | Comprobantes, subtotal, descuento y total agrupados por sala y mes |
| `vw_documentos_pendientes` | Ingresos y transferencias no procesados, con días transcurridos |

#### 4.5.5 Roles y privilegios

| Rol | Uso | Privilegios |
|---|---|---|
| `bodega_propietario` | Administración de la base | `CONNECT`, `CREATE` y `TEMPORARY` sobre la base; `USAGE` y `CREATE` en `public`; todos los privilegios sobre tablas, secuencias, funciones y procedimientos |
| `bodega_api` | Lectura/escritura de la API | `SELECT`, `INSERT`, `UPDATE`, `DELETE` sobre tablas; secuencias; ejecución de funciones y procedimientos |
| `bodega_lectura` | Reportes | `SELECT` sobre tablas y ejecución de las cuatro funciones |

Se revocan los privilegios de `PUBLIC` sobre la base, el esquema, las tablas, las secuencias, las funciones y los procedimientos. `AuditoriaPrecio` es append-only para `bodega_api`: se revocan `UPDATE` y `DELETE`, y el `INSERT` queda disponible para el trigger de auditoría. Las contraseñas no se versionan; se asignan en el despliegue con `ALTER ROLE ... PASSWORD`.

### 4.6 Guía: dónde va cada regla

La guía del TPI pide explicar dónde vive cada tipo de regla y por qué. El criterio aplicado es: si la regla puede expresarse de forma declarativa, se expresa en el esquema; si depende de varias filas, de un agregado o de una transición de estado, se implementa con función, trigger o procedimiento; y si no es expresable en SQL, se controla en la carga y se documenta como límite.

| Tipo de regla | Mecanismo elegido | Ejemplos en el repositorio | Por qué |
|---|---|---|---|
| Existencia y obligatoriedad | `NOT NULL` | `Empleado.id_sala`, `Vino.cuit_bodega`, `ComprobanteVenta.id_cliente` | La base rechaza filas incompletas sin depender de la aplicación. |
| Unicidad | `PRIMARY KEY` y `UNIQUE` | `Uq_socio_numero`, `Uq_transportista_cuit`, `Uq_vino_nombre_anada_presentacion`, `Lote_Uva_campania` | Evita duplicados con un índice único y permite que las FK apunten a claves confiables. |
| Dominio y rango | `DOMAIN`, `ENUM` y `CHECK` | `cuit_dom`, `estado_documento`, `Check_vino_tipo`, `Check_maridaje_temperatura`, `Check_vino_precio` | Son reglas de una sola fila y se validan en el menor nivel posible. |
| Integridad referencial y acción ante borrado | `FOREIGN KEY` con `ON DELETE` / `ON UPDATE` | `Vino` con `RESTRICT`, `DetalleVenta` con `CASCADE`, `Localidad.cuit_encargado` con `SET NULL` | Preservan el historial y eliminan solo filas que no existen sin su padre. |
| Regla entre filas o agregado | Función y trigger, incluso `CONSTRAINT TRIGGER` diferido | `fn_total_comprobante` + `trg_renglon_3_stock_y_totales`; `trg_vinocepa_suma_100`; `trg_vino_suma_100` | El total y la composición dependen de varias filas; el trigger diferido permite cerrar la transacción con el conjunto completo. |
| Operación transaccional multi-tabla | Procedimiento almacenado | `sp_procesar_ingreso`, `sp_procesar_transferencia` | Verifican estado, bloquean filas, actualizan stock y cambian el estado en una sola operación atómica. |
| Historial y auditoría | Trigger `AFTER` y tabla append-only | `trg_vino_auditoria_precio` sobre `Vino` y `AuditoriaPrecio` | El cambio de precio deja rastro aunque la aplicación olvide registrarlo; a la API se le revocan `UPDATE` y `DELETE`. |
| Invariante verificable pero costosa de imponer fila por fila | Script de verificación | `db/tests/verificacion_etapa3.sql`, `db/tests/db_tests.sql` | Se ejecuta después de la carga o del cambio y falla si alguna consulta de control devuelve un valor distinto de cero. |
| Reporte y agregación | Vista | `vw_stock_total_vino`, `vw_ventas_mensuales_sala`, `vw_documentos_pendientes` | Centraliza la consulta y evita repetir la lógica en la aplicación. |
| Seguridad y menor privilegio | Roles y `GRANT` / `REVOKE` | `bodega_propietario`, `bodega_api`, `bodega_lectura` | Cada consumidor recibe solo los permisos que necesita; `PUBLIC` queda sin acceso. |
| Regla no expresable declarativamente | Control en la carga y en la aplicación, documentado | Correspondencia entre `Cliente.tipo_cliente` y su subtipo | Exigiría un `CHECK` cruzado entre tablas o un trigger adicional; se documenta como límite en la sección 4.8. |

**Criterio de asignación.** No se deja en la aplicación una regla que la base pueda garantizar, y no se fuerza en un trigger una decisión que depende de datos externos o de una política comercial. Las reglas que quedan fuera de SQL se verifican en la carga y se declaran explícitamente para que no parezcan garantizadas por el esquema.

### 4.7 Demostración de concurrencia

La prueba se ejecutó con dos sesiones `psql` sobre la base `bodega_test`, con aislamiento `READ COMMITTED`, el vino `V0420` y la sala 1 con stock 1. El objetivo es mostrar qué ocurre cuando dos ventas compiten por la última botella y cómo `FOR UPDATE`, el trigger de stock y el `CHECK` evitan el stock negativo.

| Paso | Sin `FOR UPDATE` | Con `FOR UPDATE` |
|---|---|---|
| A lee el stock | `SELECT` devuelve 1 sin bloquear | `SELECT ... FOR UPDATE` devuelve 1 y bloquea la fila |
| B lee el stock | `SELECT` devuelve 1: lectura vieja | Queda esperando el lock de A |
| A inserta el renglón | El trigger descuenta la botella y A deja la transacción abierta | Igual que en el caso sin bloqueo |
| B inserta el renglón | Queda esperando el lock del trigger | Sigue esperando a que A confirme |
| A confirma | `COMMIT` | `COMMIT` |
| B se desbloquea | El trigger vuelve a leer 0 y rechaza la venta con RN-09; B hace `ROLLBACK` | El `SELECT` devuelve 0 y la venta falla con RN-09; B hace `ROLLBACK` |

**Conclusión.** El `SELECT ... FOR UPDATE` explícito evita la lectura vieja y hace que la espera ocurra antes de insertar. Aun sin ese bloqueo en la aplicación, `trg_renglon_2_valida_stock` bloquea la fila de `StockSala` con `FOR UPDATE` y serializa la escritura; el `CHECK (cantidad >= 0)` es la última barrera. La invariante se mantiene en ambos escenarios, pero el bloqueo explícito produce un comportamiento más predecible y menos trabajo desperdiciado.

Evidencia en `docs/capturas/`:

- `concurrencia_for_update_1_a_abierta_b_bloqueada.jpeg`: A mantiene el lock y B espera.
- `concurrencia_for_update_2_a_commit_b_desbloqueada.jpeg`: A confirma; B ve 0 y recibe el error de RN-09.
- `concurrencia_sin_for_update_1_ambos_leen_stock.jpeg`: ambas sesiones leen 1.
- `concurrencia_sin_for_update_2_a_descuenta_b_bloqueada.jpeg`: A descuenta y B espera el trigger.
- `concurrencia_sin_for_update_3_a_commit_error_b.jpeg`: A confirma; B recibe el error de RN-09.

El detalle de las sentencias ejecutadas está en `docs/informe.md`, sección «Prueba de concurrencia».

### 4.8 Observaciones de consistencia entre la guía y el código

Las siguientes observaciones reflejan el estado real del esquema y no propuestas futuras:

1. **`Empleado` no tiene columna `apellido`.** La guía menciona nombre y apellido; el código almacena un único campo `nombre`.
2. **`Cepa.tipo` admite `'Rosada'`.** El `CHECK` de `002_constraints.sql` incluye `'Rosada'` además de `'Tinta'` y `'Blanca'`.
3. **`SalaDeVenta.dia_cierre` admite `'Ninguno'`.** El `CHECK` incluye ese valor además de los días de la semana.
4. **`Localidad` no tiene FK a `Departamento`.** La relación geográfica se usa en `Finca`; las localidades se cargan como catálogo independiente.
5. **`Cliente.cuit` no es `UNIQUE`.** La identidad del cliente la garantiza `id_cliente`; el CUIT se valida por dominio pero no por unicidad.
6. **La jerarquía de clientes no tiene una restricción de exclusividad.** `tipo_cliente` y la existencia del subtipo se controlan en la carga y en la aplicación, no con un `CHECK` cruzado entre tablas.
7. **No todos los atributos tienen `CHECK` de positividad.** Por ejemplo, `Vino.presentacion_ml` no tiene `CHECK > 0` y `DetalleVenta.descuento_aplicado` no tiene un `CHECK` de rango propio; la API valida los descuentos de clientes según el tipo y la excepción U6 para exportadores con más de tres permisos.
8. **El volcado versionado requiere regeneración.** `db/dump_completo.sql.gz` (10.106.395 bytes, SHA-256 `45cf6078…949ff`) se generó antes de la corrección de `fn_descuento_cliente` que introdujo el commit `f755e43`; conserva valor como artefacto de reproducibilidad, pero no se usa como evidencia primaria de la lógica actual. Después de regenerarlo hay que actualizar el tamaño y el hash en `README.md` y en la sección 5.7.

---

## 5. Carga masiva de datos (Etapa 3)

La Etapa 3 está implementada por completo en `db/seed/`. Incluye los catálogos reales del Anexo B, un generador determinístico, la carga del volumen de operación, la comparación de tres estrategias de inserción, controles de integridad y un volcado versionado. Esta sección consolida esos artefactos y las decisiones registradas en `db/seed/README.md` y en `docs/informe.md`.

### 5.1 Catálogos reales (Anexo B)

Los catálogos se guardan en `db/seed/` con codificación UTF-8, encabezado, coma como separador e identificadores explícitos y determinísticos. No se generan al azar: dos ejecuciones producen los mismos valores.

| Archivo | Tabla destino | Filas | Columnas | Fuente |
|---|---|---:|---|---|
| `cepas.csv` | `Cepa` | 12 | `id_cepa`, `nombre`, `tipo` | Anexo B.1 |
| `maridajes.csv` | `Maridaje` | 8 | `id_maridaje`, `nombre`, `temperatura_servicio` | Anexo B.2 |
| `tipos_vino.csv` | Sin tabla destino (catálogo de referencia) | 4 | `tipo` | Anexo B.4 |
| `departamentos.csv` | `Departamento` | 18 | `id_departamento`, `nombre`, `provincia` | Anexo B.3 |
| `localidades.csv` | `Localidad` | 18 | `id_localidad`, `nombre`, `provincia`, `codigo_postal`, `cuit_encargado` | Anexo B.3 |

- **Cepas (12):** 7 tintas y 5 blancas, con la grafía exacta que admite `Check_cepa_tipo`.
- **Maridajes (8):** temperaturas entre 8 °C y 17 °C, dentro del rango de `Check_maridaje_temperatura`.
- **Tipos de vino (4):** Tinto, Blanco, Rosado y Espumante. El esquema no tiene tabla `TipoVino`; la fuente de verdad es `Check_vino_tipo` y el CSV se usa como referencia del generador.
- **Departamentos y localidades (18):** una localidad cabecera por departamento. La correspondencia se documenta en `docs/informe.md` porque `Localidad` no tiene FK a `Departamento`.
- **`Localidad.cuit_encargado`:** se carga en `NULL` y se completa después de cargar `Empleado`, para resolver la dependencia circular `Localidad → Empleado → SalaDeVenta → Localidad`.

### 5.2 Generador y ejecución

`db/seed/load.py` usa Python 3.10 o superior, `psycopg` 3 y `Faker` con locale `es_AR`; las dependencias están en `db/seed/requirements.txt`. La semilla por defecto es `20261101` y la fecha base por defecto es `2026-11-01`, ambas configurables.

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r db/seed/requirements.txt
$env:PGPASSWORD = "<password>"

# Validación sin base: genera, valida y muestra conteos.
.\.venv\Scripts\python.exe db/seed/load.py --dry-run --scale 0.01

# Carga completa sobre una base vacía.
.\.venv\Scripts\python.exe db/seed/load.py --scale 1.0

# Recarga completa y reporte JSON.
.\.venv\Scripts\python.exe db/seed/load.py --reset --scale 1.0 --report db/seed/report_local.json

# Comparación de estrategias con rollback.
.\.venv\Scripts\python.exe db/seed/load.py --benchmark --benchmark-scale 1.0 `
  --benchmark-report db/seed/benchmark_report.json
```

| Opción | Descripción |
|---|---|
| `--dsn` | Cadena de conexión completa; tiene prioridad sobre las variables `PG*`. |
| `--reset` | Ejecuta `TRUNCATE ... RESTART IDENTITY CASCADE` sobre las 31 tablas. |
| `--scale` | Factor de escala de los volúmenes; por defecto `1.0`. |
| `--strategy` | `copy` (por defecto), `executemany` o `individual`. |
| `--seed` | Semilla del generador; por defecto `20261101`. |
| `--base-date` | Fecha base ISO del historial; por defecto `2026-11-01`. |
| `--dry-run` | Genera y valida en memoria, sin conectarse a PostgreSQL. |
| `--report` | Escribe un JSON con conteos, tiempos y resultados de control. |
| `--benchmark` | Compara las tres estrategias dentro de transacciones con rollback. |
| `--benchmark-scale` | Escala del benchmark; por defecto `1.0`. |
| `--benchmark-report` | Archivo JSON con el detalle por tabla del benchmark. |

Sin `--reset`, el script aborta si detecta datos en `Cepa`, `Vino` o `ComprobanteVenta`. La contraseña no se guarda en el repositorio: se toma de `PGPASSWORD`, de las variables estándar de PostgreSQL o de `--dsn`.

### 5.3 Volúmenes y orden de carga

| Tabla | Filas | Tabla | Filas |
|---|---:|---|---:|
| `cepa` | 12 | `maridaje` | 8 |
| `departamento` | 18 | `localidad` | 18 |
| `bodega` | 20 | `transportista` | 18 |
| `depositocentral` | 1 | `saladeventa` | 20 |
| `empleado` | 120 | `transportistalocalidad` | 49 |
| `finca` | 30 | `parcela` | 900 |
| `loteuva` | 4.000 | `analisiscalidad` | 8.029 |
| `cliente` | 20.000 | `socioclub` | 14.016 |
| `distribuidor` | 3.946 | `exportador` | 2.038 |
| `permisoexportacion` | 4.558 | `vino` | 600 |
| `vinocepa` | 880 | `vinomaridaje` | 903 |
| `stockdeposito` | 600 | `ingreso` | 2.000 |
| `detalleingreso` | 7.125 | `transferencia` | 3.000 |
| `detalletransferencia` | 9.277 | `stocksala` | 3.000 |
| `comprobanteventa` | 150.000 | `detalleventa` | 510.382 |
| `auditoriaprecio` | 1 | **Total** | **745.569** |

`vino` se fija en 600 para que `vinocepa` y `vinomaridaje` queden dentro del rango recomendado de 300 a 1.000 filas. El orden de carga es topológico:

1. Catálogos: cepas, maridajes, departamentos, localidades, bodegas, transportistas y depósito central.
2. Salas de venta y empleados.
3. Fincas, parcelas, lotes de uva y análisis de calidad.
4. Clientes, socios, distribuidores, exportadores y permisos.
5. Vinos, composición de cepas, maridajes y stock del depósito.
6. Ingresos y sus renglones; transferencias y sus renglones.
7. Stock de salas, comprobantes de venta, renglones y auditoría.
8. Actualización de `Localidad.cuit_encargado` con los empleados ya cargados.
9. Ajuste de secuencias con `setval`, `ANALYZE` y verificación final.

Antes de tocar la base, el generador valida en memoria claves primarias únicas, referencias existentes, composición de vinos, subtotales, totales, stock no negativo y coherencia del descuento por tipo de cliente. La carga y los controles corren en una única transacción: cualquier fallo revierte todo.

### 5.4 Estrategia frente a los triggers

La carga histórica no puede ejecutar los triggers operativos tal como están, porque rechazarían fechas pasadas, renglones de documentos ya cerrados o ventas históricas que no deben descontar stock actual. Dentro de la misma transacción se deshabilitan los triggers de usuario de estas tablas:

| Tabla | Triggers deshabilitados | Motivo |
|---|---|---|
| `DetalleVenta` | `trg_renglon_1_completar`, `trg_renglon_2_valida_stock`, `trg_renglon_3_stock_y_totales` | Las ventas históricas no deben descontar stock actual ni recalcular totales ya calculados. |
| `Transferencia` | `trg_transferencia_estado`, `trg_transferencia_fecha` | La fecha histórica no debe reemplazarse por `CURRENT_DATE`; los documentos se cargan terminados. |
| `DetalleIngreso` | `trg_detalle_ingreso_bloqueo` | El ingreso se carga cerrado y el trigger rechazaría sus renglones. |
| `DetalleTransferencia` | `trg_detalle_transferencia_bloqueo` | La transferencia se carga cerrada y el trigger rechazaría sus renglones. |
| `Vino` | `trg_vino_auditoria_precio`, `trg_vino_suma_100` | Los precios son históricos; la composición se valida después de cargar todas las cepas. |
| `VinoCepa` | `trg_vinocepa_suma_100` | La composición se controla al finalizar la carga. |

`trg_ingreso_estado` no se desactiva porque es `BEFORE UPDATE OF estado` y la carga solo hace `INSERT`. Las claves foráneas siguen activas: son triggers internos y `DISABLE TRIGGER USER` no las afecta. Los totales de `ComprobanteVenta` se calculan en Python con la misma fórmula de los triggers y funciones de la Etapa 2, porque los triggers que los recalcularían están deshabilitados durante la carga.

**Riesgos y mitigaciones.** El `DISABLE TRIGGER USER` toma un lock exclusivo y la carga corre en una única transacción, en un entorno controlado y sin sesiones concurrentes. Los `DISABLE` y `ENABLE` están en la misma transacción, de modo que un error revierte ambos. Los datos se validan en Python y con 15 controles SQL antes del `COMMIT`; las FK no se desactivan y se validan fila por fila.

### 5.5 Tiempos y comparación de estrategias

El modo `--benchmark` genera un único dataset y lo inserta tres veces dentro de transacciones con `force_rollback=True`, sin modificar datos, secuencias ni triggers. La comparación se hizo a escala `1.0`, con 745.569 filas, triggers deshabilitados y FK activas:

| Estrategia | Inserción | Tiempo total | Filas/s | vs. `individual` |
|---|---:|---:|---:|---:|
| `copy` | 20,481 s | 21,975 s | 36.403,0 | 10,06x |
| `executemany` | 40,831 s | 42,412 s | 18.259,9 | 5,05x |
| `individual` | 206,065 s | 207,406 s | 3.618,1 | 1,00x |

La generación previa tardó 7,87 s. Los 15 controles dieron cero en las tres estrategias. `COPY` es la estrategia por defecto porque es la más rápida y la que mejor se adapta a una carga histórica masiva; `executemany` queda como alternativa por lotes. `psycopg` 3 no expone `execute_values` de `psycopg2`, por eso el lote se implementó con `executemany`.

La corrida local registrada en `db/seed/report_local.json` usó la estrategia `copy`, escala `1.0`, semilla `20261101` y fecha base `2026-11-08`. La suma de los tiempos de inserción por tabla fue 21,566 s para 745.569 filas, con los 15 controles en cero y `validation_errors` vacío.

### 5.6 Controles de integridad

El cargador ejecuta 15 controles antes del `COMMIT` y falla si alguno devuelve un valor distinto de cero:

- Triggers de usuario deshabilitados.
- Vinos cuya composición de cepas no suma 100.
- Comprobantes con totales inconsistentes o sin renglones.
- Stock negativo en depósito o sala.
- Renglones huérfanos de comprobante, vino, ingreso o transferencia.
- Lotes sin parcela, clientes sin localidad, empleados sin sala, vinos sin bodega o permisos sin exportador.

Además, `db/tests/verificacion_etapa3.sql` es un script independiente del cargador que ejecuta 22 controles y falla con una excepción si alguno no coincide con el valor esperado:

| Categoría | Controles | Esperado |
|---|---:|---:|
| Stock negativo en depósito o sala | 2 | 0 |
| Coherencia de importes, descuentos y composición | 6 | 0 |
| Huérfanos en relaciones principales | 11 | 0 |
| Integridad global: FK validadas, triggers habilitados y localidades con encargado | 3 | 0 |

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bodega_seed `
  -v ON_ERROR_STOP=1 -f db/tests/verificacion_etapa3.sql
```

El script crea una vista temporal con una fila por control, compara `resultado` con `esperado`, ordena la salida y lanza `RAISE EXCEPTION` si hay diferencias. Los 22 controles dieron cero sobre la carga completa.

### 5.7 Volcado y restauración

El volcado se generó con `pg_dump` 18.3 en formato SQL plano, sin propietarios ni privilegios, y se comprimió con gzip:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" -U postgres -d bodega_seed `
  --no-owner --no-privileges -f db/dump_completo.sql
gzip -9 -f db/dump_completo.sql
```

```text
db/dump_completo.sql.gz
10.106.395 bytes
SHA-256 45cf607865aa4aa331e0cca0fdc7cbcbf02e384ca3d193fea78081d3fdc949ff
31 bloques COPY · 745.569 filas
```

La restauración se probó en una base temporal `bodega_restore`: coincidieron las 31 tablas y las 745.569 filas, y los 22 controles volvieron a dar cero. Como el volcado usa `--no-owner --no-privileges`, los roles y permisos se recrean después con `db/migrations/007_roles.sql`.

> **Salvedad.** El archivo versionado se generó antes de la corrección de `fn_descuento_cliente` introducida en el commit `f755e43`. Por eso conserva valor como artefacto de reproducibilidad, pero no se usa como evidencia primaria de la lógica actual: hay que regenerarlo y actualizar el tamaño y el SHA-256 en `README.md` y en esta sección.

### 5.8 Reproducibilidad y fecha base

- Semilla fija `20261101` y fecha base configurable; por defecto `2026-11-01`.
- Un `random.Random` independiente por sección, derivado de `seed:seccion`, y `Faker.seed(seed)`.
- No se usa `date.today()` ni `CURRENT_TIMESTAMP` para generar datos.
- Dos ejecuciones con la misma semilla, escala y fecha base producen exactamente el mismo dataset.
- Las consultas que usan `CURRENT_DATE` solo devuelven filas si el historial llega cerca de la fecha de ejecución. Para la defensa conviene recargar con `--base-date` próxima al día de la consulta; la semilla se mantiene, así que el dataset es el mismo salvo el desplazamiento de fechas.

## 6. Consultas SQL (Etapa 5)

### 6.1 Organización y criterio de ejecución

La Etapa 5 se implementó en cuatro archivos dentro de `consultas/`:

| Archivo | Consignas | Contenido |
|---|---|---|
| `insert.sql` | I1 a I6 | Inserciones con controles previos y posteriores |
| `update.sql` | U1 a U6 | Modificaciones masivas y verificación de auditoría |
| `delete.sql` | D1 a D6 | Borrados y control de acciones referenciales |
| `select.sql` | S1 a S12 | Agregación, división relacional y funciones de ventana |

Todas las consignas se ejecutan dentro de `BEGIN ... ROLLBACK`, de modo que la prueba no altera el dataset. Cuando la consigna genera una clave, el archivo la guarda en una tabla temporal `ON COMMIT DROP` para poder consultarla en los controles posteriores. Los controles previos y posteriores comparan el estado de las filas y se apoyan en los tags de `psql` (`INSERT 0 n`, `UPDATE n`, `DELETE n`). Los valores concretos de localidades, vinos, bodegas y clientes se tomaron del dataset cargado; las fechas relativas se calculan con `CURRENT_DATE`, como exige la guía.

### 6.2 Inventario de consignas

#### 6.2.1 Inserción (I1 a I6)

| Código | Objetivo | Técnica destacada |
|---|---|---|
| I1 | Agregar la cobertura de General Alvear al transportista con menos envíos del último trimestre | CTE de ranking, `NOT EXISTS` e `INSERT ... SELECT` |
| I2 | Crear el maridaje «cordero al disco» y asociarlo a los tintos con graduación mayor o igual a 14° | CTE con `INSERT ... WHERE EXISTS` y `ON CONFLICT DO NOTHING` |
| I3 | Crear un comprobante de tres renglones para un socio en la sala 1 | Tabla temporal, `INSERT ... RETURNING` y triggers RN-06, RN-08 y RN-09 |
| I4 | Insertar una bodega con CUIT nuevo | `INSERT ... RETURNING` sobre `cuit_dom` |
| I5 | Insertar una sala de venta con día de cierre válido | `INSERT ... RETURNING` y `CHECK (dia_cierre ...)` |
| I6 | Crear un ingreso en confección de 120 botellas | Tabla temporal, `INSERT ... RETURNING` y `DetalleIngreso` bajo RN-12 |

#### 6.2.2 Modificación (U1 a U6)

| Código | Objetivo | Técnica destacada |
|---|---|---|
| U1 | Recalcular los totales de los 150.000 comprobantes con el descuento del cliente | CTE y `UPDATE ... FROM` set-based (RN-06 y RN-08) |
| U2 | Aumentar 20 % el salario de los empleados con más de 5 años | `fn_antiguedad_anios` en el `WHERE` |
| U3 | Incrementar 13 % el precio de los vinos de una bodega | `UPDATE` y auditoría automática de RN-13 |
| U4 | Intercambiar los días de cierre lunes y miércoles | Un único `UPDATE` con `CASE` |
| U5 | Aplicar 15 % de descuento a los 10 vinos menos vendidos | CTE, `ROW_NUMBER()` y `UPDATE ... FROM` (RN-13) |
| U6 | Llevar al 35 % el descuento de los exportadores con más de 3 permisos | CTE con `HAVING COUNT(*) > 3` y `UPDATE ... FROM` (RN-06) |

#### 6.2.3 Borrado (D1 a D6)

| Código | Objetivo | Técnica destacada |
|---|---|---|
| D1 | Borrar comprobantes de socios con más de 5 años | Tabla temporal, `DELETE ... USING` y cascada a `DetalleVenta` |
| D2 | Eliminar cepas sin uso en vinos ni parcelas | Doble `NOT EXISTS`; en el dataset afecta 0 filas |
| D3 | Eliminar empleados con menos de 2 años de una sala dada de baja | `fn_antiguedad_anios` y control de `ON DELETE SET NULL` en `Localidad.cuit_encargado` |
| D4 | Borrar socios sin compras con alta mayor a 5 años | `NOT EXISTS` y cascada a `SocioClub` |
| D5 | Eliminar ingresos procesados de hace más de 365 días | Tabla temporal y cascada a `DetalleIngreso`; RN-12 permite el borrado en cascada |
| D6 | Borrar socios sin compras de una localidad | `NOT EXISTS` y cascada a `SocioClub` |

#### 6.2.4 Consultas (S1 a S12)

| Código | Objetivo | Técnica destacada |
|---|---|---|
| S1 | Top 10 de vinos por botellas vendidas en toda la red | `ROW_NUMBER()` y agregación |
| S2 | Vinos vendidos en todas las salas | División relacional con `HAVING COUNT(DISTINCT ...) = (SELECT COUNT(*) ...)` |
| S3 | Clientes por tipo en una sala durante la última semana | `JOIN`, `GROUP BY` e intervalo con `CURRENT_DATE` |
| S4 | Top 5 de salas por botellas de un vino en los últimos 15 días | CTE, `SUM` y `LIMIT` |
| S5 | Salas con menos transferencias pendientes | CTE, `LEFT JOIN` y subconsulta con `MIN` |
| S6 | Vinos sin stock en la sala pero con stock en el depósito | `LEFT JOIN` y `COALESCE` |
| S7 | Transportista con mayor actividad del último mes | CTE con agregados y `LIMIT 1` |
| S8 | Monto de ventas por sala en el último trimestre | `JOIN`, `SUM` y `GROUP BY` |
| S9 | Ficha completa de un vino | CTE, `STRING_AGG` y la vista `vw_stock_total_vino` |
| S10 | Rendimiento en kg/ha por parcela y campaña | CTE, subconsulta correlacionada y `CASE` |
| S11 | Ranking por sala y ventas acumuladas mensuales | `RANK() OVER (PARTITION BY ...)` y `SUM() OVER (...)` |
| S12 | Clientes que compraron todos los vinos de una bodega y clientes que nunca compraron tintos | División con `NOT EXISTS` y anti-join con `LEFT JOIN ... IS NULL` |

### 6.3 Técnicas SQL y coherencia con el modelo

Las consultas ejercitan los mecanismos definidos en las etapas anteriores:

- **CTE y subconsultas:** separan el cálculo de rankings, promedios y conjuntos objetivo antes del DML.
- **Funciones de ventana:** `ROW_NUMBER`, `RANK` y `SUM ... OVER` resuelven rankings, particiones y acumulados sin bucles.
- **División relacional y anti-joins:** S2, S12 y D2 expresan «todos» y «ninguno» con `COUNT`, `NOT EXISTS` y `LEFT JOIN ... IS NULL`.
- **Operaciones set-based:** U1 recalcula los 150.000 comprobantes en una sola sentencia; U4 intercambia dos valores con un único `CASE`.
- **Reutilización de la lógica de la base:** I3 e I6 se apoyan en los triggers y funciones de la Etapa 2; U2, U3, U5 y U6 dependen de `fn_antiguedad_anios`, del trigger de auditoría y de las reglas de descuento.
- **Acciones referenciales:** D1, D4, D5 y D6 verifican las cascadas; D3 controla el `SET NULL` de `Localidad.cuit_encargado`.

### 6.4 Límites y observaciones

- La Etapa 4 ya cuenta con `db/migrations/008_indices.sql` y mediciones con `EXPLAIN (ANALYZE, BUFFERS)` documentadas en `docs/informe.md`; aquí no se repiten esos planes.
- Las consultas con `CURRENT_DATE` dependen de la fecha de ejecución; por eso `db/seed/README.md` recomienda recargar el dataset con una fecha base próxima a la defensa.
- `consultas/salida_select_local.txt` es una salida local de referencia, no una fuente normativa. El SQL de `consultas/` es la fuente de verdad.
- Los archivos `insert.sql`, `update.sql` y `delete.sql` revierten sus cambios con `ROLLBACK`; su objetivo es demostrar el comportamiento, no persistir datos.

---

## 7. Front de la Etapa 7

El front se implementó en `front/` como una SPA con React 19, Vite 8, TypeScript 5.9, React Router 7 y Recharts 3. Usa CSS propio, sin framework de componentes. La compilación se hace con `npm run build`; Nginx sirve `dist/` y proxifica `location /api/` hacia `http://api:8000/`, de modo que el navegador usa un único origen y no necesita CORS en producción.

### 7.1 Pantallas

| Pantalla | Ruta | Función |
|---|---|---|
| Catálogo | `/vinos` | Listado paginado, búsqueda y filtros por tipo, cepa, bodega y añada; detalle con cepas, maridajes y stock |
| Alta/edición de vino | `/vinos/nuevo`, `/vinos/:codigo/editar` | Formulario con bodega, composición de cepas y maridajes; en edición carga la ficha y envía `PATCH` |
| Nueva venta | `/ventas/nueva` | Selección de cliente y sala, búsqueda de vinos, carrito, cotización y confirmación |
| Transferencias | `/transferencias` | Listado filtrado, alta, detalle, renglones y transición `terminar`/`procesar` |
| Tablero | `/tablero` | S4 y S13 con Recharts; S14 con selector de sala |

El catálogo y las pantallas de venta y transferencias muestran mensajes de error de la API sin reinterpretarlos. La pantalla de alta/edición muestra la suma de porcentajes como ayuda, pero no bloquea el envío: la validación definitiva de que los cortes suman 100 sigue en el `CONSTRAINT TRIGGER` diferido de la base.

### 7.2 Arquitectura del front

| Archivo | Responsabilidad |
|---|---|
| `front/src/api/client.ts` | `fetch` con base `VITE_API_BASE_URL ?? '/api'`; `ApiError` conserva `status`, `detail` y `sqlstate` |
| `front/src/api/endpoints.ts` | Funciones tipadas para vinos, clientes, catálogos, comprobantes, transferencias y reportes |
| `front/src/api/types.ts` | Contratos de la API compartidos por las pantallas |
| `front/src/context/CatalogosContext.tsx` | Carga única de bodegas, cepas, maridajes, salas y depósitos |
| `front/src/components/` | `Layout`, avisos, spinner, estado vacío, paginación y badge de estado |
| `front/src/lib/` | Formateo de moneda, fecha y números; debounce; nombres de sala y depósito |
| `front/src/pages/` | Las cinco pantallas y el formulario de alta/edición |
| `front/vite.config.ts` | Proxy de desarrollo `/api` hacia `127.0.0.1:8001` |
| `front/Dockerfile` | Build multietapa Node 22 + Nginx 1.29 |
| `front/nginx.conf` | Fallback de SPA y proxy `/api/` hacia `api:8000` |

La única lógica de cálculo del front es de presentación: formatear importes y mostrar cantidades. No multiplica precios por cantidades ni aplica descuentos. El subtotal, el descuento, el total y los subtotales de renglón llegan calculados por la API.

### 7.3 Endpoints agregados para el front

| Método | Ruta | Uso |
|---|---|---|
| `GET` | `/catalogos/bodegas`, `/cepas`, `/maridajes`, `/salas`, `/depositos` | Poblar selects y formularios |
| `GET` | `/vinos?cepa=&anada=` | Filtros del catálogo por nombre de cepa y añada |
| `POST` | `/comprobantes/cotizar` | Cotización sin persistencia para la pantalla de venta |
| `GET` | `/transferencias?estado=&page=&limit=` | Listado paginado y filtrado de transferencias |
| `GET` | `/reportes/s13-ventas-sala-trimestre` | Ventas por sala de los últimos tres meses |
| `GET` | `/reportes/s14-vinos-sin-stock-sala?id_sala=` | Vinos con stock cero en una sala; 404 si la sala no existe |

`POST /comprobantes/cotizar` inserta el comprobante y sus renglones dentro de una transacción, deja que los triggers calculen los importes y hace rollback con `_QuoteRollback`. No persiste datos, pero consume un número de secuencia; por eso los números de comprobante pueden tener huecos. Es una consecuencia aceptada del enfoque de reutilizar la lógica de la base sin duplicarla en el front.

Además, `api/requirements.txt` usa `psycopg[binary,pool]` para que la imagen `python:3.12-slim` incluya el binario de `libpq` y no dependa de una biblioteca del sistema.

### 7.4 Verificación

| Control | Resultado |
|---|---|
| `cd front && npm run build` | Correcto; `tsc -b` y Vite generan `dist/` (410 módulos, bundle de 667 kB) |
| `python -m pytest -q` en el contenedor API | 17 pruebas aprobadas |
| `docker compose build front api` | Ambas imágenes construidas |
| `docker compose up -d` | `db`, `db-init`, `api` y `front`; `front` queda `healthy` |
| `GET http://localhost:8080/api/salud` | `{"status":"ok","database":"bodega"}` |
| `GET /api/reportes/s13-ventas-sala-trimestre` | 200 con datos |
| `GET /api/reportes/s14-vinos-sin-stock-sala?id_sala=2` | 200 con vinos de stock cero |
| `POST /api/comprobantes/cotizar` | Devuelve totales; el conteo de `ComprobanteVenta` no cambia (15000 → 15000) |
| Fallback de SPA | `GET /vinos/nuevo` devuelve el `index.html` de la SPA |

Quedan dos avisos no bloqueantes: Vite informa un bundle principal de 667 kB y Starlette advierte que `httpx` será reemplazado por `httpx2` en una versión futura. No afectan la compilación ni las pruebas actuales.

## 8. Estado de las etapas restantes y trabajo futuro

| Etapa | Estado | Evidencia o pendiente |
|---|---|---|
| 4. Índices y rendimiento | Implementada | `db/migrations/008_indices.sql`, mediciones y planes en `docs/informe.md` |
| 6. API REST | Implementada | `api/`, traducción de SQLSTATE, paginación y 17 pruebas |
| 7. Front | Implementada | `front/`, build de producción y cinco pantallas; integración verificada por HTTP |
| 8. Despliegue | Parcial | Stack local con `docker-compose.yml`; faltan nube, backups operativos y conexión cifrada de producción |
| 9. Documentación y defensa | Parcial | Este informe, `docs/informe.md` y `docs/capturas/`; falta la demo en vivo |

Trabajo futuro recomendado: dividir el bundle del front con importaciones dinámicas, migrar la prueba de API a `httpx2` cuando el ecosistema lo estabilice, agregar autenticación si el alcance lo exige, definir backups y restauración para un entorno real y regenerar el volcado si se cambia la lógica de descuentos.

## 9. Conclusiones

El repositorio implementa un modelo relacional normalizado hasta 3FN, con claves naturales y subrogadas justificadas, una jerarquía de clientes resuelta por supertipo y subtipos, atributos derivados persistidos y protegidos por funciones y triggers, y políticas referenciales orientadas a preservar el historial. La lógica de las Etapas 1 y 2 se complementa con la carga masiva de la Etapa 3, los índices de la Etapa 4, las consultas DML y DQL de la Etapa 5, la API de la Etapa 6 y el front de la Etapa 7.

**Resultados verificables.** El esquema tiene 31 tablas, 1 tipo enumerado, 1 dominio, 4 funciones de cálculo, 2 procedimientos, 11 triggers, 3 vistas y 3 roles. Las 15 reglas de negocio tienen al menos un mecanismo en la base y un caso de prueba. La carga alcanza 745.569 filas, supera el mínimo de 100.000 y deja los 15 controles del cargador y los 22 controles independientes en cero. Las 30 consignas de la Etapa 5 se ejecutan dentro de transacciones que revierten los cambios de DML. La API tiene 17 pruebas aprobadas y el front compila y se sirve a través de Nginx con el proxy `/api/`.

**Qué funcionó bien.** Concentrar las reglas en la base evita que la aplicación pueda saltearlas y permitió que el front no duplicara totales, descuentos ni stock. Los `CONSTRAINT TRIGGER` diferidos resolvieron la composición de cepas sin exigir un orden artificial de inserción. Los procedimientos transaccionales mantuvieron atómicas las operaciones de ingreso y transferencia. La cotización reutiliza la lógica real de venta y revierte la transacción, de modo que el usuario ve el total definitivo sin persistir un comprobante incompleto.

**Límites y decisiones a revisar.** La correspondencia entre `Cliente.tipo_cliente` y su subtipo no está impuesta por el esquema; requeriría un trigger o una restricción adicional. El volcado versionado debe regenerarse cada vez que cambien las funciones, los triggers o los datos, y verificarse con su checksum. El despliegue es local, no en nube, y no incluye backups operativos ni conexión cifrada de producción. La cotización consume números de secuencia aunque haga rollback. Durante la carga se deshabilitan triggers operativos, por lo que el cálculo de totales se duplica en Python y debe mantenerse sincronizado con las funciones y triggers de la Etapa 2.

**Aprendizajes.** La elección entre `CHECK`, FK, trigger, función y procedimiento depende de si la regla involucra una fila, varias filas, un agregado o una transición de estado. La prueba de concurrencia mostró que un `SELECT` normal no alcanza para proteger el stock y que el `FOR UPDATE` del trigger es la barrera efectiva. La comparación `COPY` / `executemany` / `individual` mostró una diferencia de un orden de magnitud, y la semilla fija con fecha base configurable hizo reproducible un dataset de más de 700.000 filas.

---

## Anexo A. Trazabilidad RN-01 a RN-15

| Regla | Mecanismo en la base | Caso de prueba |
|---|---|---|
| RN-01 | `precio_venta` como atributo único de `Vino` (un solo precio para toda la red) y `CHECK (precio_venta > 0)` | `db/tests/db_tests.sql`, sección RN-01 |
| RN-02 | FK `SalaDeVenta.id_localidad`, `Localidad.cuit_encargado` y diseño normalizado | Sección RN-02 |
| RN-03 | FK `Empleado.id_sala` con `NOT NULL` | Sección RN-03 |
| RN-04 | FK `Parcela.id_cepa` y `UNIQUE (id_finca, nro_parcela, campania)` en `LoteUva` | Sección RN-04 |
| RN-05 | `trg_vinocepa_suma_100` y `trg_vino_suma_100` (constraint trigger diferido) | Sección RN-05 |
| RN-06 | `fn_descuento_cliente`, `CHECK (descuento_porcentaje BETWEEN 0 AND 100)` y `trg_renglon_1_completar` | Sección RN-06 |
| RN-07 | FK `PermisoExportacion.id_cliente → Exportador` y `CHECK (fecha_vencimiento > fecha_emision)` | Sección RN-07 |
| RN-08 | `fn_total_comprobante`, `trg_renglon_1_completar` y `trg_renglon_3_stock_y_totales` | Sección RN-08 |
| RN-09 | `trg_renglon_2_valida_stock`, `trg_renglon_3_stock_y_totales` y `CHECK (cantidad >= 0)` en stock | Sección RN-09 |
| RN-10 | `sp_procesar_ingreso` y `trg_ingreso_estado` | Sección RN-10 |
| RN-11 | `sp_procesar_transferencia`, `trg_transferencia_estado` y `trg_transferencia_fecha` | Sección RN-11 |
| RN-12 | `trg_detalle_ingreso_bloqueo` y `trg_detalle_transferencia_bloqueo` | Sección RN-12 |
| RN-13 | `trg_vino_auditoria_precio` y tabla `AuditoriaPrecio` | Sección RN-13 |
| RN-14 | FK con `ON DELETE RESTRICT` en `Vino`, `Bodega` y `Transportista` | Sección RN-14 |
| RN-15 | `CHECK` de cantidades, precios, superficies, kilos, graduación y stock | Sección RN-15 |

Cada caso de `db/tests/db_tests.sql` incluye comentarios con el error esperado y el SQLSTATE cuando corresponde. Los casos que deben fallar se ejecutan dentro de `SAVEPOINT` y se revierten para no dejar datos inconsistentes.
