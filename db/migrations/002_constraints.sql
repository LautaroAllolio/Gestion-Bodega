/* ---------------------------------------------------- */
/* 002_constraints.sql - Constraints y reglas de integridad */
/* Ejecutar despues de 001_esquema.sql (PostgreSQL 14+)   */
/* ---------------------------------------------------- */

/* UNIQUE adicionales a las PK */

ALTER TABLE Localidad 
  ADD CONSTRAINT Uq_localidad_nombre_provincia UNIQUE (nombre, provincia);

ALTER TABLE LoteUva 
  ADD CONSTRAINT Lote_Uva_campania UNIQUE (id_finca,nro_parcela,campania);

ALTER TABLE SocioClub 
  ADD CONSTRAINT Uq_socio_numero UNIQUE (numero_socio);

ALTER TABLE Transportista 
  ADD CONSTRAINT Uq_transportista_cuit UNIQUE (cuit);

ALTER TABLE Vino ADD CONSTRAINT Uq_vino_nombre_anada_presentacion
	UNIQUE (nombre_comercial, anada, presentacion_ml);

/* CHECK de integridad */

ALTER TABLE AuditoriaPrecio ADD CONSTRAINT Check_Auditoria_precioAnterior CHECK (precio_anterior > 0);

ALTER TABLE AuditoriaPrecio ADD CONSTRAINT Check_Auditoria_precioPosterior CHECK (precio_nuevo > 0);

ALTER TABLE Cepa ADD CONSTRAINT Check_cepa_tipo CHECK (tipo IN ('Tinta', 'Blanca', 'Rosada'));

ALTER TABLE Cliente ADD CONSTRAINT Check_cliente_tipo CHECK (tipo_cliente IN ('Socio', 'Distribuidor', 'Exportador'));

ALTER TABLE Cliente ADD CONSTRAINT Check_cliente_descuento CHECK (descuento_porcentaje BETWEEN 0 AND 100);

ALTER TABLE ComprobanteVenta ADD CONSTRAINT Check_comprobante_subtotal CHECK (subtotal >= 0);

ALTER TABLE ComprobanteVenta ADD CONSTRAINT Check_comprobante_total CHECK (total >= 0);

ALTER TABLE DetalleIngreso ADD CONSTRAINT Check_DetalleIngreso_cantidad CHECK (cantidad_botellas > 0);

ALTER TABLE DetalleTransferencia ADD CONSTRAINT Check_detalleT_cantidad CHECK (cantidad > 0);

ALTER TABLE DetalleVenta ADD CONSTRAINT Check_DetalleVenta_cantidad CHECK (cantidad > 0);

ALTER TABLE DetalleVenta ADD CONSTRAINT Check_detalleVenta_precio CHECK (precio_unitario > 0);

ALTER TABLE DetalleVenta ADD CONSTRAINT Check_DetalleVenta_subtotal CHECK (subtotal > 0);

ALTER TABLE Empleado ADD CONSTRAINT Check_empleado_salario CHECK (salario > 0);

ALTER TABLE Finca ADD CONSTRAINT Check_finca_superficie CHECK (superficie_total > 0);

ALTER TABLE LoteUva ADD CONSTRAINT Check_lote_kilos CHECK (kilos > 0);

ALTER TABLE Maridaje ADD CONSTRAINT Check_maridaje_temperatura CHECK (temperatura_servicio BETWEEN 5 AND 25);

ALTER TABLE Parcela ADD CONSTRAINT Check_parcela_superficie CHECK (superficie > 0);

ALTER TABLE Parcela ADD CONSTRAINT Check_parcela_anio_plantacion CHECK (anio_plantacion BETWEEN 1900 AND 2100);

ALTER TABLE PermisoExportacion ADD CONSTRAINT Check_permiso_fechas CHECK (fecha_vencimiento > fecha_emision);

ALTER TABLE SalaDeVenta ADD CONSTRAINT Check_dia_cierre CHECK (dia_cierre IN ('Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo', 'Ninguno'));

ALTER TABLE StockDeposito ADD CONSTRAINT Check_StockDeposito_cantidad CHECK (cantidad >= 0);

ALTER TABLE StockSala ADD CONSTRAINT Check_StockSala_cantidad CHECK (cantidad >= 0);

ALTER TABLE Vino ADD CONSTRAINT Check_vino_alcohol CHECK (graduacion_alcoholica BETWEEN 5 AND 20);

