-- ============================================================================
-- iceberg_catalog.is_table_existed test cases
-- ============================================================================
BEGIN;
BEGIN
INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES (current_database(), 'test_ns', '{}'::JSONB);
INSERT 0 1
CREATE TABLE is_table_existed_rel(id int);
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
    'is_table_existed_rel'::regclass,
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
);
INSERT 0 1
-- 1. Existing table returns {"exists": true}.
SELECT iceberg_catalog.is_table_existed('test_ns', 'test_tbl');
 is_table_existed 
------------------
 {"exists": true}
(1 row)
-- 2. Missing table returns {"exists": false}.
SELECT iceberg_catalog.is_table_existed('test_ns', 'missing_tbl');
 is_table_existed  
-------------------
 {"exists": false}
(1 row)
-- 3. Return value is a JSONB object.
SELECT jsonb_typeof(iceberg_catalog.is_table_existed('test_ns', 'test_tbl')) AS result_type;
 result_type 
-------------
 object
(1 row)
-- 4. Return value contains the exists key.
SELECT iceberg_catalog.is_table_existed('test_ns', 'test_tbl') ? 'exists' AS has_exists;
 has_exists 
------------
 t
(1 row)
-- 5. Empty p_namespace errors.
SAVEPOINT sp5;
SAVEPOINT
SELECT iceberg_catalog.is_table_existed('', 'tbl');
gsql:test/sql/is_table_existed.sql:53: ERROR:  p_namespace is required and must not be empty
CONTEXT:  referenced column: is_table_existed
ROLLBACK TO SAVEPOINT sp5;
ROLLBACK
-- 6. Empty p_table errors.
SAVEPOINT sp6;
SAVEPOINT
SELECT iceberg_catalog.is_table_existed('ns', '');
gsql:test/sql/is_table_existed.sql:58: ERROR:  p_table is required and must not be empty
CONTEXT:  referenced column: is_table_existed
ROLLBACK TO SAVEPOINT sp6;
ROLLBACK
-- 7. NULL p_namespace errors.
SAVEPOINT sp7;
SAVEPOINT
SELECT iceberg_catalog.is_table_existed(NULL, 'tbl');
gsql:test/sql/is_table_existed.sql:63: ERROR:  p_namespace is required and must not be empty
CONTEXT:  referenced column: is_table_existed
ROLLBACK TO SAVEPOINT sp7;
ROLLBACK
-- 8. NULL p_table errors.
SAVEPOINT sp8;
SAVEPOINT
SELECT iceberg_catalog.is_table_existed('ns', NULL);
gsql:test/sql/is_table_existed.sql:68: ERROR:  p_table is required and must not be empty
CONTEXT:  referenced column: is_table_existed
ROLLBACK TO SAVEPOINT sp8;
ROLLBACK
ROLLBACK;
ROLLBACK
