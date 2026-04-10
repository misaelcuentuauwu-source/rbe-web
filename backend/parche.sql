-- Active: 1769381960521@@localhost@3306@rbe@@127.0.0.1@3306@rbe
-- Active: 1769381960521@@localhost@3306@rbe
-- ============================================================
-- RBE - Rutas Baja Express
-- Script completo: schema + datos
-- Actualizado: Marzo 13 del 2026
-- Usuario de prueba supervisor: za / za
-- Cambios v2:
--   · pasajero: se eliminó columna edad (ahora es vista calculada)
--   · Nueva vista: vista_pasajeros_edad (calcula edad con TIMESTAMPDIFF)
--   · Nueva tabla: cuenta_pasajero (login pasajeros + Firebase Auth)
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
    registro INT PRIMARY KEY,
    conNombre VARCHAR(30) NOT NULL,
    conPrimerApell VARCHAR(30) NOT NULL,
    conSegundoApell VARCHAR(30),
    licNumero VARCHAR(15) NOT NULL,
    licVencimiento DATE NOT NULL,
    fechaContrato DATE NOT NULL
);

CREATE TABLE ciudad (
    clave VARCHAR(5) PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL
);

CREATE TABLE tipo_asiento (
    codigo VARCHAR(5) PRIMARY KEY,
    descripcion VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE tipo_pasajero (
    num INT PRIMARY KEY,
    descuento INT NOT NULL,
    descripcion VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE tipo_pago (
    numero INT PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL,
    descripcion VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE edo_viaje (
    numero INT PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL,
    descripcion VARCHAR(50) NOT NULL
);

-- ── edad eliminada: ahora se calcula en la vista ──────────────
CREATE TABLE pasajero (
    num            INT PRIMARY KEY AUTO_INCREMENT,
    paNombre       VARCHAR(30) NOT NULL,
    paPrimerApell  VARCHAR(30) NOT NULL,
    paSegundoApell VARCHAR(30),
    fechaNacimiento DATE NOT NULL
);

-- ── Vista que calcula la edad dinámicamente ───────────────────
CREATE VIEW vista_pasajeros_edad AS
SELECT
    num,
    paNombre,
    paPrimerApell,
    paSegundoApell,
    fechaNacimiento,
    TIMESTAMPDIFF(YEAR, fechaNacimiento, CURDATE()) AS edad
FROM pasajero;

-- ── Cuenta de pasajero: login propio + Firebase Auth ──────────
-- proveedor: 'local' | 'google' | 'facebook' | 'apple'
-- clave:     NULL si el pasajero usa Google/redes sociales
-- firebase_uid: NULL si usa login local con clave propia
-- foto:      ruta relativa al archivo, ej: 'fotos_pasajeros/abc.jpg'
CREATE TABLE cuenta_pasajero (
    pasajero_num  INT          PRIMARY KEY,
    correo        VARCHAR(100) NOT NULL UNIQUE,
    clave         VARCHAR(255),                   -- NULL si usa proveedor externo
    firebase_uid  VARCHAR(128) UNIQUE,            -- NULL si usa login local
    proveedor     VARCHAR(50)  NOT NULL DEFAULT 'local',
    foto          VARCHAR(200),                   -- ruta en media/, no BLOB
    FOREIGN KEY (pasajero_num) REFERENCES pasajero(num) ON DELETE CASCADE
);

CREATE TABLE modelo (
    numero INT PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL,
    numasientos INT NOT NULL,
    ano INT NOT NULL,
    capacidad INT NOT NULL,
    marca INT NOT NULL,
    FOREIGN KEY (marca) REFERENCES marca(numero)
);

CREATE TABLE terminal (
    numero INT PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL,
    dirCalle VARCHAR(30) NOT NULL,
    dirNumero VARCHAR(10) NOT NULL,
    dirColonia VARCHAR(30) NOT NULL,
    telefono VARCHAR(12),
    ciudad VARCHAR(5) NOT NULL,
    FOREIGN KEY (ciudad) REFERENCES ciudad(clave)
);

CREATE TABLE ruta (
    codigo INT PRIMARY KEY,
    duracion VARCHAR(10) NOT NULL,
    origen INT NOT NULL,
    destino INT NOT NULL,
    precio DECIMAL(10,2) NOT NULL DEFAULT 250,
    FOREIGN KEY (origen) REFERENCES terminal(numero),
    FOREIGN KEY (destino) REFERENCES terminal(numero)
);

CREATE TABLE autobus (
    numero INT PRIMARY KEY,
    modelo INT NOT NULL,
    placas VARCHAR(10) NOT NULL UNIQUE,
    serieVIN VARCHAR(17) NOT NULL UNIQUE,
    FOREIGN KEY (modelo) REFERENCES modelo(numero)
);

CREATE TABLE viaje (
    numero INT PRIMARY KEY AUTO_INCREMENT,
    fecHoraSalida DATETIME NOT NULL,
    fecHoraEntrada DATETIME NOT NULL,
    ruta INT NOT NULL,
    estado INT NOT NULL,
    autobus INT,
    conductor INT,
    FOREIGN KEY (ruta) REFERENCES ruta(codigo),
    FOREIGN KEY (estado) REFERENCES edo_viaje(numero),
    FOREIGN KEY (autobus) REFERENCES autobus(numero),
    FOREIGN KEY (conductor) REFERENCES conductor(registro)
);

CREATE TABLE asiento (
    numero INT PRIMARY KEY AUTO_INCREMENT,
    tipo VARCHAR(5) NOT NULL,
    autobus INT NOT NULL,
    FOREIGN KEY (tipo) REFERENCES tipo_asiento(codigo),
    FOREIGN KEY (autobus) REFERENCES autobus(numero)
);

CREATE TABLE viaje_asiento (
    asiento INT NOT NULL,
    viaje INT NOT NULL,
    ocupado BOOLEAN NOT NULL,
    PRIMARY KEY (asiento, viaje),
    FOREIGN KEY (asiento) REFERENCES asiento(numero),
    FOREIGN KEY (viaje) REFERENCES viaje(numero)
);

CREATE TABLE taquillero (
    registro INT PRIMARY KEY AUTO_INCREMENT,
    taqNombre VARCHAR(30) NOT NULL,
    taqPrimerApell VARCHAR(30) NOT NULL,
    taqSegundoApell VARCHAR(30),
    fechaContrato DATE NOT NULL,
    usuario VARCHAR(20) NOT NULL,
    contrasena VARCHAR(20) NOT NULL,
    terminal INT NOT NULL,
    foto  VARCHAR(200),  
    supervisa BOOLEAN,
    FOREIGN KEY (terminal) REFERENCES terminal(numero)
);

CREATE TABLE pago (
    numero INT PRIMARY KEY AUTO_INCREMENT,
    fechapago DATETIME NOT NULL,
    monto DECIMAL(10,2) NOT NULL,
    tipo INT NOT NULL,
    vendedor INT,
    FOREIGN KEY (tipo) REFERENCES tipo_pago(numero),
    FOREIGN KEY (vendedor) REFERENCES taquillero(registro)
);

CREATE TABLE ticket (
    codigo INT PRIMARY KEY AUTO_INCREMENT,
    precio DECIMAL(10,2) NOT NULL,
    fechaEmision DATETIME NOT NULL,
    asiento INT NOT NULL,
    viaje INT NOT NULL,
    pasajero INT NOT NULL,
    tipopasajero INT NOT NULL,
    pago INT NOT NULL,
    FOREIGN KEY (asiento) REFERENCES asiento(numero),
    FOREIGN KEY (viaje) REFERENCES viaje(numero),
    FOREIGN KEY (pasajero) REFERENCES pasajero(num),
    FOREIGN KEY (tipopasajero) REFERENCES tipo_pasajero(num),
    FOREIGN KEY (pago) REFERENCES pago(numero)
);

-- ── Catalogos ─────────────────────────────────────────────────

INSERT INTO marca (numero, nombre) VALUES
(1, 'Volvo'),
(2, 'Mercedes-Benz'),
(3, 'Scania'),
(4, 'MAN'),
(5, 'Irizar');

INSERT INTO tipo_asiento (codigo, descripcion) VALUES
('COM', 'Comun'),
('DIS', 'Discapacitado'),
('PLU', 'Plus');

INSERT INTO tipo_pago (numero, nombre, descripcion) VALUES
(1, 'Efectivo', 'Efectivo'),
(2, 'Tarjeta',  'Tarjeta');

INSERT INTO tipo_pasajero (num, descuento, descripcion) VALUES
(1,  0, 'Adulto'),
(2, 50, 'Nino'),
(3, 30, 'Adulto Mayor'),
(4, 25, 'Estudiante'),
(5, 15, 'Discapacitado');

INSERT INTO edo_viaje (numero, nombre, descripcion) VALUES
(1, 'Disponible', 'Se puede vender'),
(2, 'En Ruta',    'Actualmente en trayecto'),
(3, 'Finalizado', 'Llego a destino'),
(4, 'Cancelado',  'Viaje suspendido'),
(5, 'Retrasado',  'Salida demorada');

-- ── Ciudades ──────────────────────────────────────────────────

INSERT INTO ciudad (clave, nombre) VALUES
('ENS', 'Ensenada'),
('MXL', 'Mexicali'),
('RSO', 'Rosarito'),
('SFE', 'San Felipe'),
('SQN', 'San Quintin'),
('TEC', 'Tecate'),
('TJ',  'Tijuana');

-- ── Terminales ────────────────────────────────────────────────

INSERT INTO terminal (numero, nombre, dirCalle, dirNumero, dirColonia, telefono, ciudad) VALUES
(1, 'Central Tijuana',      'Blvd. Insurgentes',        '2100',   'El Florido',      '6641123344', 'TJ'),
(2, 'Central Mexicali',     'Calz. Independencia',       '501',    'Pueblo Nuevo',    '6862219080', 'MXL'),
(3, 'Central Ensenada',     'Av. Reforma',               '1245',   'Moderna',         '6463317722', 'ENS'),
(4, 'Terminal Tecate',      'Blvd. Benito Juarez',       '780',    'Las Palmas',      '6652294433', 'TEC'),
(5, 'Terminal Rosarito',    'Blvd. Popotla',             '455',    'Centro',          '6611238899', 'RSO'),
(6, 'Terminal San Quintin', 'Carretera Transpeninsular', 'KM 189', 'Lazaro Cardenas', '6161237700', 'SQN'),
(7, 'Terminal San Felipe',  'Av. Mar de Cortes',         '320',    'Centro',          '6861985522', 'SFE');

-- ── Rutas ─────────────────────────────────────────────────────

INSERT INTO ruta (codigo, duracion, origen, destino, precio) VALUES
(1,  '0h45m',  1, 5,  90.00),
(2,  '0h45m',  5, 1,  90.00),
(3,  '2h',     1, 3, 240.00),
(4,  '2h',     3, 1, 240.00),
(5,  '1h15m',  1, 4, 180.00),
(6,  '1h15m',  4, 1, 180.00),
(7,  '2h50m',  1, 2, 350.00),
(8,  '2h50m',  2, 1, 350.00),
(9,  '2h',     5, 3, 240.00),
(10, '2h',     3, 5, 240.00),
(11, '3h',     3, 6, 320.00),
(12, '3h',     6, 3, 320.00),
(13, '4h',     1, 6, 500.00),
(14, '4h',     6, 1, 500.00),
(15, '6h',     5, 6, 550.00),
(16, '6h',     6, 5, 550.00),
(17, '2h15m',  2, 7, 300.00),
(18, '2h15m',  7, 2, 300.00),
(19, '5h',     3, 7, 650.00),
(20, '5h',     7, 3, 650.00),
(21, '6h30m',  6, 7, 900.00),
(22, '6h30m',  7, 6, 900.00),
(23, '1h',     4, 5, 120.00),
(24, '1h',     5, 4, 120.00),
(25, '3h',     4, 3, 300.00),
(26, '3h',     3, 4, 300.00),
(27, '4h',     4, 6, 520.00),
(28, '4h',     6, 4, 520.00),
(29, '3h20m',  2, 3, 390.00),
(30, '3h20m',  3, 2, 390.00),
(31, '5h10m',  2, 6, 720.00),
(32, '5h10m',  6, 2, 720.00),
(33, '1h10m',  4, 1, 180.00),
(34, '1h10m',  1, 4, 180.00),
(35, '6h',     5, 7, 750.00),
(36, '6h',     7, 5, 750.00),
(37, '7h',     1, 7, 950.00),
(38, '7h',     7, 1, 950.00);

-- ── Modelos ───────────────────────────────────────────────────

INSERT INTO modelo (numero, nombre, numasientos, ano, capacidad, marca) VALUES
(1, 'Irizar i8',       52, 2021, 52, 5),
(2, 'Volvo 9800',      48, 2022, 48, 1),
(3, 'Scania K440',     50, 2022, 50, 3),
(4, 'Mercedes OC500',  46, 2020, 46, 2),
(5, 'MAN Lions Coach', 49, 2023, 49, 4);

-- ── Autobuses ─────────────────────────────────────────────────

INSERT INTO autobus (numero, modelo, placas, serieVIN) VALUES
(1,  1, 'ABC1234', '1HGCM82633A004352'),
(2,  2, 'BCD2345', '2HGFA16598H392847'),
(3,  3, 'CDE3456', '3N1AB7AP4HY256981'),
(4,  4, 'DEF4567', '4T1BF1FK5HU789654'),
(5,  5, 'EFG5678', '5YFBURHE6HP123478'),
(6,  1, 'FGH6789', '1HD1BW5177Y035721'),
(7,  2, 'GHI7890', 'JHMCM56557C404578'),
(8,  3, 'HIJ8901', 'KMHCT4AE1FU765432'),
(9,  4, 'IJK9012', 'WDBRF40J43F392167'),
(10, 5, 'JKL0123', '1FTFW1EG1HFC98325');

-- ── Conductores ───────────────────────────────────────────────

INSERT INTO conductor (registro, conNombre, conPrimerApell, conSegundoApell, licNumero, licVencimiento, fechaContrato) VALUES
(1,  'Marco',     'Hernandez', 'Soto',     'BCF-2025-91342', '2028-04-12', '2022-03-10'),
(2,  'Luis',      'Medina',    'Torres',   'BCF-2024-55102', '2027-11-01', '2021-07-14'),
(3,  'Rosa',      'Aguilar',   'Ponce',    'BCF-2026-77421', '2029-02-20', '2023-02-01'),
(4,  'Jaime',     'Flores',    'Ramirez',  'BCF-2023-10455', '2027-09-30', '2020-05-22'),
(5,  'Daniela',   'Sanchez',   'Vega',     'BCF-2026-66790', '2030-01-17', '2024-01-03'),
(6,  'Hector',    'Ramos',     'Cruz',     'BCF-2025-22984', '2028-06-13', '2025-01-18'),
(7,  'Brenda',    'Lopez',     'Castillo', 'BCF-2024-88311', '2027-03-09', '2022-09-09'),
(8,  'Oscar',     'Delgado',   'Silva',    'BCF-2025-55009', '2028-12-14', '2021-12-14'),
(9,  'Kevin',     'Ortiz',     'Molina',   'BCF-2027-33201', '2029-04-25', '2023-02-20'),
(10, 'Miriam',    'Navarro',   'Ruiz',     'BCF-2024-11798', '2027-10-11', '2024-06-11'),
(11, 'Roberto',   'Perez',     'Leon',     'BCF-2023-42055', '2027-08-09', '2023-08-03'),
(12, 'Alejandra', 'Varela',    'Diaz',     'BCF-2026-90021', '2029-03-01', '2025-03-01');

-- ── Asientos ─────────────────────────────────────────────────
-- autobus 1 (52 asientos)
INSERT INTO asiento (numero, tipo, autobus) VALUES
(1,'DIS',1),(2,'PLU',1),(3,'DIS',1),(4,'PLU',1),(5,'PLU',1),(6,'PLU',1),(7,'PLU',1),(8,'PLU',1),
(9,'COM',1),(10,'COM',1),(11,'COM',1),(12,'COM',1),(13,'COM',1),(14,'COM',1),(15,'COM',1),(16,'COM',1),
(17,'COM',1),(18,'COM',1),(19,'COM',1),(20,'COM',1),(21,'COM',1),(22,'COM',1),(23,'COM',1),(24,'COM',1),
(25,'COM',1),(26,'COM',1),(27,'COM',1),(28,'COM',1),(29,'COM',1),(30,'COM',1),(31,'COM',1),(32,'COM',1),
(33,'COM',1),(34,'COM',1),(35,'COM',1),(36,'COM',1),(37,'COM',1),(38,'COM',1),(39,'COM',1),(40,'COM',1),
(41,'COM',1),(42,'COM',1),(43,'COM',1),(44,'COM',1),(45,'COM',1),(46,'COM',1),(47,'COM',1),(48,'DIS',1),
(49,'COM',1),(50,'COM',1),(51,'COM',1),(52,'COM',1),
-- autobus 2 (48 asientos)
(53,'PLU',2),(54,'PLU',2),(55,'DIS',2),(56,'PLU',2),(57,'PLU',2),(58,'PLU',2),(59,'PLU',2),(60,'PLU',2),
(61,'COM',2),(62,'COM',2),(63,'COM',2),(64,'COM',2),(65,'COM',2),(66,'COM',2),(67,'COM',2),(68,'COM',2),
(69,'COM',2),(70,'COM',2),(71,'COM',2),(72,'COM',2),(73,'COM',2),(74,'COM',2),(75,'COM',2),(76,'COM',2),
(77,'COM',2),(78,'COM',2),(79,'COM',2),(80,'COM',2),(81,'COM',2),(82,'COM',2),(83,'COM',2),(84,'COM',2),
(85,'COM',2),(86,'COM',2),(87,'COM',2),(88,'COM',2),(89,'COM',2),(90,'COM',2),(91,'COM',2),(92,'COM',2),
(93,'COM',2),(94,'COM',2),(95,'COM',2),(96,'COM',2),(97,'COM',2),(98,'COM',2),(99,'DIS',2),(100,'DIS',2),
-- autobus 3 (50 asientos)
(101,'DIS',3),(102,'PLU',3),(103,'DIS',3),(104,'PLU',3),(105,'PLU',3),(106,'PLU',3),(107,'PLU',3),(108,'PLU',3),
(109,'COM',3),(110,'COM',3),(111,'COM',3),(112,'COM',3),(113,'COM',3),(114,'COM',3),(115,'COM',3),(116,'COM',3),
(117,'COM',3),(118,'COM',3),(119,'COM',3),(120,'COM',3),(121,'COM',3),(122,'COM',3),(123,'COM',3),(124,'COM',3),
(125,'COM',3),(126,'COM',3),(127,'COM',3),(128,'COM',3),(129,'COM',3),(130,'COM',3),(131,'COM',3),(132,'COM',3),
(133,'COM',3),(134,'COM',3),(135,'COM',3),(136,'COM',3),(137,'COM',3),(138,'COM',3),(139,'COM',3),(140,'COM',3),
(141,'COM',3),(142,'COM',3),(143,'COM',3),(144,'COM',3),(145,'COM',3),(146,'COM',3),(147,'COM',3),(148,'COM',3),
(149,'COM',3),(150,'COM',3),
-- autobus 4 (46 asientos)
(151,'DIS',4),(152,'PLU',4),(153,'DIS',4),(154,'PLU',4),(155,'PLU',4),(156,'PLU',4),(157,'PLU',4),(158,'PLU',4),
(159,'COM',4),(160,'COM',4),(161,'COM',4),(162,'COM',4),(163,'COM',4),(164,'COM',4),(165,'COM',4),(166,'COM',4),
(167,'COM',4),(168,'COM',4),(169,'COM',4),(170,'COM',4),(171,'COM',4),(172,'COM',4),(173,'COM',4),(174,'COM',4),
(175,'COM',4),(176,'COM',4),(177,'COM',4),(178,'COM',4),(179,'COM',4),(180,'COM',4),(181,'COM',4),(182,'COM',4),
(183,'COM',4),(184,'COM',4),(185,'COM',4),(186,'COM',4),(187,'COM',4),(188,'COM',4),(189,'COM',4),(190,'COM',4),
(191,'COM',4),(192,'COM',4),(193,'COM',4),(194,'COM',4),(195,'COM',4),(196,'COM',4),
-- autobus 5 (49 asientos)
(197,'DIS',5),(198,'PLU',5),(199,'DIS',5),(200,'PLU',5),(201,'PLU',5),(202,'PLU',5),(203,'PLU',5),(204,'PLU',5),
(205,'COM',5),(206,'COM',5),(207,'COM',5),(208,'COM',5),(209,'COM',5),(210,'COM',5),(211,'COM',5),(212,'COM',5),
(213,'COM',5),(214,'COM',5),(215,'COM',5),(216,'COM',5),(217,'COM',5),(218,'COM',5),(219,'COM',5),(220,'COM',5),
(221,'COM',5),(222,'COM',5),(223,'COM',5),(224,'COM',5),(225,'COM',5),(226,'COM',5),(227,'COM',5),(228,'COM',5),
(229,'COM',5),(230,'COM',5),(231,'COM',5),(232,'COM',5),(233,'COM',5),(234,'COM',5),(235,'COM',5),(236,'COM',5),
(237,'COM',5),(238,'COM',5),(239,'COM',5),(240,'COM',5),(241,'COM',5),(242,'COM',5),(243,'COM',5),(244,'COM',5),
(245,'COM',5),
-- autobus 6 (52 asientos)
(246,'DIS',6),(247,'PLU',6),(248,'DIS',6),(249,'PLU',6),(250,'PLU',6),(251,'PLU',6),(252,'PLU',6),(253,'PLU',6),
(254,'COM',6),(255,'COM',6),(256,'COM',6),(257,'COM',6),(258,'COM',6),(259,'COM',6),(260,'COM',6),(261,'COM',6),
(262,'COM',6),(263,'COM',6),(264,'COM',6),(265,'COM',6),(266,'COM',6),(267,'COM',6),(268,'COM',6),(269,'COM',6),
(270,'COM',6),(271,'COM',6),(272,'COM',6),(273,'COM',6),(274,'COM',6),(275,'COM',6),(276,'COM',6),(277,'COM',6),
(278,'COM',6),(279,'COM',6),(280,'COM',6),(281,'COM',6),(282,'COM',6),(283,'COM',6),(284,'COM',6),(285,'COM',6),
(286,'COM',6),(287,'COM',6),(288,'COM',6),(289,'COM',6),(290,'COM',6),(291,'COM',6),(292,'COM',6),(293,'DIS',6),
(294,'COM',6),(295,'COM',6),(296,'COM',6),(297,'COM',6),
-- autobus 7 (48 asientos)
(298,'PLU',7),(299,'PLU',7),(300,'DIS',7),(301,'PLU',7),(302,'PLU',7),(303,'PLU',7),(304,'PLU',7),(305,'PLU',7),
(306,'COM',7),(307,'COM',7),(308,'COM',7),(309,'COM',7),(310,'COM',7),(311,'COM',7),(312,'COM',7),(313,'COM',7),
(314,'COM',7),(315,'COM',7),(316,'COM',7),(317,'COM',7),(318,'COM',7),(319,'COM',7),(320,'COM',7),(321,'COM',7),
(322,'COM',7),(323,'COM',7),(324,'COM',7),(325,'COM',7),(326,'COM',7),(327,'COM',7),(328,'COM',7),(329,'COM',7),
(330,'COM',7),(331,'COM',7),(332,'COM',7),(333,'COM',7),(334,'COM',7),(335,'COM',7),(336,'COM',7),(337,'COM',7),
(338,'COM',7),(339,'COM',7),(340,'COM',7),(341,'COM',7),(342,'COM',7),(343,'COM',7),(344,'DIS',7),(345,'DIS',7),
-- autobus 8 (50 asientos)
(346,'DIS',8),(347,'PLU',8),(348,'DIS',8),(349,'PLU',8),(350,'PLU',8),(351,'PLU',8),(352,'PLU',8),(353,'PLU',8),
(354,'COM',8),(355,'COM',8),(356,'COM',8),(357,'COM',8),(358,'COM',8),(359,'COM',8),(360,'COM',8),(361,'COM',8),
(362,'COM',8),(363,'COM',8),(364,'COM',8),(365,'COM',8),(366,'COM',8),(367,'COM',8),(368,'COM',8),(369,'COM',8),
(370,'COM',8),(371,'COM',8),(372,'COM',8),(373,'COM',8),(374,'COM',8),(375,'COM',8),(376,'COM',8),(377,'COM',8),
(378,'COM',8),(379,'COM',8),(380,'COM',8),(381,'COM',8),(382,'COM',8),(383,'COM',8),(384,'COM',8),(385,'COM',8),
(386,'COM',8),(387,'COM',8),(388,'COM',8),(389,'COM',8),(390,'COM',8),(391,'COM',8),(392,'COM',8),(393,'COM',8),
(394,'COM',8),(395,'COM',8),
-- autobus 9 (46 asientos)
(396,'DIS',9),(397,'PLU',9),(398,'DIS',9),(399,'PLU',9),(400,'PLU',9),(401,'PLU',9),(402,'PLU',9),(403,'PLU',9),
(404,'COM',9),(405,'COM',9),(406,'COM',9),(407,'COM',9),(408,'COM',9),(409,'COM',9),(410,'COM',9),(411,'COM',9),
(412,'COM',9),(413,'COM',9),(414,'COM',9),(415,'COM',9),(416,'COM',9),(417,'COM',9),(418,'COM',9),(419,'COM',9),
(420,'COM',9),(421,'COM',9),(422,'COM',9),(423,'COM',9),(424,'COM',9),(425,'COM',9),(426,'COM',9),(427,'COM',9),
(428,'COM',9),(429,'COM',9),(430,'COM',9),(431,'COM',9),(432,'COM',9),(433,'COM',9),(434,'COM',9),(435,'COM',9),
(436,'COM',9),(437,'COM',9),(438,'COM',9),(439,'COM',9),(440,'COM',9),(441,'COM',9),
-- autobus 10 (49 asientos)
(442,'DIS',10),(443,'PLU',10),(444,'DIS',10),(445,'PLU',10),(446,'PLU',10),(447,'PLU',10),(448,'PLU',10),(449,'PLU',10),
(450,'COM',10),(451,'COM',10),(452,'COM',10),(453,'COM',10),(454,'COM',10),(455,'COM',10),(456,'COM',10),(457,'COM',10),
(458,'COM',10),(459,'COM',10),(460,'COM',10),(461,'COM',10),(462,'COM',10),(463,'COM',10),(464,'COM',10),(465,'COM',10),
(466,'COM',10),(467,'COM',10),(468,'COM',10),(469,'COM',10),(470,'COM',10),(471,'COM',10),(472,'COM',10),(473,'COM',10),
(474,'COM',10),(475,'COM',10),(476,'COM',10),(477,'COM',10),(478,'COM',10),(479,'COM',10),(480,'COM',10),(481,'COM',10),
(482,'COM',10),(483,'COM',10),(484,'COM',10),(485,'COM',10),(486,'COM',10),(487,'COM',10),(488,'COM',10),(489,'COM',10),
(490,'COM',10);

-- ── Taquilleros ───────────────────────────────────────────────

INSERT INTO taquillero (registro, taqNombre, taqPrimerApell, taqSegundoApell, fechaContrato, usuario, contrasena, terminal, supervisa) VALUES
(1,  'Ana',      'Gomez',    'Ruiz',      '2023-01-10', 'agomez',    'AG2023',   1, 1),
(2,  'Mario',    'Sanchez',  'Lopez',     '2023-03-22', 'msanchez',  'MS22',     1, 0),
(3,  'Brenda',   'Torres',   'Aguilar',   '2024-07-15', 'btorres',   'BT24',     1, 0),
(4,  'Jose',     'Perez',    'Mendez',    '2024-04-05', 'jperez',    'JP24',     2, 1),
(5,  'Diana',    'Ramirez',  'Soto',      '2023-10-11', 'dramirez',  'DR23',     2, 0),
(6,  'Kevin',    'Herrera',  'Salas',     '2025-01-18', 'kherrera',  'KH25',     2, 0),
(7,  'Laura',    'Sanchez',  'Diaz',      '2022-09-14', 'lsanchez',  'LS22',     3, 1),
(8,  'Carlos',   'Medina',   'Ruiz',      '2023-05-03', 'cmedina',   'CM23',     3, 0),
(9,  'Fernanda', 'Reyes',    'Aguilar',   '2025-01-01', 'freyes',    'FR25',     3, 0),
(10, 'Carlos',   'Torres',   'Ramirez',   '2021-02-19', 'ctorres',   'CT21',     4, 1),
(11, 'Ivana',    'Cruz',     'Vega',      '2022-08-29', 'icruz',     'IC22',     4, 0),
(12, 'Samuel',   'Ortega',   'Flores',    '2024-02-14', 'sortega',   'SO24',     4, 0),
(13, 'Sergio',   'Delgado',  'Montoya',   '2023-06-12', 'sdelgado',  'SD23',     5, 1),
(14, 'Valeria',  'Munoz',    'Tapia',     '2024-01-04', 'vmunoz',    'VM24',     5, 0),
(15, 'Hugo',     'Paredes',  'Leon',      '2022-11-20', 'hparedes',  'HP22',     5, 0),
(16, 'Paola',    'Flores',   'Rivas',     '2024-05-19', 'pflores',   'PF24',     6, 1),
(17, 'Edgar',    'Vargas',   'Molina',    '2023-03-02', 'evargas',   'EV23',     6, 0),
(18, 'Karla',    'Salgado',  'Ruiz',      '2025-02-07', 'ksalgado',  'KS25',     6, 0),
(19, 'Miriam',   'Castillo', 'Perez',     '2023-09-30', 'mcastillo', 'MC23',     7, 1),
(20, 'Luis',     'Navarro',  'Beltran',   '2024-03-21', 'lnavarro',  'LN24',     7, 0),
(21, 'Sofia',    'Avila',    'Torres',    '2025-01-13', 'savila',    'SA25',     7, 0),
(22, 'Salvador', 'Garcia',   'Bojorquez', '2025-12-01', 'sgarcia',   'salvador', 1, 1),
(23, 'Admin',    'Za',       NULL,        '2026-02-21', 'za',        'za',       1, 1);

-- ── Pasajeros (sin columna edad) ──────────────────────────────

INSERT INTO pasajero (num, paNombre, paPrimerApell, paSegundoApell, fechaNacimiento) VALUES
(1,  'Alejandro', 'Torres',    'Lopez',     '1995-04-12'),
(2,  'Mariana',   'Hernandez', 'Cruz',      '1988-11-03'),
(3,  'Luis',      'Aguilar',   'Soto',      '2001-06-21'),
(4,  'Fernanda',  'Ruiz',      'Martinez',  '1999-09-15'),
(5,  'Ricardo',   'Medina',    'Vargas',    '1987-02-08'),
(6,  'Sofia',     'Castillo',  'Ponce',     '2005-12-01'),
(7,  'Mateo',     'Garcia',    'Leon',      '1991-05-22'),
(8,  'Daniela',   'Lopez',     'Silva',     '1993-10-09'),
(9,  'Jorge',     'Sanchez',   'Rivera',    '1980-03-14'),
(10, 'Paola',     'Ramirez',   'Diaz',      '1997-08-20'),
(11, 'Ivan',      'Flores',    'Navarro',   '2004-01-10'),
(12, 'Teresa',    'Morales',   'Romero',    '1985-06-30'),
(13, 'Pedro',     'Vargas',    'Camacho',   '1992-12-04'),
(14, 'Karen',     'Soto',      'Aguilar',   '1994-02-19'),
(15, 'Brenda',    'Leon',      'Herrera',   '1998-07-07'),
(16, 'Miguel',    'Cruz',      'Delgado',   '1989-01-23'),
(17, 'Ana',       'Molina',    'Rojas',     '2000-04-28'),
(18, 'Jesus',     'Paredes',   'Luna',      '1979-09-01'),
(19, 'Valeria',   'Cabrera',   'Solis',     '1996-11-12'),
(20, 'Hector',    'Ortega',    'Villalobos','1984-05-18'),
(21, 'Andrea',    'Castillo',  'Ramos',     '1999-03-22'),
(22, 'Carlos',    'Navarro',   'Cardenas',  '1993-07-30'),
(23, 'Elisa',     'Ramirez',   'Cruz',      '2002-10-17'),
(24, 'Omar',      'Herrera',   'Lozano',    '1988-04-25'),
(25, 'Natalia',   'Vega',      'Bernal',    '1997-03-04'),
(26, 'Diego',     'Tapia',     'Rivera',    '1990-08-16'),
(27, 'Laura',     'Camacho',   'Flores',    '1986-02-11'),
(28, 'Alan',      'Ruiz',      'Castro',    '2003-09-29'),
(29, 'Miriam',    'Rios',      'Sanchez',   '1995-06-10'),
(30, 'Esteban',   'Salinas',   'Duarte',    '1992-01-14'),
(41, 'Diego',     'Torres',    'Soto',      '2016-07-14'),
(42, 'Camila',    'Hernandez', 'Ruiz',      '2015-02-01'),
(43, 'Samuel',    'Medina',    'Lopez',     '2017-11-23'),
(44, 'Zoe',       'Aguilar',   'Vega',      '2019-03-08'),
(71, 'Hector',    'Sepulveda', 'Ramos',     '1955-04-12'),
(72, 'Rosa',      'Camacho',   'Valenzuela','1948-11-22'),
(73, 'Manuel',    'Ramirez',   'Castro',    '1952-06-01'),
(74, 'Irma',      'Martinez',  'Rivas',     '1945-02-14'),
(101,'Anwar',     'Estrada',   'Santos',    '2006-04-14'),
(102,'Salvador',  'Garcia',    'Bojorquez', '2006-02-17'),
(103,'Elver',     'Ignacio',   'Bernal',    '1985-04-25'),
(104,'Jose',      'Perez',     'Lopez',     '1970-08-26'),
(105,'Maria',     'Madrigal',  'Gutierrez', '1980-10-23'),
(106,'Misael',    'Urquidez',  'Arredondo', '2006-03-14'),
(107,'Leonardo',  'Castillo',  'Mora',      '1998-04-12'),
(108,'Valeria',   'Nunes',     'Rivas',     '2002-09-03');

-- ── Cuentas de pasajero de ejemplo ───────────────────────────
-- login local
INSERT INTO cuenta_pasajero (pasajero_num, correo, clave, firebase_uid, proveedor, foto) VALUES
(1,  'alejandro.torres@mail.com',  '$2b$12$hashejemplo1', NULL, 'local',  NULL),
(2,  'mariana.hdz@mail.com',       '$2b$12$hashejemplo2', NULL, 'local',  NULL);
-- login con Google (clave NULL, firebase_uid viene de Firebase)
INSERT INTO cuenta_pasajero (pasajero_num, correo, clave, firebase_uid, proveedor, foto) VALUES
(3,  'luis.aguilar@gmail.com',     NULL, 'uid_google_abc123', 'google', 'fotos_pasajeros/luis_3.jpg'),
(4,  'fernanda.ruiz@gmail.com',    NULL, 'uid_google_def456', 'google', NULL);

-- ════════════════════════════════════════════════════════════
--  VIAJES
--  Estado: 1=Disponible 2=En Ruta 3=Finalizado 4=Cancelado 5=Retrasado
-- ════════════════════════════════════════════════════════════

INSERT INTO viaje (numero, fecHoraSalida, fecHoraEntrada, ruta, estado, autobus, conductor) VALUES
-- ── Enero 2026 — Finalizados ──────────────────────────────────
(1,  '2026-01-10 08:00:00', '2026-01-10 08:45:00',  1, 3,  1,  1),
(2,  '2026-01-10 10:00:00', '2026-01-10 12:50:00',  7, 3,  2,  2),
(3,  '2026-01-12 07:30:00', '2026-01-12 09:30:00',  3, 3,  3,  3),
(4,  '2026-01-15 08:00:00', '2026-01-15 10:00:00',  4, 3,  1,  1),
(5,  '2026-01-20 09:00:00', '2026-01-20 09:45:00',  2, 3,  2,  2),
(6,  '2026-01-22 07:30:00', '2026-01-22 09:30:00',  3, 3,  3,  3),
(7,  '2026-01-25 10:00:00', '2026-01-25 12:50:00',  7, 3,  4,  4),
(8,  '2026-01-28 14:00:00', '2026-01-28 16:00:00',  4, 3,  5,  5),
-- ── Febrero 2026 — Finalizados ────────────────────────────────
(9,  '2026-02-01 06:30:00', '2026-02-01 07:15:00',  1, 3,  1,  1),
(10, '2026-02-05 08:00:00', '2026-02-05 10:00:00',  3, 3,  2,  2),
(11, '2026-02-10 09:15:00', '2026-02-10 10:30:00',  5, 3,  3,  2),
(12, '2026-02-15 15:00:00', '2026-02-15 15:45:00',  2, 3,  4,  4),
(13, '2026-02-18 07:00:00', '2026-02-18 09:50:00',  7, 3,  6,  6),
(14, '2026-02-20 08:00:00', '2026-02-20 08:45:00',  1, 3,  7,  9),
-- ── Febrero 2026 — En Ruta (21-feb) ──────────────────────────
(15, '2026-02-21 07:00:00', '2026-02-21 09:50:00',  7, 2,  1,  1),
(16, '2026-02-21 08:30:00', '2026-02-21 09:15:00',  1, 2,  4,  4),
-- ── Febrero 2026 — Disponibles ───────────────────────────────
(17, '2026-02-22 06:00:00', '2026-02-22 08:50:00',  7, 1,  2,  2),
(18, '2026-02-22 09:00:00', '2026-02-22 09:45:00',  2, 1,  7,  7),
(19, '2026-02-22 14:00:00', '2026-02-22 16:00:00',  3, 1,  1,  6),
(20, '2026-02-23 07:00:00', '2026-02-23 09:00:00',  4, 1,  3,  3),
(21, '2026-02-23 18:00:00', '2026-02-23 19:15:00',  5, 1,  8,  5),
(22, '2026-02-24 10:00:00', '2026-02-24 11:15:00',  6, 1,  6,  7),
(23, '2026-02-24 16:00:00', '2026-02-24 18:50:00',  7, 1,  9,  1),
(24, '2026-02-25 08:00:00', '2026-02-25 10:50:00',  8, 1, 10,  8),
(25, '2026-02-25 12:00:00', '2026-02-25 14:00:00',  9, 1,  2,  3),
(26, '2026-02-26 06:00:00', '2026-02-26 09:00:00', 11, 1,  5,  4),
(27, '2026-02-27 08:00:00', '2026-02-27 12:00:00', 13, 1,  9,  7),
(28, '2026-02-28 09:00:00', '2026-02-28 12:15:00', 17, 1,  3,  6),
-- ── Febrero — Retrasado / Cancelado ──────────────────────────
(34, '2026-02-21 06:00:00', '2026-02-21 07:00:00', 23, 5,  6, 11),
(35, '2026-02-20 10:00:00', '2026-02-20 11:00:00', 24, 4,  3, 12),
-- ── Marzo 2026 — Finalizados (1-12 mar) ──────────────────────
(29, '2026-03-01 08:00:00', '2026-03-01 08:45:00',  1, 3,  1,  1),
(30, '2026-03-01 10:00:00', '2026-03-01 12:50:00',  7, 3,  2,  2),
(31, '2026-03-02 07:30:00', '2026-03-02 09:30:00',  3, 3,  3,  3),
(32, '2026-03-03 09:00:00', '2026-03-03 11:50:00',  7, 3,  4,  4),
(33, '2026-03-04 08:00:00', '2026-03-04 08:45:00',  2, 3,  5,  5),
(36, '2026-03-05 07:00:00', '2026-03-05 09:00:00',  4, 3,  6,  6),
(37, '2026-03-06 06:30:00', '2026-03-06 09:20:00',  8, 3,  7,  7),
(38, '2026-03-07 08:00:00', '2026-03-07 10:00:00',  3, 3,  8,  8),
(39, '2026-03-08 09:00:00', '2026-03-08 09:45:00',  1, 3,  9,  9),
(40, '2026-03-09 10:00:00', '2026-03-09 12:50:00',  7, 3, 10,  1),
(41, '2026-03-10 07:30:00', '2026-03-10 09:30:00',  3, 3,  1,  2),
(42, '2026-03-11 08:00:00', '2026-03-11 10:00:00',  4, 3,  2,  3),
(43, '2026-03-12 06:00:00', '2026-03-12 06:45:00',  1, 3,  3,  4),
-- ── Hoy 13-Mar — En Ruta ─────────────────────────────────────
(44, '2026-03-13 07:00:00', '2026-03-13 09:50:00',  7, 2,  4,  5),
(45, '2026-03-13 08:30:00', '2026-03-13 09:15:00',  2, 2,  5,  6),
(46, '2026-03-13 10:00:00', '2026-03-13 12:00:00',  3, 2,  6,  7),
-- ── Marzo 2026 — Disponibles (14-30 mar) ─────────────────────
(47, '2026-03-14 07:00:00', '2026-03-14 09:50:00',  7, 1,  7,  8),
(48, '2026-03-14 09:00:00', '2026-03-14 09:45:00',  2, 1,  8,  9),
(49, '2026-03-15 08:00:00', '2026-03-15 10:00:00',  3, 1,  9, 10),
(50, '2026-03-15 10:00:00', '2026-03-15 12:50:00',  7, 1, 10,  1),
(51, '2026-03-16 07:30:00', '2026-03-16 09:30:00',  4, 1,  1,  2),
(52, '2026-03-16 14:00:00', '2026-03-16 16:50:00',  8, 1,  2,  3),
(53, '2026-03-17 08:00:00', '2026-03-17 08:45:00',  1, 1,  3,  4),
(54, '2026-03-18 09:00:00', '2026-03-18 11:50:00',  7, 1,  4,  5),
(55, '2026-03-19 07:00:00', '2026-03-19 09:00:00',  3, 1,  5,  6),
(56, '2026-03-20 10:00:00', '2026-03-20 12:15:00',  5, 1,  6,  7),
(57, '2026-03-21 08:00:00', '2026-03-21 08:45:00',  2, 1,  7,  8),
(58, '2026-03-22 07:00:00', '2026-03-22 09:50:00',  7, 1,  8,  9),
(59, '2026-03-23 09:00:00', '2026-03-23 11:00:00',  4, 1,  9, 10),
(60, '2026-03-24 08:00:00', '2026-03-24 10:50:00',  8, 1, 10,  1),
(61, '2026-03-25 07:30:00', '2026-03-25 09:30:00',  3, 1,  1,  2),
(62, '2026-03-26 10:00:00', '2026-03-26 12:50:00',  7, 1,  2,  3),
(63, '2026-03-27 08:00:00', '2026-03-27 08:45:00',  1, 1,  3,  4),
(64, '2026-03-28 09:00:00', '2026-03-28 11:15:00',  5, 1,  4,  5),
(65, '2026-03-29 07:00:00', '2026-03-29 09:50:00',  7, 1,  5,  6),
(66, '2026-03-30 08:00:00', '2026-03-30 10:00:00',  3, 1,  6,  7),
(67, '2026-03-31 10:00:00', '2026-03-31 12:50:00',  7, 1,  7,  8);

-- ════════════════════════════════════════════════════════════
--  VIAJE_ASIENTO
-- ════════════════════════════════════════════════════════════

INSERT INTO viaje_asiento (asiento, viaje, ocupado) VALUES
-- Viaje 1 (bus 1, TJ-RSO)
(1,1,1),(2,1,1),(3,1,1),(4,1,1),(5,1,1),(6,1,1),(7,1,1),(8,1,1),
(9,1,1),(10,1,1),(11,1,1),(12,1,1),(13,1,0),(14,1,0),(15,1,0),
-- Viaje 2 (bus 2, TJ-MXL)
(53,2,1),(54,2,1),(55,2,1),(56,2,1),(57,2,1),(58,2,1),(59,2,1),(60,2,1),
(61,2,1),(62,2,1),(63,2,1),(64,2,0),(65,2,0),(66,2,0),
-- Viaje 3 (bus 3, TJ-ENS)
(101,3,1),(102,3,1),(103,3,1),(104,3,1),(105,3,1),(106,3,1),(107,3,1),(108,3,1),
(109,3,1),(110,3,1),(111,3,0),(112,3,0),(113,3,0),
-- Viaje 15 (bus 1, en ruta 21-feb)
(1,15,1),(2,15,1),(3,15,0),(4,15,1),(5,15,1),(6,15,0),(7,15,1),(8,15,1),
(9,15,1),(10,15,0),(11,15,1),(12,15,0),(13,15,1),(14,15,0),(15,15,1),
(16,15,0),(17,15,1),(18,15,0),(19,15,1),(20,15,0),
-- Viaje 16 (bus 4, en ruta 21-feb)
(151,16,1),(152,16,1),(153,16,0),(154,16,1),(159,16,1),(160,16,0),(161,16,1),
-- Viaje 17 (bus 2, disponible)
(53,17,0),(54,17,0),(55,17,0),(56,17,0),(57,17,0),(58,17,0),(59,17,0),(60,17,0),
(61,17,0),(62,17,0),(63,17,0),(64,17,0),(65,17,0),(66,17,0),(67,17,0),(68,17,0),
-- Viaje 18 (bus 7, disponible)
(298,18,0),(299,18,0),(300,18,0),(301,18,0),(302,18,0),(303,18,0),(304,18,0),(305,18,0),
(306,18,0),(307,18,0),(308,18,0),(309,18,0),(310,18,0),(311,18,0),(312,18,0),
-- Viaje 19 (bus 1, disponible)
(1,19,0),(2,19,0),(3,19,0),(4,19,0),(5,19,0),(6,19,0),(7,19,0),(8,19,0),
(9,19,0),(10,19,0),(11,19,0),(12,19,0),(13,19,0),(14,19,0),(15,19,0),
-- Viaje 20 (bus 3, disponible)
(101,20,0),(102,20,0),(103,20,0),(104,20,0),(105,20,0),(106,20,0),(107,20,0),(108,20,0),
(109,20,0),(110,20,0),(111,20,0),(112,20,0),(113,20,0),(114,20,0),(115,20,0),
-- Viaje 29 (bus 1, TJ-RSO, 12 pasajeros)
(1,29,1),(2,29,1),(3,29,1),(4,29,1),(5,29,1),(6,29,1),(7,29,1),(8,29,1),
(9,29,1),(10,29,1),(11,29,1),(12,29,1),(13,29,0),(14,29,0),(15,29,0),
-- Viaje 30 (bus 2, TJ-MXL, 10 pasajeros)
(53,30,1),(54,30,1),(55,30,1),(56,30,1),(57,30,1),(58,30,1),(59,30,1),(60,30,1),
(61,30,1),(62,30,1),(63,30,0),(64,30,0),(65,30,0),
-- Viaje 31 (bus 3, TJ-ENS, 9 pasajeros)
(101,31,1),(102,31,1),(103,31,1),(104,31,1),(105,31,1),(106,31,1),(107,31,1),(108,31,1),
(109,31,1),(110,31,0),(111,31,0),(112,31,0),
-- Viaje 32 (bus 4, TJ-MXL, 8 pasajeros)
(151,32,1),(152,32,1),(153,32,1),(154,32,1),(155,32,1),(156,32,1),(157,32,1),(158,32,1),
(159,32,0),(160,32,0),(161,32,0),
-- Viaje 33 (bus 5, RSO-TJ, 7 pasajeros)
(197,33,1),(198,33,1),(199,33,1),(200,33,1),(201,33,1),(202,33,1),(203,33,1),
(204,33,0),(205,33,0),(206,33,0),
-- Viaje 36 (bus 6, ENS-TJ, 11 pasajeros)
(246,36,1),(247,36,1),(248,36,1),(249,36,1),(250,36,1),(251,36,1),(252,36,1),(253,36,1),
(254,36,1),(255,36,1),(256,36,1),(257,36,0),(258,36,0),
-- Viaje 37 (bus 7, MXL-TJ, 13 pasajeros)
(298,37,1),(299,37,1),(300,37,1),(301,37,1),(302,37,1),(303,37,1),(304,37,1),(305,37,1),
(306,37,1),(307,37,1),(308,37,1),(309,37,1),(310,37,1),(311,37,0),(312,37,0),
-- Viaje 38 (bus 8, TJ-ENS, 10 pasajeros)
(346,38,1),(347,38,1),(348,38,1),(349,38,1),(350,38,1),(351,38,1),(352,38,1),(353,38,1),
(354,38,1),(355,38,1),(356,38,0),(357,38,0),
-- Viaje 39 (bus 9, TJ-RSO, 8 pasajeros)
(396,39,1),(397,39,1),(398,39,1),(399,39,1),(400,39,1),(401,39,1),(402,39,1),(403,39,1),
(404,39,0),(405,39,0),
-- Viaje 40 (bus 10, TJ-MXL, 15 pasajeros)
(442,40,1),(443,40,1),(444,40,1),(445,40,1),(446,40,1),(447,40,1),(448,40,1),(449,40,1),
(450,40,1),(451,40,1),(452,40,1),(453,40,1),(454,40,1),(455,40,1),(456,40,1),(457,40,0),
-- Viaje 41 (bus 1, TJ-ENS, 9 pasajeros)
(1,41,1),(2,41,1),(3,41,1),(4,41,1),(5,41,1),(6,41,1),(7,41,1),(8,41,1),
(9,41,1),(10,41,0),(11,41,0),
-- Viaje 42 (bus 2, ENS-TJ, 7 pasajeros)
(53,42,1),(54,42,1),(55,42,1),(56,42,1),(57,42,1),(58,42,1),(59,42,1),(60,42,0),(61,42,0),
-- Viaje 43 (bus 3, TJ-RSO, 10 pasajeros)
(101,43,1),(102,43,1),(103,43,1),(104,43,1),(105,43,1),(106,43,1),(107,43,1),(108,43,1),
(109,43,1),(110,43,1),(111,43,0),(112,43,0),
-- Viaje 44 (bus 4, TJ-MXL, 18 ocupados — en ruta hoy)
(151,44,1),(152,44,1),(153,44,1),(154,44,1),(155,44,1),(156,44,1),(157,44,1),(158,44,1),
(159,44,1),(160,44,1),(161,44,1),(162,44,1),(163,44,1),(164,44,1),(165,44,1),(166,44,1),
(167,44,1),(168,44,1),(169,44,0),(170,44,0),
-- Viaje 45 (bus 5, RSO-TJ, 6 ocupados — en ruta hoy)
(197,45,1),(198,45,1),(199,45,1),(200,45,1),(201,45,1),(202,45,1),(203,45,0),(204,45,0),
-- Viaje 46 (bus 6, TJ-ENS, 20 ocupados — en ruta hoy)
(246,46,1),(247,46,1),(248,46,1),(249,46,1),(250,46,1),(251,46,1),(252,46,1),(253,46,1),
(254,46,1),(255,46,1),(256,46,1),(257,46,1),(258,46,1),(259,46,1),(260,46,1),(261,46,1),
(262,46,1),(263,46,1),(264,46,1),(265,46,1),(266,46,0),(267,46,0);

-- ════════════════════════════════════════════════════════════
--  PAGOS
-- ════════════════════════════════════════════════════════════

INSERT INTO pago (numero, fechapago, monto, tipo, vendedor) VALUES
(1,  '2026-01-10 07:00:00',  720.00, 1,  1),
(2,  '2026-01-10 07:05:00',  350.00, 2,  1),
(3,  '2026-01-12 06:50:00', 1200.00, 1,  7),
(4,  '2026-01-12 06:55:00',  480.00, 2,  7),
(5,  '2026-01-15 07:30:00',  480.00, 1,  4),
(6,  '2026-01-20 08:30:00',   90.00, 1,  1),
(7,  '2026-01-22 06:45:00',  720.00, 1,  7),
(8,  '2026-01-25 09:00:00', 2100.00, 2,  4),
(9,  '2026-01-28 13:00:00',  480.00, 1,  1),
(10, '2026-01-28 13:05:00',  480.00, 2,  1),
(11, '2026-02-01 06:00:00',  180.00, 1,  1),
(12, '2026-02-05 07:30:00', 1200.00, 2,  7),
(13, '2026-02-10 08:45:00',  540.00, 1,  7),
(14, '2026-02-15 14:00:00',  270.00, 1,  4),
(15, '2026-02-18 06:30:00', 1050.00, 1,  1),
(16, '2026-02-20 07:45:00',  270.00, 2,  1),
(17, '2026-03-01 07:30:00', 1035.00, 1,  1),
(18, '2026-03-01 09:30:00', 3395.00, 2,  4),
(19, '2026-03-02 07:00:00', 2136.00, 1,  7),
(20, '2026-03-03 08:30:00', 2800.00, 2,  4),
(21, '2026-03-04 07:45:00',  621.00, 1,  1),
(22, '2026-03-05 06:15:00', 1926.00, 1, 10),
(23, '2026-03-06 06:00:00', 4462.50, 2,  4),
(24, '2026-03-07 07:30:00', 2388.00, 1,  7),
(25, '2026-03-08 08:30:00',  696.00, 1,  1),
(26, '2026-03-09 09:30:00', 5162.50, 2,  4),
(27, '2026-03-10 07:00:00', 2148.00, 1,  7),
(28, '2026-03-11 07:30:00', 1668.00, 1,  1),
(29, '2026-03-12 05:30:00',  861.00, 1,  1),
(30, '2026-03-13 06:30:00', 6212.50, 2,  4),
(31, '2026-03-13 08:00:00',  531.00, 1,  1),
(32, '2026-03-13 09:30:00', 4728.00, 2,  7);

-- ════════════════════════════════════════════════════════════
--  TICKETS
-- ════════════════════════════════════════════════════════════

INSERT INTO ticket (codigo, precio, fechaEmision, asiento, viaje, pasajero, tipopasajero, pago) VALUES
(1,  90.00, '2026-01-10 07:00:00',  1, 1,  1, 1,  1),
(2,  45.00, '2026-01-10 07:00:00',  2, 1, 41, 2,  1),
(3,  90.00, '2026-01-10 07:00:00',  3, 1,  2, 1,  1),
(4,  90.00, '2026-01-10 07:00:00',  4, 1,  3, 1,  1),
(5,  90.00, '2026-01-10 07:00:00',  5, 1,  4, 1,  1),
(6,  90.00, '2026-01-10 07:00:00',  6, 1,  5, 1,  1),
(7,  90.00, '2026-01-10 07:00:00',  7, 1,  6, 1,  1),
(8,  90.00, '2026-01-10 07:00:00',  8, 1,  7, 1,  1),
(9,  350.00, '2026-01-10 07:05:00', 53, 2,  9, 1,  2),
(10, 240.00, '2026-01-12 06:50:00', 101, 3, 10, 1, 3),
(11, 240.00, '2026-01-12 06:50:00', 102, 3, 11, 1, 3),
(12, 180.00, '2026-01-12 06:50:00', 103, 3, 12, 4, 3),
(13, 180.00, '2026-01-12 06:50:00', 104, 3, 13, 4, 3),
(14, 168.00, '2026-01-12 06:55:00', 105, 3, 71, 3, 4),
(15, 168.00, '2026-01-12 06:55:00', 106, 3, 72, 3, 4),
(16, 168.00, '2026-01-12 06:55:00', 107, 3, 73, 3, 4),
(17, 350.00, '2026-01-25 09:00:00', 151, 7, 14, 1, 8),
(18, 350.00, '2026-01-25 09:00:00', 152, 7, 15, 1, 8),
(19, 350.00, '2026-01-25 09:00:00', 153, 7, 16, 1, 8),
(20, 262.50, '2026-01-25 09:00:00', 154, 7, 17, 4, 8),
(21, 262.50, '2026-01-25 09:00:00', 155, 7, 18, 4, 8),
(22, 262.50, '2026-01-25 09:00:00', 156, 7, 19, 4, 8),
(23, 240.00, '2026-01-28 13:00:00', 197, 8, 20, 1,  9),
(24, 240.00, '2026-01-28 13:00:00', 198, 8, 21, 1,  9),
(25, 120.00, '2026-01-28 13:00:00', 199, 8, 43, 2,  9),
(26, 168.00, '2026-01-28 13:00:00', 200, 8, 22, 3,  9),
(27, 240.00, '2026-01-28 13:05:00', 201, 8, 23, 1, 10),
(28, 240.00, '2026-01-28 13:05:00', 202, 8, 24, 1, 10),
(29,  90.00, '2026-02-01 06:00:00',  1, 9, 25, 1, 11),
(30,  90.00, '2026-02-01 06:00:00',  2, 9, 26, 1, 11),
(31, 240.00, '2026-02-05 07:30:00', 53, 10, 27, 1, 12),
(32, 240.00, '2026-02-05 07:30:00', 54, 10, 28, 1, 12),
(33, 240.00, '2026-02-05 07:30:00', 55, 10, 29, 1, 12),
(34, 240.00, '2026-02-05 07:30:00', 56, 10, 30, 1, 12),
(35, 180.00, '2026-02-05 07:30:00', 57, 10, 41, 4, 12),
(36, 180.00, '2026-02-10 08:45:00', 101, 11, 101, 1, 13),
(37, 180.00, '2026-02-10 08:45:00', 102, 11, 102, 1, 13),
(38, 135.00, '2026-02-10 08:45:00', 103, 11, 103, 4, 13),
(39,  90.00, '2026-02-15 14:00:00', 151, 12, 104, 1, 14),
(40,  63.00, '2026-02-15 14:00:00', 152, 12,  71, 3, 14),
(41,  45.00, '2026-02-15 14:00:00', 153, 12,  44, 2, 14),
(42,  90.00, '2026-03-01 07:30:00',  1, 29,  1, 1, 17),
(43,  45.00, '2026-03-01 07:30:00',  2, 29, 41, 2, 17),
(44,  90.00, '2026-03-01 07:30:00',  3, 29,  2, 1, 17),
(45,  90.00, '2026-03-01 07:30:00',  4, 29,  3, 1, 17),
(46,  90.00, '2026-03-01 07:30:00',  5, 29,  4, 1, 17),
(47,  90.00, '2026-03-01 07:30:00',  6, 29,  5, 1, 17),
(48,  63.00, '2026-03-01 07:30:00',  7, 29, 71, 3, 17),
(49,  63.00, '2026-03-01 07:30:00',  8, 29, 72, 3, 17),
(50,  90.00, '2026-03-01 07:30:00',  9, 29,  6, 1, 17),
(51,  90.00, '2026-03-01 07:30:00', 10, 29,  7, 1, 17),
(52,  90.00, '2026-03-01 07:30:00', 11, 29,  8, 1, 17),
(53,  90.00, '2026-03-01 07:30:00', 12, 29,  9, 1, 17),
(54, 350.00, '2026-03-01 09:30:00', 53, 30, 10, 1, 18),
(55, 350.00, '2026-03-01 09:30:00', 54, 30, 11, 1, 18),
(56, 262.50, '2026-03-01 09:30:00', 55, 30, 12, 4, 18),
(57, 350.00, '2026-03-01 09:30:00', 56, 30, 13, 1, 18),
(58, 350.00, '2026-03-01 09:30:00', 57, 30, 14, 1, 18),
(59, 350.00, '2026-03-01 09:30:00', 58, 30, 15, 1, 18),
(60, 245.00, '2026-03-01 09:30:00', 59, 30, 73, 3, 18),
(61, 350.00, '2026-03-01 09:30:00', 60, 30, 16, 1, 18),
(62, 350.00, '2026-03-01 09:30:00', 61, 30, 17, 1, 18),
(63, 338.00, '2026-03-01 09:30:00', 62, 30, 18, 1, 18),
(64, 240.00, '2026-03-02 07:00:00', 101, 31, 19, 1, 19),
(65, 240.00, '2026-03-02 07:00:00', 102, 31, 20, 1, 19),
(66, 180.00, '2026-03-02 07:00:00', 103, 31, 21, 4, 19),
(67, 240.00, '2026-03-02 07:00:00', 104, 31, 22, 1, 19),
(68, 240.00, '2026-03-02 07:00:00', 105, 31, 23, 1, 19),
(69, 168.00, '2026-03-02 07:00:00', 106, 31, 74, 3, 19),
(70, 240.00, '2026-03-02 07:00:00', 107, 31, 24, 1, 19),
(71, 120.00, '2026-03-02 07:00:00', 108, 31, 42, 2, 19),
(72, 240.00, '2026-03-02 07:00:00', 109, 31, 25, 1, 19),
(73, 350.00, '2026-03-03 08:30:00', 151, 32, 26, 1, 20),
(74, 350.00, '2026-03-03 08:30:00', 152, 32, 27, 1, 20),
(75, 350.00, '2026-03-03 08:30:00', 153, 32, 28, 1, 20),
(76, 262.50, '2026-03-03 08:30:00', 154, 32, 29, 4, 20),
(77, 350.00, '2026-03-03 08:30:00', 155, 32, 30, 1, 20),
(78, 350.00, '2026-03-03 08:30:00', 156, 32,  1, 1, 20),
(79, 262.50, '2026-03-03 08:30:00', 157, 32,101, 4, 20),
(80, 350.00, '2026-03-03 08:30:00', 158, 32,  2, 1, 20),
(81,  90.00, '2026-03-04 07:45:00', 197, 33,  3, 1, 21),
(82,  90.00, '2026-03-04 07:45:00', 198, 33,  4, 1, 21),
(83,  45.00, '2026-03-04 07:45:00', 199, 33, 43, 2, 21),
(84,  90.00, '2026-03-04 07:45:00', 200, 33,  5, 1, 21),
(85,  63.00, '2026-03-04 07:45:00', 201, 33, 71, 3, 21),
(86,  90.00, '2026-03-04 07:45:00', 202, 33,  6, 1, 21),
(87,  63.00, '2026-03-04 07:45:00', 203, 33, 72, 3, 21),
(88, 180.00, '2026-03-05 06:15:00', 246, 36,  7, 1, 22),
(89, 180.00, '2026-03-05 06:15:00', 247, 36,  8, 1, 22),
(90, 135.00, '2026-03-05 06:15:00', 248, 36,102, 4, 22),
(91, 180.00, '2026-03-05 06:15:00', 249, 36,  9, 1, 22),
(92, 180.00, '2026-03-05 06:15:00', 250, 36, 10, 1, 22),
(93, 126.00, '2026-03-05 06:15:00', 251, 36, 73, 3, 22),
(94, 180.00, '2026-03-05 06:15:00', 252, 36, 11, 1, 22),
(95, 180.00, '2026-03-05 06:15:00', 253, 36, 12, 1, 22),
(96, 135.00, '2026-03-05 06:15:00', 254, 36,103, 4, 22),
(97, 180.00, '2026-03-05 06:15:00', 255, 36, 13, 1, 22),
(98, 180.00, '2026-03-05 06:15:00', 256, 36, 14, 1, 22),
(99,  350.00, '2026-03-06 06:00:00', 298, 37, 15, 1, 23),
(100, 350.00, '2026-03-06 06:00:00', 299, 37, 16, 1, 23),
(101, 262.50, '2026-03-06 06:00:00', 300, 37,104, 4, 23),
(102, 350.00, '2026-03-06 06:00:00', 301, 37, 17, 1, 23),
(103, 350.00, '2026-03-06 06:00:00', 302, 37, 18, 1, 23),
(104, 245.00, '2026-03-06 06:00:00', 303, 37, 74, 3, 23),
(105, 350.00, '2026-03-06 06:00:00', 304, 37, 19, 1, 23),
(106, 350.00, '2026-03-06 06:00:00', 305, 37, 20, 1, 23),
(107, 350.00, '2026-03-06 06:00:00', 306, 37, 21, 1, 23),
(108, 262.50, '2026-03-06 06:00:00', 307, 37,105, 4, 23),
(109, 350.00, '2026-03-06 06:00:00', 308, 37, 22, 1, 23),
(110, 350.00, '2026-03-06 06:00:00', 309, 37, 23, 1, 23),
(111, 350.00, '2026-03-06 06:00:00', 310, 37, 24, 1, 23),
(112, 240.00, '2026-03-07 07:30:00', 346, 38, 25, 1, 24),
(113, 240.00, '2026-03-07 07:30:00', 347, 38, 26, 1, 24),
(114, 180.00, '2026-03-07 07:30:00', 348, 38,106, 4, 24),
(115, 240.00, '2026-03-07 07:30:00', 349, 38, 27, 1, 24),
(116, 168.00, '2026-03-07 07:30:00', 350, 38, 71, 3, 24),
(117, 240.00, '2026-03-07 07:30:00', 351, 38, 28, 1, 24),
(118, 240.00, '2026-03-07 07:30:00', 352, 38, 29, 1, 24),
(119, 180.00, '2026-03-07 07:30:00', 353, 38,107, 4, 24),
(120, 240.00, '2026-03-07 07:30:00', 354, 38, 30, 1, 24),
(121, 240.00, '2026-03-07 07:30:00', 355, 38,  1, 1, 24),
(122,  90.00, '2026-03-08 08:30:00', 396, 39,  2, 1, 25),
(123,  45.00, '2026-03-08 08:30:00', 397, 39, 44, 2, 25),
(124,  90.00, '2026-03-08 08:30:00', 398, 39,  3, 1, 25),
(125,  90.00, '2026-03-08 08:30:00', 399, 39,  4, 1, 25),
(126,  63.00, '2026-03-08 08:30:00', 400, 39, 72, 3, 25),
(127,  90.00, '2026-03-08 08:30:00', 401, 39,  5, 1, 25),
(128,  90.00, '2026-03-08 08:30:00', 402, 39,  6, 1, 25),
(129,  63.00, '2026-03-08 08:30:00', 403, 39, 73, 3, 25),
(130, 350.00, '2026-03-09 09:30:00', 442, 40,  7, 1, 26),
(131, 350.00, '2026-03-09 09:30:00', 443, 40,  8, 1, 26),
(132, 262.50, '2026-03-09 09:30:00', 444, 40,108, 4, 26),
(133, 350.00, '2026-03-09 09:30:00', 445, 40,  9, 1, 26),
(134, 350.00, '2026-03-09 09:30:00', 446, 40, 10, 1, 26),
(135, 350.00, '2026-03-09 09:30:00', 447, 40, 11, 1, 26),
(136, 245.00, '2026-03-09 09:30:00', 448, 40, 74, 3, 26),
(137, 350.00, '2026-03-09 09:30:00', 449, 40, 12, 1, 26),
(138, 350.00, '2026-03-09 09:30:00', 450, 40, 13, 1, 26),
(139, 350.00, '2026-03-09 09:30:00', 451, 40, 14, 1, 26),
(140, 262.50, '2026-03-09 09:30:00', 452, 40,101, 4, 26),
(141, 350.00, '2026-03-09 09:30:00', 453, 40, 15, 1, 26),
(142, 350.00, '2026-03-09 09:30:00', 454, 40, 16, 1, 26),
(143, 350.00, '2026-03-09 09:30:00', 455, 40, 17, 1, 26),
(144, 350.00, '2026-03-09 09:30:00', 456, 40, 18, 1, 26),
(145, 240.00, '2026-03-10 07:00:00',  1, 41, 19, 1, 27),
(146, 240.00, '2026-03-10 07:00:00',  2, 41, 20, 1, 27),
(147, 180.00, '2026-03-10 07:00:00',  3, 41,102, 4, 27),
(148, 240.00, '2026-03-10 07:00:00',  4, 41, 21, 1, 27),
(149, 240.00, '2026-03-10 07:00:00',  5, 41, 22, 1, 27),
(150, 168.00, '2026-03-10 07:00:00',  6, 41, 71, 3, 27),
(151, 240.00, '2026-03-10 07:00:00',  7, 41, 23, 1, 27),
(152, 240.00, '2026-03-10 07:00:00',  8, 41, 24, 1, 27),
(153, 240.00, '2026-03-10 07:00:00',  9, 41, 25, 1, 27),
(154, 240.00, '2026-03-11 07:30:00', 53, 42, 26, 1, 28),
(155, 240.00, '2026-03-11 07:30:00', 54, 42, 27, 1, 28),
(156, 180.00, '2026-03-11 07:30:00', 55, 42,103, 4, 28),
(157, 240.00, '2026-03-11 07:30:00', 56, 42, 28, 1, 28),
(158, 168.00, '2026-03-11 07:30:00', 57, 42, 72, 3, 28),
(159, 240.00, '2026-03-11 07:30:00', 58, 42, 29, 1, 28),
(160, 240.00, '2026-03-11 07:30:00', 59, 42, 30, 1, 28),
(161,  90.00, '2026-03-12 05:30:00', 101, 43,  1, 1, 29),
(162,  45.00, '2026-03-12 05:30:00', 102, 43, 41, 2, 29),
(163,  90.00, '2026-03-12 05:30:00', 103, 43,  2, 1, 29),
(164,  90.00, '2026-03-12 05:30:00', 104, 43,  3, 1, 29),
(165,  63.00, '2026-03-12 05:30:00', 105, 43, 73, 3, 29),
(166,  90.00, '2026-03-12 05:30:00', 106, 43,  4, 1, 29),
(167,  90.00, '2026-03-12 05:30:00', 107, 43,  5, 1, 29),
(168,  90.00, '2026-03-12 05:30:00', 108, 43,  6, 1, 29),
(169,  90.00, '2026-03-12 05:30:00', 109, 43,  7, 1, 29),
(170,  90.00, '2026-03-12 05:30:00', 110, 43,  8, 1, 29),
(171, 350.00, '2026-03-13 06:30:00', 151, 44,  9, 1, 30),
(172, 350.00, '2026-03-13 06:30:00', 152, 44, 10, 1, 30),
(173, 262.50, '2026-03-13 06:30:00', 153, 44,104, 4, 30),
(174, 350.00, '2026-03-13 06:30:00', 154, 44, 11, 1, 30),
(175, 350.00, '2026-03-13 06:30:00', 155, 44, 12, 1, 30),
(176, 350.00, '2026-03-13 06:30:00', 156, 44, 13, 1, 30),
(177, 245.00, '2026-03-13 06:30:00', 157, 44, 74, 3, 30),
(178, 350.00, '2026-03-13 06:30:00', 158, 44, 14, 1, 30),
(179, 350.00, '2026-03-13 06:30:00', 159, 44, 15, 1, 30),
(180, 350.00, '2026-03-13 06:30:00', 160, 44, 16, 1, 30),
(181, 262.50, '2026-03-13 06:30:00', 161, 44,105, 4, 30),
(182, 350.00, '2026-03-13 06:30:00', 162, 44, 17, 1, 30),
(183, 350.00, '2026-03-13 06:30:00', 163, 44, 18, 1, 30),
(184, 350.00, '2026-03-13 06:30:00', 164, 44, 19, 1, 30),
(185, 350.00, '2026-03-13 06:30:00', 165, 44, 20, 1, 30),
(186, 350.00, '2026-03-13 06:30:00', 166, 44, 21, 1, 30),
(187, 350.00, '2026-03-13 06:30:00', 167, 44, 22, 1, 30),
(188, 350.00, '2026-03-13 06:30:00', 168, 44, 23, 1, 30),
(189,  90.00, '2026-03-13 08:00:00', 197, 45, 24, 1, 31),
(190,  90.00, '2026-03-13 08:00:00', 198, 45, 25, 1, 31),
(191,  45.00, '2026-03-13 08:00:00', 199, 45, 43, 2, 31),
(192,  90.00, '2026-03-13 08:00:00', 200, 45, 26, 1, 31),
(193,  63.00, '2026-03-13 08:00:00', 201, 45, 71, 3, 31),
(194,  90.00, '2026-03-13 08:00:00', 202, 45, 27, 1, 31),
(195, 240.00, '2026-03-13 09:30:00', 246, 46, 28, 1, 32),
(196, 240.00, '2026-03-13 09:30:00', 247, 46, 29, 1, 32),
(197, 180.00, '2026-03-13 09:30:00', 248, 46,106, 4, 32),
(198, 240.00, '2026-03-13 09:30:00', 249, 46, 30, 1, 32),
(199, 240.00, '2026-03-13 09:30:00', 250, 46,  1, 1, 32),
(200, 168.00, '2026-03-13 09:30:00', 251, 46, 72, 3, 32),
(201, 240.00, '2026-03-13 09:30:00', 252, 46,  2, 1, 32),
(202, 240.00, '2026-03-13 09:30:00', 253, 46,  3, 1, 32),
(203, 180.00, '2026-03-13 09:30:00', 254, 46,107, 4, 32),
(204, 240.00, '2026-03-13 09:30:00', 255, 46,  4, 1, 32),
(205, 240.00, '2026-03-13 09:30:00', 256, 46,  5, 1, 32),
(206, 240.00, '2026-03-13 09:30:00', 257, 46,  6, 1, 32),
(207, 240.00, '2026-03-13 09:30:00', 258, 46,  7, 1, 32),
(208, 168.00, '2026-03-13 09:30:00', 259, 46, 73, 3, 32),
(209, 240.00, '2026-03-13 09:30:00', 260, 46,  8, 1, 32),
(210, 240.00, '2026-03-13 09:30:00', 261, 46,  9, 1, 32),
(211, 240.00, '2026-03-13 09:30:00', 262, 46, 10, 1, 32),
(212, 240.00, '2026-03-13 09:30:00', 263, 46, 11, 1, 32),
(213, 240.00, '2026-03-13 09:30:00', 264, 46, 12, 1, 32),
(214, 240.00, '2026-03-13 09:30:00', 265, 46, 13, 1, 32);

-- ════════════════════════════════════════════════════════════
--  Verificacion
-- ════════════════════════════════════════════════════════════
SELECT 'viajes'         AS tabla, COUNT(*) AS total FROM viaje;
SELECT 'tickets'        AS tabla, COUNT(*) AS total FROM ticket;
SELECT 'pagos'          AS tabla, COUNT(*) AS total FROM pago;
SELECT 'pasajeros'      AS tabla, COUNT(*) AS total FROM pasajero;
SELECT 'cuentas'        AS tabla, COUNT(*) AS total FROM cuenta_pasajero;
SELECT 'viajes marzo'   AS tabla, COUNT(*) AS total FROM viaje WHERE fecHoraSalida >= '2026-03-01';

-- Prueba de la vista
SELECT num, paNombre, paPrimerApell, edad FROM vista_pasajeros_edad LIMIT 5;

SELECT * FROM viaje_asiento WHERE viaje = 100 AND ocupado = 1;

INSERT INTO viaje_asiento (asiento, viaje, ocupado)
SELECT a.numero, v.numero, 0
FROM viaje v
JOIN asiento a ON a.autobus = v.autobus
WHERE v.numero IN (47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67);

UPDATE viaje_asiento va
JOIN ticket t ON t.asiento = va.asiento AND t.viaje = va.viaje
SET va.ocupado = 1
WHERE va.viaje IN (47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67);
SELECT * FROM viaje_asiento WHERE viaje = 62 AND ocupado = 1;

SELECT * FROM cuenta_pasajero ORDER BY pasajero_num DESC LIMIT 5;
SELECT * FROM edo_viaje;

ALTER TABLE ticket 
ADD COLUMN etiqueta_asiento VARCHAR(10);

ALTER TABLE taquillero MODIFY contrasena VARCHAR(255) NOT NULL;
