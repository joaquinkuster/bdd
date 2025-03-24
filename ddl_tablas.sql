-- Este archivo contiene comandos DDL (Data Definition Language) para la creación de la base de datos y tablas.

-- Crear la tabla de ciudades
CREATE TABLE ciudades (
    id SERIAL PRIMARY KEY,          -- ID único de la ciudad
    nombre VARCHAR(100) NOT NULL   -- Nombre de la ciudad
);


-- Crear la tabla de sucursales
CREATE TABLE sucursales (
    id SERIAL PRIMARY KEY,          -- ID único de la sucursal
    direccion VARCHAR(100) NOT NULL,        -- Dirección de la sucursal
    ciudad_id INT NOT NULL,         -- Relación con la tabla ciudades
    FOREIGN KEY (ciudad_id) REFERENCES ciudades(id) ON DELETE CASCADE
);


-- Crear la tabla de categorías
CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,          -- ID único de la categoría
    nombre VARCHAR(100) NOT NULL    -- Nombre de la categoría
);


-- Crear la tabla de productos (con UUID)
CREATE TABLE productos (
    id SERIAL PRIMARY KEY,  -- ID único del producto
    nombre VARCHAR(100) NOT NULL,   -- Nombre del producto
    descripcion TEXT,               -- Descripción del producto (opcional)
    precio DECIMAL(10, 2) NOT NULL, -- Precio del producto
    categoria_id INT NOT NULL,      -- Relación con la tabla categorias
    FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE CASCADE
);


-- Crear la tabla de inventario
CREATE TABLE inventario (
    producto_id INT NOT NULL,      -- Relación con la tabla productos
    sucursal_id INT NOT NULL,       -- Relación con la tabla sucursales
    cantidad INT NOT NULL,          -- Cantidad disponible en inventario
    PRIMARY KEY (producto_id, sucursal_id),  -- Clave primaria compuesta
    FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE,
    FOREIGN KEY (sucursal_id) REFERENCES sucursales(id) ON DELETE CASCADE
);
