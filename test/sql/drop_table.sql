-- ============================================================================
-- iceberg_catalog.drop_table 测试用例
-- ============================================================================

BEGIN;

SELECT iceberg_catalog.create_namespace('drop_ns', '{}'::jsonb);
SELECT iceberg_catalog.create_namespace('drop_false_ns', '{}'::jsonb);

CREATE TEMP TABLE drop_table_test_ids(
    label TEXT PRIMARY KEY,
    table_uuid UUID NOT NULL
);

SELECT iceberg_catalog.create_table(
    'drop_ns',
    'drop_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true},{"id":2,"name":"data","type":"string","required":false}]}'::JSONB,
    'file:///tmp/drop/src'
);

INSERT INTO drop_table_test_ids(label, table_uuid)
SELECT 'basic', table_uuid
FROM iceberg_catalog.tables_internal
WHERE namespace = 'drop_ns'
  AND table_name = 'drop_tbl';

SELECT iceberg_catalog.create_table(
    'drop_false_ns',
    'drop_false_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::JSONB
);

INSERT INTO drop_table_test_ids(label, table_uuid)
SELECT 'explicit_false', table_uuid
FROM iceberg_catalog.tables_internal
WHERE namespace = 'drop_false_ns'
  AND table_name = 'drop_false_tbl';

-- 1. 基础调用：返回 {"success": true}
SELECT iceberg_catalog.drop_table('drop_ns', 'drop_tbl') AS drop_result;

-- 2. 验证 drop 后元信息表数据已清理
SELECT count(*) = 0 AS table_head_deleted
FROM iceberg_catalog.tables_internal
WHERE table_uuid = (
    SELECT table_uuid FROM drop_table_test_ids WHERE label = 'basic'
);

SELECT count(*) = 0 AS schema_rows_deleted
FROM iceberg_catalog.table_schemas
WHERE table_uuid = (
    SELECT table_uuid FROM drop_table_test_ids WHERE label = 'basic'
);

SELECT count(*) = 0 AS partition_rows_deleted
FROM iceberg_catalog.partition_specs
WHERE table_uuid = (
    SELECT table_uuid FROM drop_table_test_ids WHERE label = 'basic'
);

-- 3. p_purge = FALSE（显式传入）
SELECT iceberg_catalog.drop_table('drop_false_ns', 'drop_false_tbl', FALSE) AS drop_false_result;

SELECT count(*) = 0 AS explicit_false_table_deleted
FROM iceberg_catalog.tables_internal
WHERE table_uuid = (
    SELECT table_uuid FROM drop_table_test_ids WHERE label = 'explicit_false'
);

-- 4. p_purge = TRUE → 报错（暂不支持）
SAVEPOINT sp4;
SELECT iceberg_catalog.drop_table('ns', 'tbl', TRUE);
ROLLBACK TO SAVEPOINT sp4;

-- 5. p_namespace 为空串 → 报错
SAVEPOINT sp5;
SELECT iceberg_catalog.drop_table('', 'tbl');
ROLLBACK TO SAVEPOINT sp5;

-- 6. p_table 为空串 → 报错
SAVEPOINT sp6;
SELECT iceberg_catalog.drop_table('ns', '');
ROLLBACK TO SAVEPOINT sp6;

-- 7. p_namespace 为 NULL → 报错
SAVEPOINT sp7;
SELECT iceberg_catalog.drop_table(NULL, 'tbl');
ROLLBACK TO SAVEPOINT sp7;

-- 8. p_table 为 NULL → 报错
SAVEPOINT sp8;
SELECT iceberg_catalog.drop_table('ns', NULL);
ROLLBACK TO SAVEPOINT sp8;

-- 9. 表不存在 → 报错
SAVEPOINT sp9;
SELECT iceberg_catalog.drop_table('drop_ns', 'drop_tbl');
ROLLBACK TO SAVEPOINT sp9;

-- 10. 创建后立即删除（覆盖 hook 插入点的正常路径）
SELECT iceberg_catalog.create_table(
    'drop_ns',
    'drop_immediate_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::JSONB
);

SELECT iceberg_catalog.drop_table('drop_ns', 'drop_immediate_tbl') AS drop_immediate_result;

ROLLBACK;