ALTER TABLE Vino ADD CONSTRAINT Check_vino_anios CHECK (anada BETWEEN 1900 AND 2100);

ALTER TABLE Vino ADD CONSTRAINT Check_vino_tipo CHECK (tipo IN ('Tinto', 'Blanco', 'Rosado', 'Espumante'));

ALTER TABLE Vino ADD CONSTRAINT Check_vino_precio CHECK (precio_venta > 0);

ALTER TABLE VinoCepa ADD CONSTRAINT Check_vinocepa_porcentaje CHECK (porcentaje_corte > 0 AND porcentaje_corte <= 100);

/* DEFAULTs solicitados */

ALTER TABLE Ingreso ALTER COLUMN estado SET DEFAULT 'en_confeccion';
ALTER TABLE Transferencia ALTER COLUMN estado SET DEFAULT 'en_confeccion';
ALTER TABLE Cliente ALTER COLUMN fecha_alta SET DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE AuditoriaPrecio ALTER COLUMN fecha_hora SET DEFAULT CURRENT_TIMESTAMP;

/* Acciones referenciales ON DELETE / ON UPDATE */

ALTER TABLE AuditoriaPrecio DROP CONSTRAINT FK_AuditoriaPrecio_Vino;
ALTER TABLE AuditoriaPrecio ADD CONSTRAINT FK_AuditoriaPrecio_Vino
    FOREIGN KEY (codigo_vino) REFERENCES Vino (codigo_vino) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE Cliente DROP CONSTRAINT FK_Cliente_Localidad;
ALTER TABLE Cliente ADD CONSTRAINT FK_Cliente_Localidad
    FOREIGN KEY (id_localidad) REFERENCES Localidad (id_localidad) ON DELETE Restrict ON UPDATE No Action;

ALTER TABLE ComprobanteVenta DROP CONSTRAINT FK_ComprobanteVenta_Cliente;
ALTER TABLE ComprobanteVenta ADD CONSTRAINT FK_ComprobanteVenta_Cliente
    FOREIGN KEY (id_cliente) REFERENCES Cliente (id_cliente) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE ComprobanteVenta DROP CONSTRAINT FK_ComprobanteVenta_SalaDeVenta;
ALTER TABLE ComprobanteVenta ADD CONSTRAINT FK_ComprobanteVenta_SalaDeVenta
    FOREIGN KEY (id_sala) REFERENCES SalaDeVenta (id_sala) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE DetalleIngreso DROP CONSTRAINT FK_DetalleIngreso_Ingreso;
ALTER TABLE DetalleIngreso ADD CONSTRAINT FK_DetalleIngreso_Ingreso
    FOREIGN KEY (id_ingreso) REFERENCES Ingreso (id_ingreso) ON DELETE Cascade ON UPDATE Cascade;

ALTER TABLE DetalleIngreso DROP CONSTRAINT FK_DetalleIngreso_Vino;
ALTER TABLE DetalleIngreso ADD CONSTRAINT FK_DetalleIngreso_Vino
    FOREIGN KEY (codigo_vino) REFERENCES Vino (codigo_vino) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE DetalleTransferencia DROP CONSTRAINT FK_DetalleTransferencia_Transferencia;
ALTER TABLE DetalleTransferencia ADD CONSTRAINT FK_DetalleTransferencia_Transferencia
    FOREIGN KEY (nro_transferencia) REFERENCES Transferencia (nro_transferencia) ON DELETE Cascade ON UPDATE Cascade;

ALTER TABLE DetalleTransferencia DROP CONSTRAINT FK_DetalleTransferencia_Vino;
ALTER TABLE DetalleTransferencia ADD CONSTRAINT FK_DetalleTransferencia_Vino
    FOREIGN KEY (codigo_vino) REFERENCES Vino (codigo_vino) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE DetalleVenta DROP CONSTRAINT FK_DetalleVenta_ComprobanteVenta;
ALTER TABLE DetalleVenta ADD CONSTRAINT FK_DetalleVenta_ComprobanteVenta
    FOREIGN KEY (nro_comprobante) REFERENCES ComprobanteVenta (nro_comprobante) ON DELETE Cascade ON UPDATE Cascade;

ALTER TABLE DetalleVenta DROP CONSTRAINT FK_DetalleVenta_Vino;
ALTER TABLE DetalleVenta ADD CONSTRAINT FK_DetalleVenta_Vino
    FOREIGN KEY (codigo_vino) REFERENCES Vino (codigo_vino) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE Distribuidor DROP CONSTRAINT FK_Distribuidor_Cliente;
