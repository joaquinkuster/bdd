-- Habilitar la extensión para usar pglogical
CREATE EXTENSION pglogical;


-- 1.- Configurar una replicación unidireccional para distribuir el catálogo (productos y categorías) a todas las sucursales.

-- En la base de datos central:

-- Crear el nodo proveedor en la base de datos central
SELECT pglogical.create_node(
    node_name := 'nodo_central',  -- Nombre del nodo proveedor
    dsn := 'host=nodo_central port=5432 dbname=nodo_central_bd user=postgres password=postgres'
);


-- Crear un conjunto de replicación para el catálogo
SELECT pglogical.create_replication_set(
    set_name := 'set_catalogo',   -- Nombre del conjunto de replicación
    replicate_insert := true,     -- Replicar inserciones
    replicate_update := true,     -- Replicar actualizaciones
    replicate_delete := true      -- Replicar eliminaciones
);


-- Agregar la tabla 'productos' al conjunto de replicación
SELECT pglogical.replication_set_add_table(
    set_name := 'set_catalogo',
    relation := 'productos',
    synchronize_data := true  -- Sincronizar los datos existentes
);


-- Agregar la tabla 'categorías' al conjunto de replicación
SELECT pglogical.replication_set_add_table(
    set_name := 'set_catalogo',
    relation := 'categorias',
    synchronize_data := true
);


-- Luego, en la base de datos de la sucursal:

-- Crear el nodo suscriptor en la sucursal
SELECT pglogical.create_node(
    node_name := 'sucursal_1',
    dsn := 'host=sucursal_1 port=5432 dbname=sucursal_1_bd user=postgres password=postgres'
);


-- Crear la suscripción para recibir datos del catálogo
SELECT pglogical.create_subscription(
    subscription_name := 'sub_catalogo',
    provider_dsn := 'host=nodo_central port=5432 dbname=nodo_central_bd user=postgres password=postgres',
    replication_sets := ARRAY['set_catalogo'],
    synchronize_data := true -- Sincronizar los datos existentes al suscriptor
);


-- 2.- Configurar replicación bidireccional para sincronizar el inventario entre el nodo central y cada sucursal, asegurando que los cambios se reflejen en ambos y fragmentando por sucursal para que solo gestione su propio inventario.

-- En la base de datos central:

-- Crear conjunto de replicación para el inventario de la sucursal 1
SELECT pglogical.create_replication_set(
    set_name := 'set_inventario_sucursal_1',
    replicate_insert := true,
    replicate_update := true,
    replicate_delete := true
);


-- Agregar la tabla 'inventario' filtrando por sucursal 1
SELECT pglogical.replication_set_add_table(
    set_name := 'set_inventario_sucursal_1',
    relation := 'inventario',
    synchronize_data := true,
    row_filter := 'sucursal_id = 1' -- Solo replicar datos de la sucursal 1
);


-- Agregar la tabla 'sucursales' filtrando por sucursal 1
SELECT pglogical.replication_set_add_table(
    set_name := 'set_inventario_sucursal_1',
    relation := 'sucursales',
    synchronize_data := true,
    row_filter := 'id = 1' -- Solo replicar datos de la sucursal 1
);


-- En la base de datos de la sucursal:

-- Crear la suscripción para recibir los datos de inventario
SELECT pglogical.create_subscription(
    subscription_name := 'sub_inventario_sucursal_1',
    provider_dsn := 'host=nodo_central port=5432 dbname=nodo_central_bd user=postgres password=postgres',
    replication_sets := ARRAY['set_inventario_sucursal_1'],
    synchronize_data := true
);


-- 3.- Para que la replicación sea bidireccional, debes repetir los pasos anteriores pero intercambiando los roles de proveedor y suscriptor.

-- En la base de datos de la sucursal:

-- Crear conjunto de replicación para su inventario local
SELECT pglogical.create_replication_set(
    set_name := 'set_inventario_sucursal_1',
    replicate_insert := true,
    replicate_update := true,
    replicate_delete := true
);


-- Agregar la tabla 'inventario' a la replicación
SELECT pglogical.replication_set_add_table(
    set_name := 'set_inventario_sucursal_1',
    relation := 'inventario',
    synchronize_data := true
);


-- En la base de datos central:

-- Crear suscripción para recibir inventario de la sucursal 1
SELECT pglogical.create_subscription(
    subscription_name := 'sub_inventario_sucursal_1',
    provider_dsn := 'host=sucursal_1 port=5432 dbname=sucursal_1_bd user=postgres password=postgres',
    replication_sets := ARRAY['set_inventario_sucursal_1'],
    synchronize_data := true
);


-- 4.- En los nodos suscriptores, verifica que los datos se están replicando correctamente.

SELECT * FROM pglogical.show_subscription_status();

--El estado debe ser replicating si la replicación está funcionando correctamente