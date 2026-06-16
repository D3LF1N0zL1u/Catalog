-- ============================================================================
-- iceberg_catalog.load_table test cases
-- ============================================================================

BEGIN;

INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES
    (current_database(), 'test_ns', '{}'::JSONB),
    (current_database(), 'prod_ns', '{}'::JSONB);

CREATE TABLE load_table_test_rel(id int);
CREATE TABLE load_table_prod_rel(id int);

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
        '33333333-3333-3333-3333-333333333333',
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
        '44444444-4444-4444-4444-444444444444',
        's3://bucket/prod_ns/big_tbl/metadata/v10.metadata.json',
        's3://bucket/prod_ns/big_tbl/metadata/v9.metadata.json',
        's3://bucket/prod_ns/big_tbl',
        2,
        1,
        100,
        0
    );

-- 1. Return value is a JSONB object.
SELECT jsonb_typeof(iceberg_catalog.load_table('test_ns', 'test_tbl')) AS result_type;

-- 2. Return value contains the LoadTableResult top-level keys.
SELECT
    iceberg_catalog.load_table('test_ns', 'test_tbl') ? 'metadata-location' AS has_metadata_location,
    iceberg_catalog.load_table('test_ns', 'test_tbl') ? 'metadata'          AS has_metadata,
    iceberg_catalog.load_table('test_ns', 'test_tbl') ? 'config'            AS has_config;

-- 3. Return value uses the metadata_location stored in META.
SELECT iceberg_catalog.load_table('test_ns', 'test_tbl')->>'metadata-location' AS metadata_location;

-- 4. Return full LoadTableResult for a second table.
SELECT iceberg_catalog.load_table('prod_ns', 'big_tbl');

-- 5. Missing table errors.
SAVEPOINT sp5;
SELECT iceberg_catalog.load_table('test_ns', 'missing_tbl');
ROLLBACK TO SAVEPOINT sp5;

-- 6. Empty p_namespace errors.
SAVEPOINT sp6;
SELECT iceberg_catalog.load_table('', 'tbl');
ROLLBACK TO SAVEPOINT sp6;

-- 7. Empty p_table errors.
SAVEPOINT sp7;
SELECT iceberg_catalog.load_table('ns', '');
ROLLBACK TO SAVEPOINT sp7;

-- 8. NULL p_namespace errors.
SAVEPOINT sp8;
SELECT iceberg_catalog.load_table(NULL, 'tbl');
ROLLBACK TO SAVEPOINT sp8;

-- 9. NULL p_table errors.
SAVEPOINT sp9;
SELECT iceberg_catalog.load_table('ns', NULL);
ROLLBACK TO SAVEPOINT sp9;

ROLLBACK;
