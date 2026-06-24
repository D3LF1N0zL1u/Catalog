-- ============================================================================
-- iceberg_catalog.load_table test cases
-- ============================================================================

BEGIN;

SELECT iceberg_catalog.create_namespace('test_ns', '{}'::jsonb);
SELECT iceberg_catalog.create_namespace('prod_ns', '{}'::jsonb);

SELECT iceberg_catalog.create_table(
    'test_ns', 'test_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::jsonb
);

SELECT iceberg_catalog.create_table(
    'prod_ns', 'big_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::jsonb,
    'file:///tmp/custom-location/prod_ns/big_tbl'::text
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
