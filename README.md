# Bases de Datos Distribuidas con pgLogical

## Introducción
El trabajo presenta una solución para una empresa que necesita centralizar la información de sus sucursales, distribuir catálogos de productos y fragmentar los inventarios por sucursal. La empresa actualmente utiliza planillas de Excel, lo que dificulta el control centralizado. La propuesta es implementar una base de datos distribuida utilizando **pgLogical**, una extensión de PostgreSQL que permite la replicación lógica y selectiva de datos.

Además, la empresa busca implementar mecanismos de seguridad para la recuperación de información en caso de pérdidas, asegurando la disponibilidad de los datos. La replicación selectiva con **pgLogical** no solo mejora el uso de recursos, sino que también asegura que cada sucursal tenga acceso a la información que necesita, sin comprometer la integridad de los datos centrales.

## Objetivos
- **Centralización de la información**: Unificar la gestión de catálogos y sucursales en una base de datos central.
- **Fragmentación de inventarios**: Cada sucursal administra su propio inventario sin acceso a los datos de otras sucursales.
- **Seguridad y disponibilidad de datos**: Implementar replicación para minimizar la pérdida de información en caso de fallos.
- **Replicación eficiente**: Sincronización de datos sin sobrecargar la infraestructura.

---

## Comparación con otras soluciones
Antes de elegir **pgLogical**, se evaluaron otras tecnologías de replicación:

- **Replicación nativa de PostgreSQL**: No soporta replicación bidireccional, lo que limita su aplicabilidad para este caso.
- **Citus**: Ofrece escalabilidad horizontal y distribución de datos en grandes volúmenes, pero su configuración es compleja y no está enfocada en replicación selectiva.
- **BDR**: Soporta replicación bidireccional y resolución de conflictos, pero es más costoso y complejo que **pgLogical**.
- **rqlite**: No es compatible con PostgreSQL y tiene limitaciones en escalabilidad.

Por estas razones, **pgLogical** fue la mejor opción para una replicación lógica, flexible y bidireccional.

---

## Implementación Técnica

### Entorno de Prueba en Docker
Se configuró un entorno de prueba utilizando **Docker Compose** con los siguientes componentes:
- **Nodo central**: Administra catálogos y el inventario global.
- **Nodo de sucursal**: Solo puede modificar su propio inventario.
- **Adminer**: Interfaz de administración de bases de datos.

### Configuración de Replicación
1. **Creación de nodos de replicación**: El nodo central actúa como proveedor de información, mientras que las sucursales se suscriben a las publicaciones relevantes.
2. **Definición de conjuntos de replicación**: Se establecieron conjuntos de replicación para distribuir catálogos y gestionar inventarios de manera bidireccional.
3. **Implementación de replicación bidireccional**: Garantiza que las modificaciones en los inventarios de cada sucursal se reflejen en la base de datos central y viceversa.

---

## Creación de Tablas

Las siguientes tablas se crearon tanto en el nodo central como en las sucursales para permitir la replicación de datos.

### Tabla `ciudades`
```sql
CREATE TABLE ciudades (
    id SERIAL PRIMARY KEY,    -- ID único de la ciudad
    nombre VARCHAR(100) NOT NULL  -- Nombre de la ciudad
);
```

### Tabla `sucursales`
```sql
CREATE TABLE sucursales (
    id SERIAL PRIMARY KEY,    -- ID único de la sucursal
    direccion VARCHAR(100) NOT NULL,  -- Dirección de la sucursal
    ciudad_id INT NOT NULL,   -- Relación con la tabla ciudades
    FOREIGN KEY (ciudad_id) REFERENCES ciudades(id) ON DELETE CASCADE
);
```

### Tabla `categorias`
```sql
CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,    -- ID único de la categoría
    nombre VARCHAR(100) NOT NULL  -- Nombre de la categoría
);
```

### Tabla `productos`
```sql
CREATE TABLE productos (
    id SERIAL PRIMARY KEY,    -- ID único del producto
    nombre VARCHAR(100) NOT NULL,  -- Nombre del producto
    descripcion TEXT,         -- Descripción del producto (opcional)
    precio DECIMAL(10, 2) NOT NULL,  -- Precio del producto
    categoria_id INT NOT NULL,  -- Relación con la tabla categorias
    FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE CASCADE
);
```

### Tabla `inventario`
```sql
CREATE TABLE inventario (
    producto_id INT NOT NULL,  -- Relación con la tabla productos
    sucursal_id INT NOT NULL,  -- Relación con la tabla sucursales
    cantidad INT NOT NULL,     -- Cantidad disponible en inventario
    PRIMARY KEY (producto_id, sucursal_id),  -- Clave primaria compuesta
    FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE,
    FOREIGN KEY (sucursal_id) REFERENCES sucursales(id) ON DELETE CASCADE
);
```

---

## Configuración de Conexiones Remotas
Para permitir que las bases de datos remotas se conecten entre sí, se realizaron los siguientes cambios en `postgresql.conf`:

```ini
listen_addresses = '*'
wal_level = logical
max_wal_senders = 10
max_replication_slots = 10
shared_preload_libraries = 'pglogical'
track_commit_timestamp = on
```

Luego, se reiniciaron los servicios de PostgreSQL.

---

## Creación de Nodos, Publicaciones y Suscripciones

### Habilitar la Extensión pgLogical
Antes de crear los nodos, es necesario habilitar la extensión `pglogical` en ambas bases de datos (nodo central y sucursal).

