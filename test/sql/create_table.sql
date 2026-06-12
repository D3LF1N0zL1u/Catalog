-- ============================================================================
-- iceberg_catalog.create_table 测试用例
--
-- 前置条件：iceberg_catalog 扩展已安装
-- ============================================================================

BEGIN;

-- 1. 基础调用：仅填 3 个必填参数，返回合法 JSONB
SELECT jsonb_typeof(iceberg_catalog.create_table(
    'test_ns',
    'test_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true},{"id":2,"name":"data","type":"string","required":false}]}'::JSONB
)) AS result_type;

-- 2. 返回结构包含三个顶层 key
SELECT
    iceberg_catalog.create_table('test_ns', 'test_tbl', '{"type":"struct","fields":[]}'::JSONB) ? 'metadata-location' AS has_metadata_location,
    iceberg_catalog.create_table('test_ns', 'test_tbl', '{"type":"struct","fields":[]}'::JSONB) ? 'metadata'          AS has_metadata,
    iceberg_catalog.create_table('test_ns', 'test_tbl', '{"type":"struct","fields":[]}'::JSONB) ? 'config'            AS has_config;

-- 3. 传入全部 8 个参数
SELECT iceberg_catalog.create_table(
    'ns_full',
    'tbl_full',
    '{"type":"struct","fields":[{"id":1,"name":"col1","type":"string","required":false}]}'::JSONB,
    's3://bucket/path/to/table'::TEXT,
    '{"spec-id":0,"fields":[]}'::JSONB,
    '{"order-id":0,"fields":[]}'::JSONB,
    FALSE,
    '{"owner":"test"}'::JSONB
);

-- 4. p_stage_create = TRUE（暂存创建）
SELECT iceberg_catalog.create_table(
    'ns_stage',
    'tbl_stage',
    '{"type":"struct","fields":[]}'::JSONB,
    p_stage_create => TRUE
);

-- 5. p_namespace 为空串 → 报错
SAVEPOINT sp5;
SELECT iceberg_catalog.create_table('', 'tbl', '{"type":"struct","fields":[]}'::JSONB);
ROLLBACK TO SAVEPOINT sp5;

-- 6. p_table_name 为空串 → 报错
SAVEPOINT sp6;
SELECT iceberg_catalog.create_table('ns', '', '{"type":"struct","fields":[]}'::JSONB);
ROLLBACK TO SAVEPOINT sp6;

-- 7. p_schema 为 NULL → 报错
SAVEPOINT sp7;
SELECT iceberg_catalog.create_table('ns', 'tbl', NULL::JSONB);
ROLLBACK TO SAVEPOINT sp7;

-- 8. p_properties 传入空对象
SELECT iceberg_catalog.create_table(
    'ns_props',
    'tbl_props',
    '{"type":"struct","fields":[]}'::JSONB,
    p_properties => '{}'::JSONB
);

ROLLBACK;
