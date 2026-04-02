-- Active: 1760978807635@@127.0.0.1@3306@mysql
-- ============================================================
-- RBE - Rutas Baja Express
-- Script estructura
-- Actualizado: Abril 2 del 2026
-- Usuario de prueba supervisor: rodavlas / 172509
-- Cambios v3:
--   · Nueva columna: 'foto' agregada a la tabla taquillero.
--   · Nuevos Triggers: 
--       - trg_antes_vender_ticket (evita sobreventa de asientos).
--       - trg_validar_licencia_conductor (bloquea licencias vencidas).
--       - trg_evitar_pasajero_duplicado (bloquea registros idénticos).
--   · Nuevo Procedimiento Almacenado: 
--       - sp_obtener_o_crear_pasajero (busca pasajero existente o crea uno nuevo devolviendo su ID).
-- ============================================================

DROP DATABASE IF EXISTS rbe;
CREATE DATABASE rbe CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE rbe;

-- ── Tablas ────────────────────────────────────────────────────

CREATE TABLE marca (
    numero INT PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL
);

CREATE TABLE conductor (
    registro        INT PRIMARY KEY,
    conNombre       VARCHAR(30) NOT NULL,
    conPrimerApell  VARCHAR(30) NOT NULL,
    conSegundoApell VARCHAR(30),
    licNumero       VARCHAR(15) NOT NULL,
    licVencimiento  DATE NOT NULL,
    fechaContrato   DATE NOT NULL
);

CREATE TABLE ciudad (
    clave   VARCHAR(5) PRIMARY KEY,
    nombre  VARCHAR(30) NOT NULL
);