```sql
CREATE EXTENSION pglogical;
```

### Creación del Nodo Proveedor (Nodo Central)
El nodo central actúa como proveedor de datos.

```sql
SELECT pglogical.create_node(
    node_name := 'nodo_central',  -- Nombre del nodo proveedor
    dsn := 'host=nodo_central port=5432 dbname=nodo_central_bd user=postgres password=postgres'
);
```

### Creación del Nodo Suscriptor (Sucursal)
La sucursal actúa como suscriptor de datos.

```sql
SELECT pglogical.create_node(
    node_name := 'sucursal_1',  -- Nombre del nodo suscriptor
    dsn := 'host=sucursal_1 port=5432 dbname=sucursal_1_bd user=postgres password=postgres'
);
```

### Creación de Publicaciones en el Nodo Central
Se crean publicaciones para el catálogo y el inventario.

#### Publicación del Catálogo
```sql
SELECT pglogical.create_replication_set(
    set_name := 'set_catalogo',  -- Nombre del conjunto de replicación
    replicate_insert := true,    -- Replicar inserciones
    replicate_update := true,    -- Replicar actualizaciones
    replicate_delete := true     -- Replicar eliminaciones
);

-- Agregar la tabla 'productos' al conjunto de replicación
SELECT pglogical.replication_set_add_table(
    set_name := 'set_catalogo',
    relation := 'productos',
    synchronize_data := true  -- Sincronizar los datos existentes
);

-- Agregar la tabla 'categorias' al conjunto de replicación
SELECT pglogical.replication_set_add_table(
    set_name := 'set_catalogo',
    relation := 'categorias',
    synchronize_data := true
);
```

#### Publicación del Inventario (Bidireccional)
```sql
SELECT pglogical.create_replication_set(
    set_name := 'set_inventario_sucursal_1',  -- Nombre del conjunto de replicación
    replicate_insert := true,
    replicate_update := true,
    replicate_delete := true
);

-- Agregar la tabla 'inventario' filtrando por sucursal 1
SELECT pglogical.replication_set_add_table(
    set_name := 'set_inventario_sucursal_1',
    relation := 'inventario',
    synchronize_data := true,
    row_filter := 'sucursal_id = 1'  -- Solo replicar datos de la sucursal 1
);
```

### Creación de Suscripciones en la Sucursal
La sucursal se suscribe a las publicaciones del nodo central.

#### Suscripción al Catálogo
```sql
SELECT pglogical.create_subscription(
    subscription_name := 'sub_catalogo',  -- Nombre de la suscripción
    provider_dsn := 'host=nodo_central port=5432 dbname=nodo_central_bd user=postgres password=postgres',
    replication_sets := ARRAY['set_catalogo'],  -- Conjunto de replicación
    synchronize_data := true  -- Sincronizar los datos existentes
);
```

#### Suscripción al Inventario (Bidireccional)
```sql
SELECT pglogical.create_subscription(
    subscription_name := 'sub_inventario_sucursal_1',  -- Nombre de la suscripción
    provider_dsn := 'host=nodo_central port=5432 dbname=nodo_central_bd user=postgres password=postgres',
    replication_sets := ARRAY['set_inventario_sucursal_1'],  -- Conjunto de replicación
    synchronize_data := true  -- Sincronizar los datos existentes
);
```

Para que la replicación sea bidireccional, debes repetir los pasos anteriores pero intercambiando los roles de proveedor y suscriptor.

---

## Resolución de Conflictos en Replicación Bidireccional
Para evitar bucles de sobrescritura infinita, se habilitó la opción:

```sql
ALTER SYSTEM SET pglogical.conflict_resolution = 'last_update_wins';
```

Esto garantiza que la última modificación realizada prevalezca sobre versiones anteriores.

---

## Implementación en la Nube con Google Cloud SQL
Para garantizar alta disponibilidad, se configuró la base de datos central en **Google Cloud SQL** con soporte para **pgLogical**. Se realizaron los siguientes pasos:

1. **Crear una instancia de PostgreSQL en Google Cloud SQL**.
2. **Configurar acceso remoto** añadiendo la IP pública de las sucursales a la lista de redes autorizadas.
3. **Habilitar replicación lógica** con las siguientes marcas en la configuración de la instancia:
   
```sh
cloudsql.logical_decoding = on
cloudsql.enable_pglogical = on
```

4. **Crear el nodo de replicación en la nube** y **suscribirse desde la sucursal local**.

---

## Verificación del Estado de la Replicación
Para verificar que la replicación está funcionando correctamente, puedes usar la siguiente consulta:

```sql
SELECT * FROM pglogical.show_subscription_status();
```

El estado debe ser `replicating` si la replicación está funcionando correctamente.

---

## Conclusión
La implementación de **pgLogical** permitió centralizar y distribuir la información de manera eficiente, asegurando la disponibilidad y seguridad de los datos. La replicación bidireccional garantiza que los cambios en las sucursales se reflejen en la base de datos central y viceversa, mejorando la gestión de inventarios y catálogos.

Además, la integración con **Google Cloud SQL** ofrece una solución escalable y segura para la replicación de datos, permitiendo mantener copias de respaldo en servidores de respaldo o en la nube.

[Ver documento completo](https://docs.google.com/document/d/19xn2j-PouzAnhZItXBqLj9djrVrzA--7/edit?usp=sharing&ouid=114794794190662415499&rtpof=true&sd=true)
