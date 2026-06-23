-- ============================================================================
-- iceberg_catalog.commit_table 测试用例
--
-- 前置条件：iceberg_catalog 扩展已安装
-- ============================================================================

BEGIN;

SELECT iceberg_catalog.create_namespace('test_ns', '{}'::jsonb);
SELECT iceberg_catalog.create_table(
    'test_ns', 'test_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::jsonb
);

-- Capture initial metadata_location for later comparison
CREATE TEMP TABLE _orig_meta AS
SELECT metadata_location FROM iceberg_catalog.tables_internal
WHERE namespace = 'test_ns' AND table_name = 'test_tbl';

-- 1. 基础调用：传入 4 个必填参数，返回合法 JSONB
SELECT jsonb_typeof(iceberg_catalog.commit_table(
    'test_ns',
    'test_tbl',
    '[{"type":"assert-table-uuid","uuid":"550e8400-e29b-41d4-a716-446655440000"}]'::JSONB,
    '[{"action":"add-snapshot","snapshot":{"snapshot-id":1,"timestamp-ms":4782185701401,"manifest-list":"s3://bucket/tbl/metadata/snap-1.avro","summary":{"operation":"append"}}}]'::JSONB
)) AS result_type;

-- 2. 返回结构包含两个顶层 key
SELECT
    iceberg_catalog.commit_table('test_ns', 'test_tbl', '[{"type":"assert-ref-snapshot-id","ref":"main","snapshot-id":0}]'::JSONB, '[{"action":"add-snapshot","snapshot":{"snapshot-id":2,"timestamp-ms":4782185701401,"manifest-list":"s3://bucket/tbl/metadata/snap-2.avro","summary":{"operation":"append"}}}]'::JSONB) ? 'metadata-location' AS has_metadata_location,
    iceberg_catalog.commit_table('test_ns', 'test_tbl', '[{"type":"assert-ref-snapshot-id","ref":"main","snapshot-id":0}]'::JSONB, '[{"action":"add-snapshot","snapshot":{"snapshot-id":3,"timestamp-ms":4782185701402,"manifest-list":"s3://bucket/tbl/metadata/snap-3.avro","summary":{"operation":"append"}}}]'::JSONB) ? 'metadata'          AS has_metadata;

-- 2.1 验证 snapshot 已写入（3 次 commit → 3 条记录）
SELECT count(*) = 3 AS three_snapshots
FROM iceberg_catalog.snapshots s
JOIN iceberg_catalog.tables_internal t ON s.table_uuid = t.table_uuid
WHERE t.namespace = 'test_ns' AND t.table_name = 'test_tbl';

-- 2.2 验证 metadata_location 已更新（不等于建表时的值）
SELECT t.metadata_location != o.metadata_location AS meta_updated
FROM iceberg_catalog.tables_internal t, _orig_meta o
WHERE t.namespace = 'test_ns' AND t.table_name = 'test_tbl';

-- 2.3 验证 snapshot_id 匹配
SELECT s.snapshot_id = 3 AS snap_id_matches
FROM iceberg_catalog.snapshots s
JOIN iceberg_catalog.tables_internal t ON s.table_uuid = t.table_uuid
WHERE t.namespace = 'test_ns' AND t.table_name = 'test_tbl'
  AND s.snapshot_id = (SELECT MAX(snapshot_id) FROM iceberg_catalog.snapshots
                        WHERE table_uuid = t.table_uuid);

-- 3. p_namespace 为空串 → 报错
SAVEPOINT sp3;
SELECT iceberg_catalog.commit_table('', 'tbl', '[{"type":"assert-table-uuid","uuid":"0"}]'::JSONB, '[{"action":"add-snapshot"}]'::JSONB);
ROLLBACK TO SAVEPOINT sp3;

-- 4. p_table 为空串 → 报错
SAVEPOINT sp4;
SELECT iceberg_catalog.commit_table('ns', '', '[{"type":"assert-table-uuid","uuid":"0"}]'::JSONB, '[{"action":"add-snapshot"}]'::JSONB);
ROLLBACK TO SAVEPOINT sp4;

-- 5. p_requirements 为 NULL → 报错
SAVEPOINT sp5;
SELECT iceberg_catalog.commit_table('ns', 'tbl', NULL::JSONB, '[{"action":"add-snapshot"}]'::JSONB);
ROLLBACK TO SAVEPOINT sp5;

-- 6. p_updates 为 NULL → 报错
SAVEPOINT sp6;
SELECT iceberg_catalog.commit_table('ns', 'tbl', '[{"type":"assert-table-uuid","uuid":"0"}]'::JSONB, NULL::JSONB);
ROLLBACK TO SAVEPOINT sp6;

DROP TABLE IF EXISTS _orig_meta;

ROLLBACK;
