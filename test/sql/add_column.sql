-- ============================================================================
-- iceberg_catalog.add_column 测试用例
--
-- 前置条件：iceberg_catalog 扩展已安装
-- ============================================================================

BEGIN;

SELECT iceberg_catalog.create_namespace('test_ns', '{}'::jsonb);
SELECT iceberg_catalog.create_table(
    'test_ns', 'test_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::jsonb
);

-- 1. 基础调用：传入 4 个必填参数，返回合法 JSONB
SELECT jsonb_typeof(iceberg_catalog.add_column(
    'test_ns',
    'test_tbl',
    'new_col',
    'string'
)) AS result_type;

-- 2. 返回结构包含两个顶层 key
SELECT
    iceberg_catalog.add_column('test_ns', 'test_tbl', 'col_a', 'int') ? 'metadata-location' AS has_metadata_location,
    iceberg_catalog.add_column('test_ns', 'test_tbl', 'col_b', 'long') ? 'metadata'          AS has_metadata;

-- 3. 传入 p_column_doc 参数，返回合法 JSONB
SELECT jsonb_typeof(iceberg_catalog.add_column(
    'test_ns',
    'test_tbl',
    'col_with_doc',
    'decimal(10,2)',
    p_column_doc => 'A documented column'
)) AS result_type;

-- 3.1 验证外表已增加新列
SELECT count(*) = 1 AS col_new_col_exists
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'test_ns' AND c.relname = 'test_tbl'
  AND a.attname = 'new_col' AND a.attnum > 0 AND NOT a.attisdropped;
SELECT count(*) = 1 AS col_col_a_exists
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'test_ns' AND c.relname = 'test_tbl'
  AND a.attname = 'col_a' AND a.attnum > 0 AND NOT a.attisdropped;
SELECT count(*) = 1 AS col_col_with_doc_exists
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'test_ns' AND c.relname = 'test_tbl'
  AND a.attname = 'col_with_doc' AND a.attnum > 0 AND NOT a.attisdropped;

-- 4. p_namespace 为空串 → 报错
SAVEPOINT sp4;
SELECT iceberg_catalog.add_column('', 'tbl', 'col', 'string');
ROLLBACK TO SAVEPOINT sp4;

-- 5. p_table 为空串 → 报错
SAVEPOINT sp5;
SELECT iceberg_catalog.add_column('ns', '', 'col', 'string');
ROLLBACK TO SAVEPOINT sp5;

-- 6. p_column_name 为空串 → 报错
SAVEPOINT sp6;
SELECT iceberg_catalog.add_column('ns', 'tbl', '', 'string');
ROLLBACK TO SAVEPOINT sp6;

-- 7. p_column_type 为空串 → 报错
SAVEPOINT sp7;
SELECT iceberg_catalog.add_column('ns', 'tbl', 'col', '');
ROLLBACK TO SAVEPOINT sp7;

ROLLBACK;
