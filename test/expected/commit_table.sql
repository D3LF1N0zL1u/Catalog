-- ============================================================================
-- iceberg_catalog.commit_table 测试用例
--
-- 前置条件：iceberg_catalog 扩展已安装
-- ============================================================================
BEGIN;
BEGIN
SELECT iceberg_catalog.create_namespace('test_ns', '{}'::jsonb);
               create_namespace               
----------------------------------------------
 {"namespace": ["test_ns"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_table(
    'test_ns', 'test_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::jsonb
);
                                                                                                                                                                                                                                                                                                                                                                create_table                                                                                                                                                                                                                                                                                                                                                                 
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}], "schema-id": 0}], "location": "file:///tmp/iceberg_warehouse/test_ns/test_tbl", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 1, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/iceberg_warehouse/test_ns/test_tbl/metadata/00000-<uuid>.metadata.json"}
(1 row)
-- Capture initial metadata_location for later comparison
CREATE TEMP TABLE _orig_meta AS
SELECT metadata_location FROM iceberg_catalog.tables_internal
WHERE namespace = 'test_ns' AND table_name = 'test_tbl';
INSERT 0 1
-- 1. 基础调用：传入 4 个必填参数，返回合法 JSONB
SELECT jsonb_typeof(iceberg_catalog.commit_table(
    'test_ns',
    'test_tbl',
    '[{"type":"assert-table-uuid","uuid":"<uuid>"}]'::JSONB,
    '[{"action":"add-snapshot","snapshot":{"snapshot-id":1,"timestamp-ms":4782185701401,"manifest-list":"s3://bucket/tbl/metadata/snap-1.avro","summary":{"operation":"append"}}}]'::JSONB
)) AS result_type;
 result_type 
-------------
 object
(1 row)
-- 2. 返回结构包含两个顶层 key
SELECT
    iceberg_catalog.commit_table('test_ns', 'test_tbl', '[{"type":"assert-ref-snapshot-id","ref":"main","snapshot-id":0}]'::JSONB, '[{"action":"add-snapshot","snapshot":{"snapshot-id":2,"timestamp-ms":4782185701401,"manifest-list":"s3://bucket/tbl/metadata/snap-2.avro","summary":{"operation":"append"}}}]'::JSONB) ? 'metadata-location' AS has_metadata_location,
    iceberg_catalog.commit_table('test_ns', 'test_tbl', '[{"type":"assert-ref-snapshot-id","ref":"main","snapshot-id":0}]'::JSONB, '[{"action":"add-snapshot","snapshot":{"snapshot-id":3,"timestamp-ms":4782185701402,"manifest-list":"s3://bucket/tbl/metadata/snap-3.avro","summary":{"operation":"append"}}}]'::JSONB) ? 'metadata'          AS has_metadata;
 has_metadata_location | has_metadata 
-----------------------+--------------
 t                     | t
(1 row)
-- 2.1 验证 snapshot 已写入（3 次 commit → 3 条记录）
SELECT count(*) = 3 AS three_snapshots
FROM iceberg_catalog.snapshots s
JOIN iceberg_catalog.tables_internal t ON s.table_uuid = t.table_uuid
WHERE t.namespace = 'test_ns' AND t.table_name = 'test_tbl';
 three_snapshots 
-----------------
 t
(1 row)
-- 2.2 验证 metadata_location 已更新（不等于建表时的值）
SELECT t.metadata_location != o.metadata_location AS meta_updated
FROM iceberg_catalog.tables_internal t, _orig_meta o
WHERE t.namespace = 'test_ns' AND t.table_name = 'test_tbl';
 meta_updated 
--------------
 t
(1 row)
-- 2.3 验证 snapshot_id 匹配
SELECT s.snapshot_id = 3 AS snap_id_matches
FROM iceberg_catalog.snapshots s
JOIN iceberg_catalog.tables_internal t ON s.table_uuid = t.table_uuid
WHERE t.namespace = 'test_ns' AND t.table_name = 'test_tbl'
  AND s.snapshot_id = (SELECT MAX(snapshot_id) FROM iceberg_catalog.snapshots
                        WHERE table_uuid = t.table_uuid);
 snap_id_matches 
-----------------
 t
(1 row)
-- 3. p_namespace 为空串 → 报错
SAVEPOINT sp3;
SAVEPOINT
SELECT iceberg_catalog.commit_table('', 'tbl', '[{"type":"assert-table-uuid","uuid":"0"}]'::JSONB, '[{"action":"add-snapshot"}]'::JSONB);
gsql:test/sql/commit_table.sql:54: ERROR:  p_namespace is required and must not be empty
CONTEXT:  referenced column: commit_table
ROLLBACK TO SAVEPOINT sp3;
ROLLBACK
-- 4. p_table 为空串 → 报错
SAVEPOINT sp4;
SAVEPOINT
SELECT iceberg_catalog.commit_table('ns', '', '[{"type":"assert-table-uuid","uuid":"0"}]'::JSONB, '[{"action":"add-snapshot"}]'::JSONB);
gsql:test/sql/commit_table.sql:59: ERROR:  p_table is required and must not be empty
CONTEXT:  referenced column: commit_table
ROLLBACK TO SAVEPOINT sp4;
ROLLBACK
-- 5. p_requirements 为 NULL → 报错
SAVEPOINT sp5;
SAVEPOINT
SELECT iceberg_catalog.commit_table('ns', 'tbl', NULL::JSONB, '[{"action":"add-snapshot"}]'::JSONB);
gsql:test/sql/commit_table.sql:64: ERROR:  p_requirements is required and must not be NULL
CONTEXT:  referenced column: commit_table
ROLLBACK TO SAVEPOINT sp5;
ROLLBACK
-- 6. p_updates 为 NULL → 报错
SAVEPOINT sp6;
SAVEPOINT
SELECT iceberg_catalog.commit_table('ns', 'tbl', '[{"type":"assert-table-uuid","uuid":"0"}]'::JSONB, NULL::JSONB);
gsql:test/sql/commit_table.sql:69: ERROR:  p_updates is required and must not be NULL
CONTEXT:  referenced column: commit_table
ROLLBACK TO SAVEPOINT sp6;
ROLLBACK
DROP TABLE IF EXISTS _orig_meta;
DROP TABLE
ROLLBACK;
ROLLBACK
