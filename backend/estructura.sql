-- Active: 1769826674400@@127.0.0.1@3306@rbe
DROP DATABASE IF EXISTS rbe;
CREATE DATABASE rbe;
USE rbe;

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