ALTER TABLE Distribuidor ADD CONSTRAINT FK_Distribuidor_Cliente
    FOREIGN KEY (id_cliente) REFERENCES Cliente (id_cliente) ON DELETE Cascade ON UPDATE No Action;

ALTER TABLE Empleado DROP CONSTRAINT FK_id_sala;
ALTER TABLE Empleado ADD CONSTRAINT FK_id_sala
    FOREIGN KEY (id_sala) REFERENCES SalaDeVenta (id_sala) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE Exportador DROP CONSTRAINT FK_Exportador_Cliente;
ALTER TABLE Exportador ADD CONSTRAINT FK_Exportador_Cliente
    FOREIGN KEY (id_cliente) REFERENCES Cliente (id_cliente) ON DELETE Cascade ON UPDATE No Action;

ALTER TABLE Finca DROP CONSTRAINT FK_Finca_Departamento;
ALTER TABLE Finca ADD CONSTRAINT FK_Finca_Departamento
    FOREIGN KEY (id_departamento) REFERENCES Departamento (id_departamento) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE Ingreso DROP CONSTRAINT FK_Ingreso_Bodega;
ALTER TABLE Ingreso ADD CONSTRAINT FK_Ingreso_Bodega
    FOREIGN KEY (cuit_bodega) REFERENCES Bodega (cuit) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE Ingreso DROP CONSTRAINT FK_Ingreso_DepositoCentral;
ALTER TABLE Ingreso ADD CONSTRAINT FK_Ingreso_DepositoCentral
    FOREIGN KEY (id_deposito) REFERENCES DepositoCentral (id_deposito) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE Ingreso DROP CONSTRAINT FK_Ingreso_Transportista;
ALTER TABLE Ingreso ADD CONSTRAINT FK_Ingreso_Transportista
    FOREIGN KEY (id_transporte) REFERENCES Transportista (id_transporte) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE Localidad DROP CONSTRAINT FK_Cuit_Empleado;
ALTER TABLE Localidad ADD CONSTRAINT FK_Cuit_Empleado
    FOREIGN KEY (cuit_encargado) REFERENCES Empleado (cuit)
    ON DELETE Restrict ON UPDATE Cascade
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE LoteUva DROP CONSTRAINT FK_LoteUva_Bodega;
ALTER TABLE LoteUva ADD CONSTRAINT FK_LoteUva_Bodega
    FOREIGN KEY (cuit_bodega) REFERENCES Bodega (cuit) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE LoteUva DROP CONSTRAINT FK_LoteUva_Parcela;
ALTER TABLE LoteUva ADD CONSTRAINT FK_LoteUva_Parcela
    FOREIGN KEY (nro_parcela,id_finca) REFERENCES Parcela (nro_parcela,id_finca) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE Parcela DROP CONSTRAINT FK_Parcela_cepa;
ALTER TABLE Parcela ADD CONSTRAINT FK_Parcela_cepa
    FOREIGN KEY (id_cepa) REFERENCES Cepa (id_cepa) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE Parcela DROP CONSTRAINT FK_Parcela_Finca;
ALTER TABLE Parcela ADD CONSTRAINT FK_Parcela_Finca
    FOREIGN KEY (id_finca) REFERENCES Finca (id_finca) ON DELETE Cascade ON UPDATE No Action;

ALTER TABLE PermisoExportacion DROP CONSTRAINT FK_PermisoExportacion_Exportador;
ALTER TABLE PermisoExportacion ADD CONSTRAINT FK_PermisoExportacion_Exportador
    FOREIGN KEY (id_cliente) REFERENCES Exportador (id_cliente) ON DELETE Cascade ON UPDATE No Action;

ALTER TABLE SalaDeVenta DROP CONSTRAINT FK_SalaDeVenta_Localidad;
ALTER TABLE SalaDeVenta ADD CONSTRAINT FK_SalaDeVenta_Localidad
    FOREIGN KEY (id_localidad) REFERENCES Localidad (id_localidad) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE SocioClub DROP CONSTRAINT FK_SocioClub_Cliente;
ALTER TABLE SocioClub ADD CONSTRAINT FK_SocioClub_Cliente
    FOREIGN KEY (id_cliente) REFERENCES Cliente (id_cliente) ON DELETE Cascade ON UPDATE No Action;