CREATE TABLE tipo_asiento (
    codigo      VARCHAR(5) PRIMARY KEY,
    descripcion VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE tipo_pasajero (
    num         INT PRIMARY KEY,
    descuento   INT NOT NULL,
    descripcion VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE tipo_pago (
    numero      INT PRIMARY KEY,
    nombre      VARCHAR(30) NOT NULL,
    descripcion VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE edo_viaje (
    numero      INT PRIMARY KEY,
    nombre      VARCHAR(30) NOT NULL,
    descripcion VARCHAR(50) NOT NULL
);

CREATE TABLE pasajero (
    num             INT PRIMARY KEY AUTO_INCREMENT,
    paNombre        VARCHAR(30) NOT NULL,
    paPrimerApell   VARCHAR(30) NOT NULL,
    paSegundoApell  VARCHAR(30),
    fechaNacimiento DATE NOT NULL
);

CREATE TABLE cuenta_pasajero (
    pasajero_num  INT          PRIMARY KEY,
    correo        VARCHAR(100) NOT NULL UNIQUE,
    contrasena    VARCHAR(255),                   -- NULL si usa proveedor externo
    firebase_uid  VARCHAR(128) UNIQUE,            -- NULL si usa login local
    proveedor     VARCHAR(50)  NOT NULL DEFAULT 'local',
    foto          VARCHAR(200),                   -- ruta en media/, no BLOB
    FOREIGN KEY (pasajero_num) REFERENCES pasajero(num) ON DELETE CASCADE
);

CREATE TABLE modelo (
    numero      INT PRIMARY KEY,
    nombre      VARCHAR(30) NOT NULL,
    numasientos INT NOT NULL,
    ano         INT NOT NULL,
    capacidad   INT NOT NULL,
    marca       INT NOT NULL,
    FOREIGN KEY (marca) REFERENCES marca(numero)
);

CREATE TABLE terminal (
    numero      INT PRIMARY KEY,
    nombre      VARCHAR(30) NOT NULL,
    dirCalle    VARCHAR(30) NOT NULL,
    dirNumero   VARCHAR(10) NOT NULL,
    dirColonia  VARCHAR(30) NOT NULL,
    telefono    VARCHAR(12),
    ciudad      VARCHAR(5) NOT NULL,
    FOREIGN KEY (ciudad) REFERENCES ciudad(clave)
);

CREATE TABLE ruta (
    codigo      INT PRIMARY KEY,
    duracion    VARCHAR(10) NOT NULL,
    origen      INT NOT NULL,
    destino     INT NOT NULL,
    precio      DECIMAL(10,2) NOT NULL DEFAULT 250,
    FOREIGN KEY (origen) REFERENCES terminal(numero),
    FOREIGN KEY (destino) REFERENCES terminal(numero)
);

CREATE TABLE autobus (
    numero      INT PRIMARY KEY,
    modelo      INT NOT NULL,
    placas      VARCHAR(10) NOT NULL UNIQUE,
    serieVIN    VARCHAR(17) NOT NULL UNIQUE,
    FOREIGN KEY (modelo) REFERENCES modelo(numero)
);

CREATE TABLE viaje (
    numero          INT PRIMARY KEY AUTO_INCREMENT,
    fecHoraSalida   DATETIME NOT NULL,
    fecHoraEntrada  DATETIME NOT NULL,
    ruta            INT NOT NULL,
    estado          INT NOT NULL,
    autobus         INT,
    conductor       INT,
    FOREIGN KEY (ruta) REFERENCES ruta(codigo),
    FOREIGN KEY (estado) REFERENCES edo_viaje(numero),
    FOREIGN KEY (autobus) REFERENCES autobus(numero),
    FOREIGN KEY (conductor) REFERENCES conductor(registro)
);

CREATE TABLE asiento (
    numero  INT PRIMARY KEY AUTO_INCREMENT,
    tipo    VARCHAR(5) NOT NULL,
    autobus INT NOT NULL,
    FOREIGN KEY (tipo) REFERENCES tipo_asiento(codigo),
    FOREIGN KEY (autobus) REFERENCES autobus(numero)
);

CREATE TABLE viaje_asiento (
    asiento INT NOT NULL,
    viaje   INT NOT NULL,
    ocupado BOOLEAN NOT NULL,
    PRIMARY KEY (asiento, viaje),
    FOREIGN KEY (asiento) REFERENCES asiento(numero),
    FOREIGN KEY (viaje) REFERENCES viaje(numero)
);

CREATE TABLE taquillero (
    registro        INT PRIMARY KEY AUTO_INCREMENT,
    taqNombre       VARCHAR(30) NOT NULL,
    taqPrimerApell  VARCHAR(30) NOT NULL,
    taqSegundoApell VARCHAR(30),
    fechaContrato   DATE NOT NULL,
    usuario         VARCHAR(20) NOT NULL,
    contrasena      VARCHAR(255) NOT NULL,
    terminal        INT NOT NULL,
    foto            VARCHAR(200),  
    supervisa       BOOLEAN,
    FOREIGN KEY (terminal) REFERENCES terminal(numero)
);

CREATE TABLE pago (
    numero      INT PRIMARY KEY AUTO_INCREMENT,
    fechapago   DATETIME NOT NULL,
    monto       DECIMAL(10,2) NOT NULL,
    tipo        INT NOT NULL,
    vendedor    INT,
    FOREIGN KEY (tipo) REFERENCES tipo_pago(numero),
    FOREIGN KEY (vendedor) REFERENCES taquillero(registro)
);

CREATE TABLE ticket (
    codigo          INT PRIMARY KEY AUTO_INCREMENT,
    precio          DECIMAL(10,2) NOT NULL,
    fechaEmision    DATETIME NOT NULL,
    asiento         INT NOT NULL,
    viaje           INT NOT NULL,
    pasajero        INT NOT NULL,
    tipopasajero    INT NOT NULL,
    pago            INT NOT NULL,
    FOREIGN KEY (asiento) REFERENCES asiento(numero),
    FOREIGN KEY (viaje) REFERENCES viaje(numero),
    FOREIGN KEY (pasajero) REFERENCES pasajero(num),
    FOREIGN KEY (tipopasajero) REFERENCES tipo_pasajero(num),
    FOREIGN KEY (pago) REFERENCES pago(numero)
);

-- ── Vistas  ───────────────────

CREATE VIEW vista_pasajeros_edad AS
SELECT
    num,
    paNombre,
    paPrimerApell,
    paSegundoApell,
    fechaNacimiento,
    TIMESTAMPDIFF(YEAR, fechaNacimiento, CURDATE()) AS edad
FROM pasajero;

-- ── Triggers  ───────────────────
DELIMITER //
CREATE TRIGGER trg_antes_vender_ticket
BEFORE INSERT ON ticket
FOR EACH ROW
BEGIN
    DECLARE estado_asiento BOOLEAN;
    
    SELECT ocupado INTO estado_asiento 
    FROM viaje_asiento 
    WHERE asiento = NEW.asiento AND viaje = NEW.viaje;
    
    IF estado_asiento = TRUE THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Error: Este asiento ya fue vendido para este viaje.';
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_validar_licencia_conductor
BEFORE INSERT ON conductor
FOR EACH ROW
BEGIN
    -- CURDATE() es la fecha de hoy. Comparamos si la licencia ya expiró.
    IF NEW.licVencimiento < CURDATE() THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Error: No se puede registrar un conductor con licencia vencida.';
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_evitar_pasajero_duplicado
BEFORE INSERT ON pasajero
FOR EACH ROW
BEGIN
    -- Variable para guardar el ID si encontramos a alguien igual
    DECLARE v_id_existente INT DEFAULT 0;
    
    -- Buscamos si existe alguien con los mismos datos exactos
    -- Usamos IFNULL en el segundo apellido por si no tiene (es nulo)
    SELECT num INTO v_id_existente
    FROM pasajero
    WHERE paNombre = NEW.paNombre
      AND paPrimerApell = NEW.paPrimerApell
      AND IFNULL(paSegundoApell, '') = IFNULL(NEW.paSegundoApell, '')
      AND fechaNacimiento = NEW.fechaNacimiento
    LIMIT 1;
    
    -- Si 'v_id_existente' es mayor a 0, significa que sí lo encontró
    IF v_id_existente > 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Error: Este pasajero ya está registrado. Usa la búsqueda para encontrarlo.';
    END IF;

END //
DELIMITER ;

-- ── Procedimientos  ───────────────────

DELIMITER //
CREATE PROCEDURE sp_obtener_o_crear_pasajero(
    IN p_nombre VARCHAR(30),
    IN p_primer_apell VARCHAR(30),
    IN p_segundo_apell VARCHAR(30),
    IN p_fecha_nac DATE,
    OUT p_id_pasajero INT -- Esta es la variable de salida que te regresará el ID
)
BEGIN
    -- 1. Intentamos buscar al pasajero para ver si ya existe
    SELECT num INTO p_id_pasajero
    FROM pasajero
    WHERE paNombre = p_nombre
      AND paPrimerApell = p_primer_apell
      AND IFNULL(paSegundoApell, '') = IFNULL(p_segundo_apell, '')
      AND fechaNacimiento = p_fecha_nac
    LIMIT 1;
    
    -- 2. Si no se encontró (el ID quedó en NULL), entonces sí lo insertamos
    IF p_id_pasajero IS NULL THEN
        INSERT INTO pasajero (paNombre, paPrimerApell, paSegundoApell, fechaNacimiento)
        VALUES (p_nombre, p_primer_apell, p_segundo_apell, p_fecha_nac);
        
        -- 3. Obtenemos el ID del nuevo pasajero que acabamos de crear
        SET p_id_pasajero = LAST_INSERT_ID();
    END IF;
    
    -- Al terminar, la variable p_id_pasajero tendrá el ID viejo (si existía) 
    -- o el ID nuevo (si no existía). ¡Listo para usarse en el ticket!
END //
DELIMITER ;