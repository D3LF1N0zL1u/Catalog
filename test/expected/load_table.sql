-- ============================================================================
-- iceberg_catalog.load_table test cases
-- ============================================================================
BEGIN;
BEGIN
SELECT iceberg_catalog.create_namespace('test_ns', '{}'::jsonb);
               create_namespace               
----------------------------------------------
 {"namespace": ["test_ns"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_namespace('prod_ns', '{}'::jsonb);
               create_namespace               
----------------------------------------------
 {"namespace": ["prod_ns"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_table(
    'test_ns', 'test_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::jsonb
);
                                                                                                                                                                                                                                                                                                                                                                create_table                                                                                                                                                                                                                                                                                                                                                                 
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}], "schema-id": 0}], "location": "file:///tmp/iceberg_warehouse/test_ns/test_tbl", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 1, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/iceberg_warehouse/test_ns/test_tbl/metadata/00000-<uuid>.metadata.json"}
(1 row)
SELECT iceberg_catalog.create_table(
    'prod_ns', 'big_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::jsonb,
    'file:///tmp/custom-location/prod_ns/big_tbl'::text
);
                                                                                                                                                                                                                                                                                                                                                             create_table                                                                                                                                                                                                                                                                                                                                                              
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}], "schema-id": 0}], "location": "file:///tmp/custom-location/prod_ns/big_tbl", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 1, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/custom-location/prod_ns/big_tbl/metadata/00000-<uuid>.metadata.json"}
(1 row)
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
------------------------------------------------------------------------------------------------------------------
 file:///tmp/iceberg_warehouse/test_ns/test_tbl/metadata/00000-<uuid>.metadata.json
(1 row)
-- 4. Return full LoadTableResult for a second table.
SELECT iceberg_catalog.load_table('prod_ns', 'big_tbl');
                                                                                                                                                                                                                                                                                                                                                              load_table                                                                                                                                                                                                                                                                                                                                                               
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}], "schema-id": 0}], "location": "file:///tmp/custom-location/prod_ns/big_tbl", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 1, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/custom-location/prod_ns/big_tbl/metadata/00000-<uuid>.metadata.json"}
(1 row)
-- 5. Missing table errors.
SAVEPOINT sp5;
SAVEPOINT
SELECT iceberg_catalog.load_table('test_ns', 'missing_tbl');
gsql:test/sql/load_table.sql:38: ERROR:  The given table does not exist
CONTEXT:  referenced column: load_table
ROLLBACK TO SAVEPOINT sp5;
ROLLBACK
-- 6. Empty p_namespace errors.
SAVEPOINT sp6;
SAVEPOINT
SELECT iceberg_catalog.load_table('', 'tbl');
gsql:test/sql/load_table.sql:43: ERROR:  p_namespace is required and must not be empty
CONTEXT:  referenced column: load_table
ROLLBACK TO SAVEPOINT sp6;
ROLLBACK
-- 7. Empty p_table errors.
SAVEPOINT sp7;
SAVEPOINT
SELECT iceberg_catalog.load_table('ns', '');
gsql:test/sql/load_table.sql:48: ERROR:  p_table is required and must not be empty
CONTEXT:  referenced column: load_table
ROLLBACK TO SAVEPOINT sp7;
ROLLBACK
-- 8. NULL p_namespace errors.
SAVEPOINT sp8;
SAVEPOINT
SELECT iceberg_catalog.load_table(NULL, 'tbl');
gsql:test/sql/load_table.sql:53: ERROR:  p_namespace is required and must not be empty
CONTEXT:  referenced column: load_table
ROLLBACK TO SAVEPOINT sp8;
ROLLBACK
-- 9. NULL p_table errors.
SAVEPOINT sp9;
SAVEPOINT
SELECT iceberg_catalog.load_table('ns', NULL);
gsql:test/sql/load_table.sql:58: ERROR:  p_table is required and must not be empty
CONTEXT:  referenced column: load_table
ROLLBACK TO SAVEPOINT sp9;
ROLLBACK
ROLLBACK;
ROLLBACK
