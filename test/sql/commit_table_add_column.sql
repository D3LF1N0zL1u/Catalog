-- ============================================================================
-- commit_table / add_column — metadata 层正确性验证
-- ============================================================================

BEGIN;

-- ### Setup: use SQL functions to create namespace and table ###
SELECT iceberg_catalog.create_namespace('cmt_test', '{}'::jsonb);

SELECT iceberg_catalog.create_table(
    'cmt_test', 't1',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true},{"id":2,"name":"data","type":"string","required":false}]}'::jsonb
) AS create_result;

-- Capture the generated table_uuid for later assertions
CREATE TEMP TABLE _t1_uuid AS
SELECT table_uuid, metadata_location, last_column_id, current_schema_id
FROM iceberg_catalog.tables_internal
WHERE namespace = 'cmt_test' AND table_name = 't1';

-- ============================================================================
-- T1: commit_table → metadata_location 轮转 + snapshot 写入
-- ============================================================================

-- 初始: snapshots 空
SELECT count(*) = 0 AS t1_snap_empty
FROM iceberg_catalog.snapshots s, _t1_uuid u
WHERE s.table_uuid = u.table_uuid;

-- 执行 commit_table
SELECT iceberg_catalog.commit_table('cmt_test', 't1',
    '[]'::jsonb,
    '[{"action":"add-snapshot","snapshot":{"snapshot-id":100,"timestamp-ms":4782185701401,"manifest-list":"s3://m","summary":{"operation":"append"},"schema-id":0}}]'::jsonb
) AS cmt_result;

-- 验证: metadata_location 已更新, previous 自动轮转
SELECT t.metadata_location != u.metadata_location  AS t1_meta_updated,
       t.previous_metadata_location = u.metadata_location AS t1_prev_rolled
FROM iceberg_catalog.tables_internal t, _t1_uuid u
WHERE t.namespace = 'cmt_test' AND t.table_name = 't1';

-- 验证: snapshot 已写入
SELECT count(*) = 1 AS t1_snap_inserted
FROM iceberg_catalog.snapshots s, _t1_uuid u
WHERE s.table_uuid = u.table_uuid;

-- ============================================================================
-- T2: add_column → schema 展开写入 + 状态字段更新
-- ============================================================================

-- 初始: 2 fields
SELECT count(*) = 2 AS t2_schema_before
FROM iceberg_catalog.table_schemas s, _t1_uuid u
WHERE s.table_uuid = u.table_uuid;

SELECT last_column_id = 2 AND current_schema_id = 0 AS t2_state_before
FROM iceberg_catalog.tables_internal
WHERE namespace = 'cmt_test' AND table_name = 't1';

-- 执行 add_column
SELECT iceberg_catalog.add_column('cmt_test', 't1', 'col3', 'string', 'third column') AS add_result;

-- 验证: schema 字段增加到 3 个
SELECT count(*) = 3 AS t2_schema_after
FROM iceberg_catalog.table_schemas s, _t1_uuid u
WHERE s.table_uuid = u.table_uuid;

-- 验证: last_column_id 和 current_schema_id 已更新
SELECT last_column_id > 2 AND current_schema_id > 0 AS t2_state_updated
FROM iceberg_catalog.tables_internal
WHERE namespace = 'cmt_test' AND table_name = 't1';

-- ============================================================================
-- T3: 参数校验
-- ============================================================================

SAVEPOINT sp1;
SELECT iceberg_catalog.commit_table('', 't', '[]'::jsonb, '[]'::jsonb);
ROLLBACK TO SAVEPOINT sp1;

SAVEPOINT sp2;
SELECT iceberg_catalog.commit_table('n', '', '[]'::jsonb, '[]'::jsonb);
ROLLBACK TO SAVEPOINT sp2;

SAVEPOINT sp3;
SELECT iceberg_catalog.add_column('', 't', 'c', 'string');
ROLLBACK TO SAVEPOINT sp3;

SAVEPOINT sp4;
SELECT iceberg_catalog.add_column('n', 't', '', 'string');
ROLLBACK TO SAVEPOINT sp4;

-- ============================================================================
-- T4: 表不存在
-- ============================================================================

SAVEPOINT sp5;
SELECT iceberg_catalog.commit_table('cmt_test', 'no_such_table', '[]'::jsonb, '[]'::jsonb);
ROLLBACK TO SAVEPOINT sp5;

SAVEPOINT sp6;
SELECT iceberg_catalog.add_column('cmt_test', 'no_such_table', 'col', 'string');
ROLLBACK TO SAVEPOINT sp6;

-- ============================================================================
-- T5: drop_table 级联删除
-- ============================================================================

SELECT iceberg_catalog.drop_table('cmt_test', 't1', false) AS drop_result;

SELECT count(*) = 0 AS t5_snaps_cleaned
FROM iceberg_catalog.snapshots s, _t1_uuid u
WHERE s.table_uuid = u.table_uuid;

SELECT count(*) = 0 AS t5_schemas_cleaned
FROM iceberg_catalog.table_schemas s, _t1_uuid u
WHERE s.table_uuid = u.table_uuid;

SELECT count(*) = 0 AS t5_specs_cleaned
FROM iceberg_catalog.partition_specs p, _t1_uuid u
WHERE p.table_uuid = u.table_uuid;

DROP TABLE _t1_uuid;
ROLLBACK;
