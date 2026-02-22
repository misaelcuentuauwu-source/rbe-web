-- Active: 1760978807635@@127.0.0.1@3306@rbe
-- ============================================================
-- RBE - Rutas Baja Express
-- Script completo: schema + datos
-- Actualizado: Febrero 2026
-- Usuario de prueba supervisor: za / za
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

CREATE TABLE pasajero (
    num INT PRIMARY KEY AUTO_INCREMENT,
    paNombre VARCHAR(30) NOT NULL,
    paPrimerApell VARCHAR(30) NOT NULL,
    paSegundoApell VARCHAR(30),
    fechaNacimiento DATE NOT NULL,
    edad INT
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
(1, 'Central Tijuana',      'Blvd. Insurgentes',       '2100',   'El Florido',      '6641123344', 'TJ'),
(2, 'Central Mexicali',     'Calz. Independencia',      '501',    'Pueblo Nuevo',    '6862219080', 'MXL'),
(3, 'Central Ensenada',     'Av. Reforma',              '1245',   'Moderna',         '6463317722', 'ENS'),
(4, 'Terminal Tecate',      'Blvd. Benito Juarez',      '780',    'Las Palmas',      '6652294433', 'TEC'),
(5, 'Terminal Rosarito',    'Blvd. Popotla',            '455',    'Centro',          '6611238899', 'RSO'),
(6, 'Terminal San Quintin', 'Carretera Transpeninsular', 'KM 189', 'Lazaro Cardenas', '6161237700', 'SQN'),
(7, 'Terminal San Felipe',  'Av. Mar de Cortes',        '320',    'Centro',          '6861985522', 'SFE');

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

-- ── Asientos autobus 1 (52) ───────────────────────────────────

INSERT INTO asiento (numero, tipo, autobus) VALUES
(1,'DIS',1),(2,'PLU',1),(3,'DIS',1),(4,'PLU',1),(5,'PLU',1),(6,'PLU',1),(7,'PLU',1),(8,'PLU',1),
(9,'COM',1),(10,'COM',1),(11,'COM',1),(12,'COM',1),(13,'COM',1),(14,'COM',1),(15,'COM',1),(16,'COM',1),
(17,'COM',1),(18,'COM',1),(19,'COM',1),(20,'COM',1),(21,'COM',1),(22,'COM',1),(23,'COM',1),(24,'COM',1),
(25,'COM',1),(26,'COM',1),(27,'COM',1),(28,'COM',1),(29,'COM',1),(30,'COM',1),(31,'COM',1),(32,'COM',1),
(33,'COM',1),(34,'COM',1),(35,'COM',1),(36,'COM',1),(37,'COM',1),(38,'COM',1),(39,'COM',1),(40,'COM',1),
(41,'COM',1),(42,'COM',1),(43,'COM',1),(44,'COM',1),(45,'COM',1),(46,'COM',1),(47,'COM',1),(48,'DIS',1),
(49,'COM',1),(50,'COM',1),(51,'COM',1),(52,'COM',1),
-- autobus 2 (48)
(53,'PLU',2),(54,'PLU',2),(55,'DIS',2),(56,'PLU',2),(57,'PLU',2),(58,'PLU',2),(59,'PLU',2),(60,'PLU',2),
(61,'COM',2),(62,'COM',2),(63,'COM',2),(64,'COM',2),(65,'COM',2),(66,'COM',2),(67,'COM',2),(68,'COM',2),
(69,'COM',2),(70,'COM',2),(71,'COM',2),(72,'COM',2),(73,'COM',2),(74,'COM',2),(75,'COM',2),(76,'COM',2),
(77,'COM',2),(78,'COM',2),(79,'COM',2),(80,'COM',2),(81,'COM',2),(82,'COM',2),(83,'COM',2),(84,'COM',2),
(85,'COM',2),(86,'COM',2),(87,'COM',2),(88,'COM',2),(89,'COM',2),(90,'COM',2),(91,'COM',2),(92,'COM',2),
(93,'COM',2),(94,'COM',2),(95,'COM',2),(96,'COM',2),(97,'COM',2),(98,'COM',2),(99,'DIS',2),(100,'DIS',2),
-- autobus 3 (50)
(101,'DIS',3),(102,'PLU',3),(103,'DIS',3),(104,'PLU',3),(105,'PLU',3),(106,'PLU',3),(107,'PLU',3),(108,'PLU',3),
(109,'COM',3),(110,'COM',3),(111,'COM',3),(112,'COM',3),(113,'COM',3),(114,'COM',3),(115,'COM',3),(116,'COM',3),
(117,'COM',3),(118,'COM',3),(119,'COM',3),(120,'COM',3),(121,'COM',3),(122,'COM',3),(123,'COM',3),(124,'COM',3),
(125,'COM',3),(126,'COM',3),(127,'COM',3),(128,'COM',3),(129,'COM',3),(130,'COM',3),(131,'COM',3),(132,'COM',3),
(133,'COM',3),(134,'COM',3),(135,'COM',3),(136,'COM',3),(137,'COM',3),(138,'COM',3),(139,'COM',3),(140,'COM',3),
(141,'COM',3),(142,'COM',3),(143,'COM',3),(144,'COM',3),(145,'COM',3),(146,'COM',3),(147,'COM',3),(148,'COM',3),
(149,'COM',3),(150,'COM',3),
-- autobus 4 (46)
(151,'DIS',4),(152,'PLU',4),(153,'DIS',4),(154,'PLU',4),(155,'PLU',4),(156,'PLU',4),(157,'PLU',4),(158,'PLU',4),
(159,'COM',4),(160,'COM',4),(161,'COM',4),(162,'COM',4),(163,'COM',4),(164,'COM',4),(165,'COM',4),(166,'COM',4),
(167,'COM',4),(168,'COM',4),(169,'COM',4),(170,'COM',4),(171,'COM',4),(172,'COM',4),(173,'COM',4),(174,'COM',4),
(175,'COM',4),(176,'COM',4),(177,'COM',4),(178,'COM',4),(179,'COM',4),(180,'COM',4),(181,'COM',4),(182,'COM',4),
(183,'COM',4),(184,'COM',4),(185,'COM',4),(186,'COM',4),(187,'COM',4),(188,'COM',4),(189,'COM',4),(190,'COM',4),
(191,'COM',4),(192,'COM',4),(193,'COM',4),(194,'COM',4),(195,'COM',4),(196,'COM',4),
-- autobus 5 (49)
(197,'DIS',5),(198,'PLU',5),(199,'DIS',5),(200,'PLU',5),(201,'PLU',5),(202,'PLU',5),(203,'PLU',5),(204,'PLU',5),
(205,'COM',5),(206,'COM',5),(207,'COM',5),(208,'COM',5),(209,'COM',5),(210,'COM',5),(211,'COM',5),(212,'COM',5),
(213,'COM',5),(214,'COM',5),(215,'COM',5),(216,'COM',5),(217,'COM',5),(218,'COM',5),(219,'COM',5),(220,'COM',5),
(221,'COM',5),(222,'COM',5),(223,'COM',5),(224,'COM',5),(225,'COM',5),(226,'COM',5),(227,'COM',5),(228,'COM',5),
(229,'COM',5),(230,'COM',5),(231,'COM',5),(232,'COM',5),(233,'COM',5),(234,'COM',5),(235,'COM',5),(236,'COM',5),
(237,'COM',5),(238,'COM',5),(239,'COM',5),(240,'COM',5),(241,'COM',5),(242,'COM',5),(243,'COM',5),(244,'COM',5),
(245,'COM',5),
-- autobus 6 (52) igual que bus 1
(246,'DIS',6),(247,'PLU',6),(248,'DIS',6),(249,'PLU',6),(250,'PLU',6),(251,'PLU',6),(252,'PLU',6),(253,'PLU',6),
(254,'COM',6),(255,'COM',6),(256,'COM',6),(257,'COM',6),(258,'COM',6),(259,'COM',6),(260,'COM',6),(261,'COM',6),
(262,'COM',6),(263,'COM',6),(264,'COM',6),(265,'COM',6),(266,'COM',6),(267,'COM',6),(268,'COM',6),(269,'COM',6),
(270,'COM',6),(271,'COM',6),(272,'COM',6),(273,'COM',6),(274,'COM',6),(275,'COM',6),(276,'COM',6),(277,'COM',6),
(278,'COM',6),(279,'COM',6),(280,'COM',6),(281,'COM',6),(282,'COM',6),(283,'COM',6),(284,'COM',6),(285,'COM',6),
(286,'COM',6),(287,'COM',6),(288,'COM',6),(289,'COM',6),(290,'COM',6),(291,'COM',6),(292,'COM',6),(293,'DIS',6),
(294,'COM',6),(295,'COM',6),(296,'COM',6),(297,'COM',6),
-- autobus 7 (48) igual que bus 2
(298,'PLU',7),(299,'PLU',7),(300,'DIS',7),(301,'PLU',7),(302,'PLU',7),(303,'PLU',7),(304,'PLU',7),(305,'PLU',7),
(306,'COM',7),(307,'COM',7),(308,'COM',7),(309,'COM',7),(310,'COM',7),(311,'COM',7),(312,'COM',7),(313,'COM',7),
(314,'COM',7),(315,'COM',7),(316,'COM',7),(317,'COM',7),(318,'COM',7),(319,'COM',7),(320,'COM',7),(321,'COM',7),
(322,'COM',7),(323,'COM',7),(324,'COM',7),(325,'COM',7),(326,'COM',7),(327,'COM',7),(328,'COM',7),(329,'COM',7),
(330,'COM',7),(331,'COM',7),(332,'COM',7),(333,'COM',7),(334,'COM',7),(335,'COM',7),(336,'COM',7),(337,'COM',7),
(338,'COM',7),(339,'COM',7),(340,'COM',7),(341,'COM',7),(342,'COM',7),(343,'COM',7),(344,'DIS',7),(345,'DIS',7),
-- autobus 8 (50) igual que bus 3
(346,'DIS',8),(347,'PLU',8),(348,'DIS',8),(349,'PLU',8),(350,'PLU',8),(351,'PLU',8),(352,'PLU',8),(353,'PLU',8),
(354,'COM',8),(355,'COM',8),(356,'COM',8),(357,'COM',8),(358,'COM',8),(359,'COM',8),(360,'COM',8),(361,'COM',8),
(362,'COM',8),(363,'COM',8),(364,'COM',8),(365,'COM',8),(366,'COM',8),(367,'COM',8),(368,'COM',8),(369,'COM',8),
(370,'COM',8),(371,'COM',8),(372,'COM',8),(373,'COM',8),(374,'COM',8),(375,'COM',8),(376,'COM',8),(377,'COM',8),
(378,'COM',8),(379,'COM',8),(380,'COM',8),(381,'COM',8),(382,'COM',8),(383,'COM',8),(384,'COM',8),(385,'COM',8),
(386,'COM',8),(387,'COM',8),(388,'COM',8),(389,'COM',8),(390,'COM',8),(391,'COM',8),(392,'COM',8),(393,'COM',8),
(394,'COM',8),(395,'COM',8),
-- autobus 9 (46) igual que bus 4
(396,'DIS',9),(397,'PLU',9),(398,'DIS',9),(399,'PLU',9),(400,'PLU',9),(401,'PLU',9),(402,'PLU',9),(403,'PLU',9),
(404,'COM',9),(405,'COM',9),(406,'COM',9),(407,'COM',9),(408,'COM',9),(409,'COM',9),(410,'COM',9),(411,'COM',9),
(412,'COM',9),(413,'COM',9),(414,'COM',9),(415,'COM',9),(416,'COM',9),(417,'COM',9),(418,'COM',9),(419,'COM',9),
(420,'COM',9),(421,'COM',9),(422,'COM',9),(423,'COM',9),(424,'COM',9),(425,'COM',9),(426,'COM',9),(427,'COM',9),
(428,'COM',9),(429,'COM',9),(430,'COM',9),(431,'COM',9),(432,'COM',9),(433,'COM',9),(434,'COM',9),(435,'COM',9),
(436,'COM',9),(437,'COM',9),(438,'COM',9),(439,'COM',9),(440,'COM',9),(441,'COM',9),
-- autobus 10 (49) igual que bus 5
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

-- ── Pasajeros ─────────────────────────────────────────────────

INSERT INTO pasajero (num, paNombre, paPrimerApell, paSegundoApell, fechaNacimiento, edad) VALUES
(1,  'Alejandro', 'Torres',    'Lopez',     '1995-04-12', 30),
(2,  'Mariana',   'Hernandez', 'Cruz',      '1988-11-03', 37),
(3,  'Luis',      'Aguilar',   'Soto',      '2001-06-21', 24),
(4,  'Fernanda',  'Ruiz',      'Martinez',  '1999-09-15', 26),
(5,  'Ricardo',   'Medina',    'Vargas',    '1987-02-08', 38),
(6,  'Sofia',     'Castillo',  'Ponce',     '2005-12-01', 20),
(7,  'Mateo',     'Garcia',    'Leon',      '1991-05-22', 34),
(8,  'Daniela',   'Lopez',     'Silva',     '1993-10-09', 32),
(9,  'Jorge',     'Sanchez',   'Rivera',    '1980-03-14', 45),
(10, 'Paola',     'Ramirez',   'Diaz',      '1997-08-20', 28),
(11, 'Ivan',      'Flores',    'Navarro',   '2004-01-10', 22),
(12, 'Teresa',    'Morales',   'Romero',    '1985-06-30', 40),
(13, 'Pedro',     'Vargas',    'Camacho',   '1992-12-04', 33),
(14, 'Karen',     'Soto',      'Aguilar',   '1994-02-19', 31),
(15, 'Brenda',    'Leon',      'Herrera',   '1998-07-07', 27),
(16, 'Miguel',    'Cruz',      'Delgado',   '1989-01-23', 36),
(17, 'Ana',       'Molina',    'Rojas',     '2000-04-28', 25),
(18, 'Jesus',     'Paredes',   'Luna',      '1979-09-01', 46),
(19, 'Valeria',   'Cabrera',   'Solis',     '1996-11-12', 29),
(20, 'Hector',    'Ortega',    'Villalobos','1984-05-18', 41),
(21, 'Andrea',    'Castillo',  'Ramos',     '1999-03-22', 26),
(22, 'Carlos',    'Navarro',   'Cardenas',  '1993-07-30', 32),
(23, 'Elisa',     'Ramirez',   'Cruz',      '2002-10-17', 23),
(24, 'Omar',      'Herrera',   'Lozano',    '1988-04-25', 37),
(25, 'Natalia',   'Vega',      'Bernal',    '1997-03-04', 28),
(26, 'Diego',     'Tapia',     'Rivera',    '1990-08-16', 35),
(27, 'Laura',     'Camacho',   'Flores',    '1986-02-11', 39),
(28, 'Alan',      'Ruiz',      'Castro',    '2003-09-29', 22),
(29, 'Miriam',    'Rios',      'Sanchez',   '1995-06-10', 30),
(30, 'Esteban',   'Salinas',   'Duarte',    '1992-01-14', 33),
(41, 'Diego',     'Torres',    'Soto',      '2016-07-14',  9),
(42, 'Camila',    'Hernandez', 'Ruiz',      '2015-02-01', 11),
(43, 'Samuel',    'Medina',    'Lopez',     '2017-11-23',  8),
(44, 'Zoe',       'Aguilar',   'Vega',      '2019-03-08',  6),
(71, 'Hector',    'Sepulveda', 'Ramos',     '1955-04-12', 70),
(72, 'Rosa',      'Camacho',   'Valenzuela','1948-11-22', 77),
(73, 'Manuel',    'Ramirez',   'Castro',    '1952-06-01', 73),
(74, 'Irma',      'Martinez',  'Rivas',     '1945-02-14', 80),
(101,'Anwar',     'Estrada',   'Santos',    '2006-04-14', 19),
(102,'Salvador',  'Garcia',    'Bojorquez', '2006-02-17', 19),
(103,'Elver',     'Ignacio',   'Bernal',    '1985-04-25', 40),
(104,'Jose',      'Perez',     'Lopez',     '1970-08-26', 55),
(105,'Maria',     'Madrigal',  'Gutierrez', '1980-10-23', 45),
(106,'Misael',    'Urquidez',  'Arredondo', '2006-03-14', 19),
(107,'Leonardo',  'Castillo',  'Mora',      '1998-04-12', 27),
(108,'Valeria',   'Nunes',     'Rivas',     '2002-09-03', 23);

-- ── Viajes (2026) ─────────────────────────────────────────────
-- Estado 3=Finalizado, 2=En Ruta, 1=Disponible, 5=Retrasado

INSERT INTO viaje (numero, fecHoraSalida, fecHoraEntrada, ruta, estado, autobus, conductor) VALUES
-- Finalizados enero 2026
(1,  '2026-01-10 08:00:00', '2026-01-10 08:45:00', 1,  3, 1,  1),
(2,  '2026-01-10 10:00:00', '2026-01-10 12:50:00', 7,  3, 2,  2),
(3,  '2026-01-12 07:30:00', '2026-01-12 09:30:00', 3,  3, 3,  3),
(4,  '2026-01-15 08:00:00', '2026-01-15 10:00:00', 4,  3, 1,  1),
(5,  '2026-01-20 09:00:00', '2026-01-20 09:45:00', 2,  3, 2,  2),
(6,  '2026-01-22 07:30:00', '2026-01-22 09:30:00', 3,  3, 3,  3),
(7,  '2026-01-25 10:00:00', '2026-01-25 12:50:00', 7,  3, 4,  4),
(8,  '2026-01-28 14:00:00', '2026-01-28 16:00:00', 4,  3, 5,  5),
-- Finalizados febrero 2026
(9,  '2026-02-01 06:30:00', '2026-02-01 07:15:00', 1,  3, 1,  1),
(10, '2026-02-05 08:00:00', '2026-02-05 10:00:00', 3,  3, 2,  2),
(11, '2026-02-10 09:15:00', '2026-02-10 10:30:00', 5,  3, 3,  2),
(12, '2026-02-15 15:00:00', '2026-02-15 15:45:00', 2,  3, 4,  4),
(13, '2026-02-18 07:00:00', '2026-02-18 09:50:00', 7,  3, 6,  6),
(14, '2026-02-20 08:00:00', '2026-02-20 08:45:00', 1,  3, 7,  9),
-- En ruta hoy 21-Feb-2026
(15, '2026-02-21 07:00:00', '2026-02-21 09:50:00', 7,  2, 1,  1),
(16, '2026-02-21 08:30:00', '2026-02-21 09:15:00', 1,  2, 4,  4),
-- Disponibles proximos dias
(17, '2026-02-22 06:00:00', '2026-02-22 08:50:00', 7,  1, 2,  2),
(18, '2026-02-22 09:00:00', '2026-02-22 09:45:00', 2,  1, 7,  7),
(19, '2026-02-22 14:00:00', '2026-02-22 16:00:00', 3,  1, 1,  6),
(20, '2026-02-23 07:00:00', '2026-02-23 09:00:00', 4,  1, 3,  3),
(21, '2026-02-23 18:00:00', '2026-02-23 19:15:00', 5,  1, 8,  5),
(22, '2026-02-24 10:00:00', '2026-02-24 11:15:00', 6,  1, 6,  7),
(23, '2026-02-24 16:00:00', '2026-02-24 18:50:00', 7,  1, 9,  1),
(24, '2026-02-25 08:00:00', '2026-02-25 10:50:00', 8,  1, 10, 8),
(25, '2026-02-25 12:00:00', '2026-02-25 14:00:00', 9,  1, 2,  3),
(26, '2026-02-26 06:00:00', '2026-02-26 09:00:00', 11, 1, 5,  4),
(27, '2026-02-27 08:00:00', '2026-02-27 12:00:00', 13, 1, 9,  7),
(28, '2026-02-28 09:00:00', '2026-02-28 12:15:00', 17, 1, 3,  6),
(29, '2026-03-01 07:00:00', '2026-03-01 13:00:00', 15, 1, 6,  5),
(30, '2026-03-02 18:00:00', '2026-03-03 00:00:00', 16, 1, 10, 4),
(31, '2026-03-03 08:00:00', '2026-03-03 13:00:00', 19, 1, 8,  9),
(32, '2026-03-05 10:00:00', '2026-03-05 16:30:00', 21, 1, 5,  4),
(33, '2026-03-07 07:00:00', '2026-03-07 14:00:00', 37, 1, 4,  10),
-- Retrasado
(34, '2026-02-21 06:00:00', '2026-02-21 07:00:00', 23, 5, 6,  11),
-- Cancelado
(35, '2026-02-20 10:00:00', '2026-02-20 11:00:00', 24, 4, 3,  12);

-- ── viaje_asiento ─────────────────────────────────────────────

INSERT INTO viaje_asiento (asiento, viaje, ocupado) VALUES
-- Viaje 1 (finalizado, autobus 1, ruta TJ-RSO)
(1,1,1),(2,1,1),(3,1,1),(4,1,1),(5,1,1),(6,1,1),(7,1,1),(8,1,1),
(9,1,1),(10,1,1),(11,1,1),(12,1,1),(13,1,0),(14,1,0),(15,1,0),
-- Viaje 2 (finalizado, autobus 2, ruta TJ-MXL)
(53,2,1),(54,2,1),(55,2,1),(56,2,1),(57,2,1),(58,2,1),(59,2,1),(60,2,1),
(61,2,1),(62,2,1),(63,2,1),(64,2,0),(65,2,0),(66,2,0),
-- Viaje 3 (finalizado, autobus 3, ruta TJ-ENS)
(101,3,1),(102,3,1),(103,3,1),(104,3,1),(105,3,1),(106,3,1),(107,3,1),(108,3,1),
(109,3,1),(110,3,1),(111,3,0),(112,3,0),(113,3,0),
-- Viaje 15 (en ruta, autobus 1)
(1,15,1),(2,15,1),(3,15,0),(4,15,1),(5,15,1),(6,15,0),(7,15,1),(8,15,1),
(9,15,1),(10,15,0),(11,15,1),(12,15,0),(13,15,1),(14,15,0),(15,15,1),
(16,15,0),(17,15,1),(18,15,0),(19,15,1),(20,15,0),
-- Viaje 16 (en ruta, autobus 4)
(151,16,1),(152,16,1),(153,16,0),(154,16,1),(159,16,1),(160,16,0),(161,16,1),
-- Viaje 17 (disponible, autobus 2)
(53,17,0),(54,17,0),(55,17,0),(56,17,0),(57,17,0),(58,17,0),(59,17,0),(60,17,0),
(61,17,0),(62,17,0),(63,17,0),(64,17,0),(65,17,0),(66,17,0),(67,17,0),(68,17,0),
-- Viaje 18 (disponible, autobus 7)
(298,18,0),(299,18,0),(300,18,0),(301,18,0),(302,18,0),(303,18,0),(304,18,0),(305,18,0),
(306,18,0),(307,18,0),(308,18,0),(309,18,0),(310,18,0),(311,18,0),(312,18,0),
-- Viaje 19 (disponible, autobus 1)
(1,19,0),(2,19,0),(3,19,0),(4,19,0),(5,19,0),(6,19,0),(7,19,0),(8,19,0),
(9,19,0),(10,19,0),(11,19,0),(12,19,0),(13,19,0),(14,19,0),(15,19,0),
-- Viaje 20 (disponible, autobus 3)
(101,20,0),(102,20,0),(103,20,0),(104,20,0),(105,20,0),(106,20,0),(107,20,0),(108,20,0),
(109,20,0),(110,20,0),(111,20,0),(112,20,0),(113,20,0),(114,20,0),(115,20,0);

-- ── Pagos ─────────────────────────────────────────────────────

INSERT INTO pago (numero, fechapago, monto, tipo, vendedor) VALUES
(1,  '2026-01-10 07:00:00',  720.00, 1, 1),
(2,  '2026-01-10 07:05:00',  350.00, 2, 1),
(3,  '2026-01-12 06:50:00', 1200.00, 1, 7),
(4,  '2026-01-12 06:55:00',  480.00, 2, 7),
(5,  '2026-01-15 07:30:00',  480.00, 1, 4),
(6,  '2026-01-20 08:30:00',   90.00, 1, 1),
(7,  '2026-01-22 06:45:00',  720.00, 1, 7),
(8,  '2026-01-25 09:00:00', 2100.00, 2, 4),
(9,  '2026-01-28 13:00:00',  480.00, 1, 1),
(10, '2026-01-28 13:05:00',  480.00, 2, 1),
(11, '2026-02-01 06:00:00',  180.00, 1, 1),
(12, '2026-02-05 07:30:00', 1200.00, 2, 7),
(13, '2026-02-10 08:45:00',  540.00, 1, 7),
(14, '2026-02-15 14:00:00',  270.00, 1, 4),
(15, '2026-02-18 06:30:00', 1050.00, 1, 1),
(16, '2026-02-20 07:45:00',  270.00, 2, 1);

-- ── Tickets ───────────────────────────────────────────────────

INSERT INTO ticket (codigo, precio, fechaEmision, asiento, viaje, pasajero, tipopasajero, pago) VALUES
-- Viaje 1 (TJ-RSO $90, autobus 1)
(1,  90.00, '2026-01-10 07:00:00',  1, 1,  1, 1,  1),
(2,  45.00, '2026-01-10 07:00:00',  2, 1, 41, 2,  1),
(3,  90.00, '2026-01-10 07:00:00',  3, 1,  2, 1,  1),
(4,  90.00, '2026-01-10 07:00:00',  4, 1,  3, 1,  1),
(5,  90.00, '2026-01-10 07:00:00',  5, 1,  4, 1,  1),
(6,  90.00, '2026-01-10 07:00:00',  6, 1,  5, 1,  1),
(7,  90.00, '2026-01-10 07:00:00',  7, 1,  6, 1,  1),
(8,  90.00, '2026-01-10 07:00:00',  8, 1,  7, 1,  1),
-- Viaje 2 (TJ-MXL $350, autobus 2)
(9,  350.00, '2026-01-10 07:05:00', 53, 2,  9, 1,  2),
-- Viaje 3 (TJ-ENS $240, autobus 3)
(10, 240.00, '2026-01-12 06:50:00', 101, 3, 10, 1,  3),
(11, 240.00, '2026-01-12 06:50:00', 102, 3, 11, 1,  3),
(12, 180.00, '2026-01-12 06:50:00', 103, 3, 12, 4,  3),
(13, 180.00, '2026-01-12 06:50:00', 104, 3, 13, 4,  3),
(14, 168.00, '2026-01-12 06:55:00', 105, 3, 71, 3,  4),
(15, 168.00, '2026-01-12 06:55:00', 106, 3, 72, 3,  4),
(16, 168.00, '2026-01-12 06:55:00', 107, 3, 73, 3,  4),
-- Viaje 7 (TJ-MXL $350, autobus 4)
(17, 350.00, '2026-01-25 09:00:00', 151, 7, 14, 1,  8),
(18, 350.00, '2026-01-25 09:00:00', 152, 7, 15, 1,  8),
(19, 350.00, '2026-01-25 09:00:00', 153, 7, 16, 1,  8),
(20, 262.50, '2026-01-25 09:00:00', 154, 7, 17, 4,  8),
(21, 262.50, '2026-01-25 09:00:00', 155, 7, 18, 4,  8),
(22, 262.50, '2026-01-25 09:00:00', 156, 7, 19, 4,  8),
-- Viaje 8 (ENS-TJ $240, autobus 5)
(23, 240.00, '2026-01-28 13:00:00', 197, 8, 20, 1,  9),
(24, 240.00, '2026-01-28 13:00:00', 198, 8, 21, 1,  9),
(25, 120.00, '2026-01-28 13:00:00', 199, 8, 43, 2,  9),
(26, 168.00, '2026-01-28 13:00:00', 200, 8, 22, 3,  9),
(27, 240.00, '2026-01-28 13:05:00', 201, 8, 23, 1, 10),
(28, 240.00, '2026-01-28 13:05:00', 202, 8, 24, 1, 10),
-- Viaje 9 (TJ-RSO $90, autobus 1)
(29,  90.00, '2026-02-01 06:00:00',  1, 9, 25, 1, 11),
(30,  90.00, '2026-02-01 06:00:00',  2, 9, 26, 1, 11),
-- Viaje 10 (TJ-ENS $240, autobus 2)
(31, 240.00, '2026-02-05 07:30:00', 53, 10, 27, 1, 12),
(32, 240.00, '2026-02-05 07:30:00', 54, 10, 28, 1, 12),
(33, 240.00, '2026-02-05 07:30:00', 55, 10, 29, 1, 12),
(34, 240.00, '2026-02-05 07:30:00', 56, 10, 30, 1, 12),
(35, 180.00, '2026-02-05 07:30:00', 57, 10, 41, 4, 12),
-- Viaje 11 (TJ-TEC $180, autobus 3)
(36, 180.00, '2026-02-10 08:45:00', 101, 11, 101, 1, 13),
(37, 180.00, '2026-02-10 08:45:00', 102, 11, 102, 1, 13),
(38, 135.00, '2026-02-10 08:45:00', 103, 11, 103, 4, 13),
-- Viaje 12 (RSO-TJ $90, autobus 4)
(39,  90.00, '2026-02-15 14:00:00', 151, 12, 104, 1, 14),
(40,  63.00, '2026-02-15 14:00:00', 152, 12, 71,  3, 14),
(41,  45.00, '2026-02-15 14:00:00', 153, 12, 44,  2, 14);