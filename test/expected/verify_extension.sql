BEGIN;
BEGIN
-- Verify external catalog records and namespace property expansion.
INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES ('external_demo', 'demo_ns', '{"env":"test","owner":"catalog"}'::jsonb);
INSERT 0 1
INSERT INTO iceberg_catalog.tables_external(
    catalog_name,
    namespace,
    table_name,
    metadata_location,
    previous_metadata_location
)
VALUES (
    'external_demo',
    'demo_ns',
    'demo_tbl',
    'file:///tmp/v2.metadata.json',
    'file:///tmp/v1.metadata.json'
);
INSERT 0 1
UPDATE iceberg_catalog.tables_external
SET metadata_location = 'file:///tmp/v3.metadata.json',
    previous_metadata_location = 'file:///tmp/v2.metadata.json'
WHERE catalog_name = 'external_demo'
  AND namespace = 'demo_ns'
  AND table_name = 'demo_tbl';
UPDATE 1
SELECT
    catalog_name,
    table_namespace,
    table_name,
    metadata_location,
    previous_metadata_location
FROM iceberg_catalog.iceberg_tables
WHERE table_namespace = 'demo_ns';
 catalog_name  | table_namespace | table_name |      metadata_location       |  previous_metadata_location  
---------------+-----------------+------------+------------------------------+------------------------------
 external_demo | demo_ns         | demo_tbl   | file:///tmp/v3.metadata.json | file:///tmp/v2.metadata.json
(1 row)
SELECT
    namespace,
    property_key,
    property_value
FROM iceberg_catalog.iceberg_namespace_properties
WHERE catalog_name = 'external_demo'
  AND namespace = 'demo_ns'
ORDER BY property_key;
 namespace | property_key | property_value 
-----------+--------------+----------------
 demo_ns   | env          | test
 demo_ns   | owner        | catalog
(2 rows)
-- Verify internal catalog records and dependent metadata tables.
CREATE TABLE gv_catalog_verify_rel(id int);
CREATE TABLE
INSERT INTO iceberg_catalog.tables_internal(
    relid,
    namespace,
    table_name,
    table_uuid,
    metadata_location,
    previous_metadata_location,
    table_location,
    last_column_id,
    current_schema_id,
    current_snapshot_id,
    default_spec_id
)
VALUES (
    'gv_catalog_verify_rel'::regclass,
    'internal_ns',
    'internal_tbl',
    '<uuid>',
    'file:///tmp/internal/v2.metadata.json',
    'file:///tmp/internal/v1.metadata.json',
    'file:///tmp/internal',
    2,
    0,
    10,
    0
);
INSERT 0 1
INSERT INTO iceberg_catalog.table_schemas(
    table_uuid,
    schema_id,
    field_position,
    field_id,
    field_name,
    field_required,
    field_type,
    field_doc
)
VALUES
    -- The unpartitioned spec is stored as a sentinel row.
    (
        '<uuid>',
        0,
        0,
        1,
        'id',
        true,
        'int',
        'primary id'
    ),
    (
        '<uuid>',
        0,
        1,
        2,
        'data',
        false,
        'string',
        NULL
    );
INSERT 0 2
INSERT INTO iceberg_catalog.snapshots(
    table_uuid,
    snapshot_id,
    schema_id,
    timestamp_ms,
    manifest_list,
    total_records
)
VALUES (
    '<uuid>',
    10,
    0,
    1710000000000,
    'file:///tmp/internal/snap-10.avro',
    42
);
INSERT 0 1
INSERT INTO iceberg_catalog.partition_specs(
    table_uuid,
    spec_id,
    field_position,
    field_id,
    source_id,
    field_name,
    transform
)
VALUES
    (
        '<uuid>',
        0,
        -1,
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        '<uuid>',
        1,
        0,
        1000,
        2,
        'data_bucket',
        'bucket[16]'
    );
INSERT 0 2
SELECT
    catalog_name,
    table_namespace,
    table_name,
    metadata_location,
    previous_metadata_location
FROM iceberg_catalog.iceberg_tables
WHERE table_namespace = 'internal_ns';
 catalog_name | table_namespace |  table_name  |           metadata_location           |      previous_metadata_location       
--------------+-----------------+--------------+---------------------------------------+---------------------------------------
 <test_db> | internal_ns     | internal_tbl | file:///tmp/internal/v2.metadata.json | file:///tmp/internal/v1.metadata.json
(1 row)
SELECT count(*) AS schema_field_count
FROM iceberg_catalog.table_schemas
WHERE table_uuid = '<uuid>';
 schema_field_count 
--------------------
                  2
(1 row)
SELECT count(*) AS snapshot_count
FROM iceberg_catalog.snapshots
WHERE table_uuid = '<uuid>';
 snapshot_count 
----------------
              1
(1 row)
SELECT count(*) AS partition_spec_count
FROM iceberg_catalog.partition_specs
WHERE table_uuid = '<uuid>';
 partition_spec_count 
----------------------
                    2
(1 row)
-- Verify dependent metadata rows are removed with the internal table head.
DELETE FROM iceberg_catalog.tables_internal
WHERE table_uuid = '<uuid>';
DELETE 1
SELECT
    (SELECT count(*)
     FROM iceberg_catalog.table_schemas
     WHERE table_uuid = '<uuid>') AS schema_field_count,
    (SELECT count(*)
     FROM iceberg_catalog.snapshots
     WHERE table_uuid = '<uuid>') AS snapshot_count,
    (SELECT count(*)
     FROM iceberg_catalog.partition_specs
     WHERE table_uuid = '<uuid>') AS partition_spec_count;
 schema_field_count | snapshot_count | partition_spec_count 
--------------------+----------------+----------------------
                  0 |              0 |                    0
(1 row)
DELETE FROM iceberg_catalog.tables_external
WHERE catalog_name = 'external_demo'
  AND namespace = 'demo_ns'
  AND table_name = 'demo_tbl';
DELETE 1
SELECT count(*)
FROM iceberg_catalog.tables_external
WHERE catalog_name = 'external_demo'
  AND namespace = 'demo_ns'
  AND table_name = 'demo_tbl';
 count 
-------
     0
(1 row)
ROLLBACK;
ROLLBACK