ALTER TABLE StockDeposito DROP CONSTRAINT FK_StockDeposito_DepositoCentral;
ALTER TABLE StockDeposito ADD CONSTRAINT FK_StockDeposito_DepositoCentral
    FOREIGN KEY (id_deposito) REFERENCES DepositoCentral (id_deposito) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE StockDeposito DROP CONSTRAINT FK_StockDeposito_Vino;
ALTER TABLE StockDeposito ADD CONSTRAINT FK_StockDeposito_Vino
    FOREIGN KEY (codigo_vino) REFERENCES Vino (codigo_vino) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE StockSala DROP CONSTRAINT FK_StockSala_SalaDeVenta;
ALTER TABLE StockSala ADD CONSTRAINT FK_StockSala_SalaDeVenta
    FOREIGN KEY (id_sala) REFERENCES SalaDeVenta (id_sala) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE StockSala DROP CONSTRAINT FK_StockSala_Vino;
ALTER TABLE StockSala ADD CONSTRAINT FK_StockSala_Vino
    FOREIGN KEY (codigo_vino) REFERENCES Vino (codigo_vino) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE Transferencia DROP CONSTRAINT FK_Transferencia_DepositoCentral;
ALTER TABLE Transferencia ADD CONSTRAINT FK_Transferencia_DepositoCentral
    FOREIGN KEY (id_deposito) REFERENCES DepositoCentral (id_deposito) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE Transferencia DROP CONSTRAINT FK_Transferencia_SalaDeVenta;
ALTER TABLE Transferencia ADD CONSTRAINT FK_Transferencia_SalaDeVenta
    FOREIGN KEY (id_sala_solicitante) REFERENCES SalaDeVenta (id_sala) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE TransportistaLocalidad DROP CONSTRAINT FK_TransportistaLocalidad_Localidad;
ALTER TABLE TransportistaLocalidad ADD CONSTRAINT FK_TransportistaLocalidad_Localidad
    FOREIGN KEY (id_localidad) REFERENCES Localidad (id_localidad) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE TransportistaLocalidad DROP CONSTRAINT FK_TransportistaLocalidad_Transportista;
ALTER TABLE TransportistaLocalidad ADD CONSTRAINT FK_TransportistaLocalidad_Transportista
    FOREIGN KEY (id_transporte) REFERENCES Transportista (id_transporte) ON DELETE Cascade ON UPDATE No Action;

ALTER TABLE Vino DROP CONSTRAINT FK_Vino_Bodega;
ALTER TABLE Vino ADD CONSTRAINT FK_Vino_Bodega
    FOREIGN KEY (cuit_bodega) REFERENCES Bodega (cuit) ON DELETE Restrict ON UPDATE Cascade;

ALTER TABLE VinoCepa DROP CONSTRAINT FK_VinoCepa_cepa;
ALTER TABLE VinoCepa ADD CONSTRAINT FK_VinoCepa_cepa
    FOREIGN KEY (id_cepa) REFERENCES Cepa (id_cepa) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE VinoCepa DROP CONSTRAINT FK_VinoCepa_Vino;
ALTER TABLE VinoCepa ADD CONSTRAINT FK_VinoCepa_Vino
    FOREIGN KEY (codigo_vino) REFERENCES Vino (codigo_vino) ON DELETE Cascade ON UPDATE Cascade;

ALTER TABLE VinoMaridaje DROP CONSTRAINT FK_VinoMaridaje_Maridaje;
ALTER TABLE VinoMaridaje ADD CONSTRAINT FK_VinoMaridaje_Maridaje
    FOREIGN KEY (id_maridaje) REFERENCES Maridaje (id_maridaje) ON DELETE No Action ON UPDATE No Action;

ALTER TABLE VinoMaridaje DROP CONSTRAINT FK_VinoMaridaje_Vino;
ALTER TABLE VinoMaridaje ADD CONSTRAINT FK_VinoMaridaje_Vino
    FOREIGN KEY (codigo_vino) REFERENCES Vino (codigo_vino) ON DELETE Cascade ON UPDATE Cascade;


ALTER TABLE AnalisisCalidad DROP CONSTRAINT FK_AnalisisCalidad_LoteUva;

ALTER TABLE AnalisisCalidad ADD CONSTRAINT FK_AnalisisCalidad_LoteUva
    FOREIGN KEY (id_lote) REFERENCES LoteUva (id_lote)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;