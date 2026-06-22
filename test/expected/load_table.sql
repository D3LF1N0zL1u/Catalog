-- ============================================================================
-- iceberg_catalog.load_table test cases
-- ============================================================================
BEGIN;
BEGIN
INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES
    (current_database(), 'test_ns', '{}'::JSONB),
    (current_database(), 'prod_ns', '{}'::JSONB);
INSERT 0 2
CREATE TABLE load_table_test_rel(id int);
CREATE TABLE
CREATE TABLE load_table_prod_rel(id int);
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
VALUES
    (
        'load_table_test_rel'::regclass,
        'test_ns',
        'test_tbl',
        '<uuid>',
        'file:///tmp/test_ns/test_tbl/metadata/v1.metadata.json',
        NULL,
        'file:///tmp/test_ns/test_tbl',
        1,
        0,
        NULL,
        0
    ),
    (
        'load_table_prod_rel'::regclass,
        'prod_ns',
        'big_tbl',
        '<uuid>',
        's3://bucket/prod_ns/big_tbl/metadata/v10.metadata.json',
        's3://bucket/prod_ns/big_tbl/metadata/v9.metadata.json',
        's3://bucket/prod_ns/big_tbl',
        2,
        1,
        100,
        0
    );
INSERT 0 2
-- 1. Return value is a JSONB object.
SELECT jsonb_typeof(iceberg_catalog.load_table('test_ns', 'test_tbl')) AS result_type;
 result_type 
-------------
 object
(1 row)
-- 2. Return value contains the LoadTableResult top-level keys.
SELECT
    iceberg_catalog.load_table('test_ns', 'test_tbl') ? 'metadata-location' AS has_metadata_location,
    iceberg_catalog.load_table('test_ns', 'test_tbl') ? 'metadata'          AS has_metadata,
    iceberg_catalog.load_table('test_ns', 'test_tbl') ? 'config'            AS has_config;
 has_metadata_location | has_metadata | has_config 
-----------------------+--------------+------------
 t                     | t            | t
(1 row)
-- 3. Return value uses the metadata_location stored in META.
SELECT iceberg_catalog.load_table('test_ns', 'test_tbl')->>'metadata-location' AS metadata_location;
                   metadata_location                    
--------------------------------------------------------
 file:///tmp/test_ns/test_tbl/metadata/v1.metadata.json
(1 row)
-- 4. Return full LoadTableResult for a second table.
SELECT iceberg_catalog.load_table('prod_ns', 'big_tbl');
                                                  load_table                                                   
---------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {}, "metadata-location": "s3://bucket/prod_ns/big_tbl/metadata/v10.metadata.json"}
(1 row)
-- 5. Missing table errors.
SAVEPOINT sp5;
SAVEPOINT
SELECT iceberg_catalog.load_table('test_ns', 'missing_tbl');
gsql:test/sql/load_table.sql:73: ERROR:  The given table does not exist
CONTEXT:  referenced column: load_table
ROLLBACK TO SAVEPOINT sp5;
ROLLBACK
-- 6. Empty p_namespace errors.
SAVEPOINT sp6;
SAVEPOINT
SELECT iceberg_catalog.load_table('', 'tbl');
gsql:test/sql/load_table.sql:78: ERROR:  p_namespace is required and must not be empty
CONTEXT:  referenced column: load_table
ROLLBACK TO SAVEPOINT sp6;
ROLLBACK
-- 7. Empty p_table errors.
SAVEPOINT sp7;
SAVEPOINT
SELECT iceberg_catalog.load_table('ns', '');
gsql:test/sql/load_table.sql:83: ERROR:  p_table is required and must not be empty
CONTEXT:  referenced column: load_table
ROLLBACK TO SAVEPOINT sp7;
ROLLBACK
-- 8. NULL p_namespace errors.
SAVEPOINT sp8;
SAVEPOINT
SELECT iceberg_catalog.load_table(NULL, 'tbl');
gsql:test/sql/load_table.sql:88: ERROR:  p_namespace is required and must not be empty
CONTEXT:  referenced column: load_table
ROLLBACK TO SAVEPOINT sp8;
ROLLBACK
-- 9. NULL p_table errors.
SAVEPOINT sp9;
SAVEPOINT
SELECT iceberg_catalog.load_table('ns', NULL);
gsql:test/sql/load_table.sql:93: ERROR:  p_table is required and must not be empty
CONTEXT:  referenced column: load_table
ROLLBACK TO SAVEPOINT sp9;
ROLLBACK
ROLLBACK;
ROLLBACK
