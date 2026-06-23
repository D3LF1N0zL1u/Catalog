BEGIN;

INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES
    (current_database(), 'unp_updatable', '{"owner": "bob", "region": "us"}'::jsonb),
    (current_database(), 'unp_removable', '{"owner": "dave", "temp": "x", "region": "eu"}'::jsonb),
    (current_database(), 'unp_combined', '{"a": "1", "b": "2", "c": "3"}'::jsonb),
    (current_database(), 'unp_empty', '{}'::jsonb);

-- Return shape and updated key reporting.
SELECT jsonb_typeof(iceberg_catalog.update_namespace_properties(
    'unp_updatable',
    p_updates => '{"owner": "carol", "env": "prod"}'::jsonb
)) AS result_type;

SELECT iceberg_catalog.update_namespace_properties(
    'unp_updatable',
    p_updates => '{"tier": "gold"}'::jsonb
) -> 'updated' @> '["tier"]'::jsonb AS has_updated_tier;

SELECT properties @> '{"env": "prod", "owner": "carol", "tier": "gold"}'::jsonb AS updatable_properties_updated
FROM iceberg_catalog.namespaces
WHERE catalog_name = current_database() AND namespace = 'unp_updatable';

-- Removed and missing keys are reported separately.
WITH resp AS (
    SELECT iceberg_catalog.update_namespace_properties(
    'unp_removable',
    p_removals => '["temp", "missing_key"]'::jsonb
) AS body
)
SELECT
    body -> 'removed' @> '["temp"]'::jsonb AS removed_temp,
    body -> 'missing' @> '["missing_key"]'::jsonb AS missing_key
FROM resp;

SELECT NOT (properties ? 'temp') AS temp_removed
FROM iceberg_catalog.namespaces
WHERE catalog_name = current_database() AND namespace = 'unp_removable';

-- Updates and removals can be applied together.
SELECT
    iceberg_catalog.update_namespace_properties(
    'unp_combined',
    p_removals => '["a"]'::jsonb,
    p_updates  => '{"b": "updated", "d": "new"}'::jsonb
) -> 'updated' @> '["b", "d"]'::jsonb AS combined_updated;

SELECT properties = '{"b": "updated", "c": "3", "d": "new"}'::jsonb AS combined_properties
FROM iceberg_catalog.namespaces
WHERE catalog_name = current_database() AND namespace = 'unp_combined';

-- Empty removals/updates are legal no-ops when at least one argument is provided.
SELECT jsonb_array_length(iceberg_catalog.update_namespace_properties(
    'unp_empty',
    p_removals => '[]'::jsonb
) -> 'removed') = 0 AS empty_removals_noop;

SELECT jsonb_array_length(iceberg_catalog.update_namespace_properties(
    'unp_empty',
    p_updates => '{}'::jsonb
) -> 'updated') = 0 AS empty_updates_noop;

-- Argument validation and conflict handling.
SAVEPOINT sp_empty_ns;
SELECT iceberg_catalog.update_namespace_properties('', p_updates => '{"key": "val"}'::jsonb);
ROLLBACK TO SAVEPOINT sp_empty_ns;

SAVEPOINT sp_null_ops;
SELECT iceberg_catalog.update_namespace_properties('unp_empty');
ROLLBACK TO SAVEPOINT sp_null_ops;

SAVEPOINT sp_bad_removals;
SELECT iceberg_catalog.update_namespace_properties(
    'unp_empty',
    p_removals => '"not_an_array"'::jsonb
);
ROLLBACK TO SAVEPOINT sp_bad_removals;

SAVEPOINT sp_bad_updates;
SELECT iceberg_catalog.update_namespace_properties(
    'unp_empty',
    p_updates => '"not_an_object"'::jsonb
);
ROLLBACK TO SAVEPOINT sp_bad_updates;

SAVEPOINT sp_overlap;
SELECT iceberg_catalog.update_namespace_properties(
    'unp_empty',
    p_removals => '["same_key"]'::jsonb,
    p_updates  => '{"same_key": "val"}'::jsonb
);
ROLLBACK TO SAVEPOINT sp_overlap;

SAVEPOINT sp_missing_ns;
SELECT iceberg_catalog.update_namespace_properties(
    'unp_missing',
    p_updates => '{"key": "val"}'::jsonb
);
ROLLBACK TO SAVEPOINT sp_missing_ns;

ROLLBACK;
