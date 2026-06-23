BEGIN;

-- Basic response shape.
SELECT jsonb_typeof(iceberg_catalog.list_namespaces()) AS result_type;
SELECT
    iceberg_catalog.list_namespaces() ? 'namespaces'      AS has_namespaces,
    iceberg_catalog.list_namespaces() ? 'next-page-token' AS has_next_page_token;
SELECT jsonb_typeof(iceberg_catalog.list_namespaces() -> 'namespaces') AS namespaces_type;

-- Top-level namespaces are read from iceberg_catalog.namespaces.
INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES
    (current_database(), 'ln_accounting', '{}'::jsonb),
    (current_database(), 'ln_dept_a', '{}'::jsonb),
    (current_database(), 'ln_dept_b', '{"owner": "alice"}'::jsonb);

SELECT iceberg_catalog.list_namespaces() -> 'namespaces' @> '[["ln_accounting"]]'::jsonb AS has_accounting;
SELECT iceberg_catalog.list_namespaces() -> 'namespaces' @> '[["ln_dept_a"]]'::jsonb AS has_dept_a;
SELECT iceberg_catalog.list_namespaces() -> 'namespaces' @> '[["ln_dept_b"]]'::jsonb AS has_dept_b;

-- Parent namespaces list one-level children only.
INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES
    (current_database(), 'ln_parent', '{}'::jsonb),
    (current_database(), 'ln_parent.child_a', '{}'::jsonb),
    (current_database(), 'ln_parent.child_b', '{}'::jsonb),
    (current_database(), 'ln_parent.child_b.grandchild', '{}'::jsonb);

SELECT iceberg_catalog.list_namespaces('ln_parent') -> 'namespaces' @> '[["ln_parent", "child_a"]]'::jsonb AS has_child_a;
SELECT iceberg_catalog.list_namespaces('ln_parent') -> 'namespaces' @> '[["ln_parent", "child_b"]]'::jsonb AS has_child_b;
SELECT iceberg_catalog.list_namespaces('ln_parent') -> 'namespaces' @> '[["ln_parent", "grandchild"]]'::jsonb AS has_grandchild;

-- Last-key pagination produces and accepts an opaque next-page-token.
WITH first_page AS (
    SELECT iceberg_catalog.list_namespaces(NULL, 1, NULL) AS page
)
SELECT
    jsonb_array_length(page -> 'namespaces') AS first_page_count,
    jsonb_typeof(page -> 'next-page-token') AS token_type
FROM first_page;

WITH first_page AS (
    SELECT iceberg_catalog.list_namespaces(NULL, 1, NULL) AS page
)
SELECT jsonb_array_length(
    iceberg_catalog.list_namespaces(NULL, 100, page ->> 'next-page-token') -> 'namespaces'
) > 0 AS second_page_has_rows
FROM first_page;

-- Argument validation.
SAVEPOINT sp_page_zero;
SELECT iceberg_catalog.list_namespaces(p_page_size => 0);
ROLLBACK TO SAVEPOINT sp_page_zero;

SAVEPOINT sp_bad_parent;
SELECT iceberg_catalog.list_namespaces(p_parent => 'ln_missing_parent');
ROLLBACK TO SAVEPOINT sp_bad_parent;

SAVEPOINT sp_bad_token;
SELECT iceberg_catalog.list_namespaces(p_page_token => 'not-base64');
ROLLBACK TO SAVEPOINT sp_bad_token;

ROLLBACK;
