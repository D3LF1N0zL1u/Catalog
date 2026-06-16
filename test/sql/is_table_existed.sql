-- ============================================================================
-- iceberg_catalog.is_table_existed test cases
-- ============================================================================

BEGIN;

INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES (current_database(), 'test_ns', '{}'::JSONB);

CREATE TABLE is_table_existed_rel(id int);

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
    '22222222-2222-2222-2222-222222222222',
    'file:///tmp/test_ns/test_tbl/metadata/v1.metadata.json',
    NULL,
    'file:///tmp/test_ns/test_tbl',
    1,
    0,
    NULL,
    0
);

-- 1. Existing table returns {"exists": true}.
SELECT iceberg_catalog.is_table_existed('test_ns', 'test_tbl');

-- 2. Missing table returns {"exists": false}.
SELECT iceberg_catalog.is_table_existed('test_ns', 'missing_tbl');

-- 3. Return value is a JSONB object.
SELECT jsonb_typeof(iceberg_catalog.is_table_existed('test_ns', 'test_tbl')) AS result_type;

-- 4. Return value contains the exists key.
SELECT iceberg_catalog.is_table_existed('test_ns', 'test_tbl') ? 'exists' AS has_exists;

-- 5. Empty p_namespace errors.
SAVEPOINT sp5;
SELECT iceberg_catalog.is_table_existed('', 'tbl');
ROLLBACK TO SAVEPOINT sp5;

-- 6. Empty p_table errors.
SAVEPOINT sp6;
SELECT iceberg_catalog.is_table_existed('ns', '');
ROLLBACK TO SAVEPOINT sp6;

-- 7. NULL p_namespace errors.
SAVEPOINT sp7;
SELECT iceberg_catalog.is_table_existed(NULL, 'tbl');
ROLLBACK TO SAVEPOINT sp7;

-- 8. NULL p_table errors.
SAVEPOINT sp8;
SELECT iceberg_catalog.is_table_existed('ns', NULL);
ROLLBACK TO SAVEPOINT sp8;

ROLLBACK;
