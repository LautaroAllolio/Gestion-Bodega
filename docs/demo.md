# Demo en vivo

Guion de la demostración de 10 a 15 minutos para la defensa. Corre sobre el despliegue local con Docker Compose; el despliegue en la nube (Etapa 8) queda como trabajo futuro y esta demo usa el mismo stack que `docker-compose.yml`.

## Preparación (el día anterior)

1. Reconstruir las imágenes y levantar el stack para confirmar que arranca limpio:

   ```powershell
   docker compose build
   docker compose up -d
   docker compose ps
   ```

   Los cuatro servicios deben quedar: `db` (healthy), `db-init` (exited 0), `api` (running) y `front` (healthy).

2. Verificar los accesos:

   ```powershell
   curl http://localhost:8080/api/salud
   # {"status":"ok","database":"bodega"}
   ```

3. Fijar datos de ejemplo para no improvisar IDs en vivo:

   ```powershell
   docker compose exec db psql -U postgres -d bodega -c "SELECT codigo_vino, nombre_comercial FROM Vino WHERE codigo_vino LIKE 'V001%' ORDER BY codigo_vino LIMIT 3;"
   docker compose exec db psql -U postgres -d bodega -c "SELECT id_cliente, apellido, tipo_cliente FROM Cliente WHERE tipo_cliente='Socio' ORDER BY id_cliente LIMIT 3;"
   docker compose exec db psql -U postgres -d bodega -c "SELECT id_sala, calle, numero_calle FROM SalaDeVenta ORDER BY id_sala LIMIT 5;"
   ```

4. Dejar abiertos: el navegador en `http://localhost:8080`, una terminal con `docker compose ps` y otra con `psql` dentro del contenedor (`docker compose exec db psql -U postgres -d bodega`).

5. Plan B: si Docker falla, las capturas de `docs/capturas/` cubren los mismos escenarios y el volcado `db/dump_completo.sql.gz` permite restaurar `bodega_seed` en el PostgreSQL local del notebook (procedimiento en `README.md`).

## Guion (12 minutos)

| Minuto | Pantalla / acción | Qué mostrar | Idea clave para decir |
|---|---|---|---|
| 0:00 | `docker compose ps` | Los 4 servicios y su estado; healthcheck de `db` y `front` | Un solo comando levanta base, migraciones, datos, API y front |
| 0:30 | Front `/vinos` | Catálogo con filtros (texto, cepa, bodega, añada) y paginación | El front no calcula nada: consume la API, que consulta la base |
| 1:30 | Ficha de un vino | Detalle con cepas, maridajes y stock (depósito y salas) | El stock sale de `vw_stock_total_vino`; la composición respeta RN-05 |
| 3:00 | Front `/ventas/nueva` | Elegir socio, sala y carrito; la cotización se recalcula sola | `POST /comprobantes/cotizar` corre la lógica real de venta y hace rollback: el total mostrado es el definitivo |
| 4:00 | Confirmar la venta | El comprobante persiste y el stock de la sala baja | Los triggers completan precio, descuento, subtotal y total (RN-06/08/09) |
| 4:30 | Venta sin stock | Agregar más botellas que el stock disponible | La base rechaza con `P0001`; la API lo traduce a 409 y el front muestra el detalle |
| 5:30 | Front `/clientes` | Crear un exportador; cargar 3 permisos de exportación | El descuento queda en 30 % (RN-06) |
| 6:30 | Cuarto permiso | Alta del 4.º permiso | `trg_sincronizar_descuento_exportador` sube el descuento a 35 % sin tocar nada a mano (migración `009`) |
| 7:00 | Borrar un permiso | El descuento vuelve a 30 % | La regla vive en la base, no en la API ni en el front |
| 7:30 | Front `/transferencias` | Alta, renglones, `terminar` y `procesar` | El stock pasa del depósito a la sala dentro de un procedimiento transaccional (`sp_procesar_transferencia`) |
| 8:30 | Reprocesar | Intentar procesar de nuevo | La transición de estados rechaza el retroceso (RN-11) |
| 9:00 | Front `/tablero` | S13 y S14 con Recharts | Los reportes son vistas SQL expuestas por la API |
| 9:30 | Terminal: `psql` | `\df`, `\dy` o consultar una vista; contar filas | 5 funciones, 13 triggers, 3 vistas y 2 procedimientos: la lógica de negocio está en la base |
| 10:30 | Controles finales | Ejecutar `db/tests/verificacion_etapa3.sql` (comando abajo) | 23 controles en cero sobre la base que acaba de modificarse en vivo |
| 11:30 | Cierre | `README.md` en pantalla | Puesta en marcha, dump con SHA-256 y estructura del repo |

### Comando de los controles finales

```powershell
cmd /c "docker compose exec -T db psql -U postgres -d bodega -v ON_ERROR_STOP=1 < db\tests\verificacion_etapa3.sql"
```

Debe terminar con `Verificación OK: todos los controles en cero.`

## Reglas de la demo

- No escribir SQL a mano salvo lo previsto: los ejercicios de modificación en vivo están en `docs/defensa_oral.md` y los corre cada integrante en su tramo.
- Los cambios de la demo (venta y transferencia) quedan persistidos: no importa, la base es de prueba. Si se quiere volver al estado original, `FORCE_RELOAD=1 docker compose up -d db-init` recarga el dataset completo.
- Si algo tarda (primera consulta, build de imágenes), mostrar la terminal de `docker compose logs -f api` mientras espera.

## Nota sobre la nube

La Etapa 8 está implementada como despliegue local reproducible. La sección "Despliegue en la nube" del `README.md` quedó como marcador de posición: si la demo se concreta sobre un despliegue en la nube, este guion no cambia; solo se reemplazan `localhost` por la URL pública y los comandos `docker compose` por los del proveedor.
