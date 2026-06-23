-- ============================================================================
-- iceberg_catalog.drop_table 测试用例
-- ============================================================================
BEGIN;
BEGIN
SELECT iceberg_catalog.create_namespace('drop_ns', '{}'::jsonb);
               create_namespace               
----------------------------------------------
 {"namespace": ["drop_ns"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_namespace('drop_false_ns', '{}'::jsonb);
                  create_namespace                  
----------------------------------------------------
 {"namespace": ["drop_false_ns"], "properties": {}}
(1 row)
CREATE TEMP TABLE drop_table_test_ids(
    label TEXT PRIMARY KEY,
    table_uuid UUID NOT NULL
);
gsql:test/sql/drop_table.sql:13: NOTICE:  CREATE TABLE / PRIMARY KEY will create implicit index "drop_table_test_ids_pkey" for table "drop_table_test_ids"
CREATE TABLE
SELECT iceberg_catalog.create_table(
    'drop_ns',
    'drop_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true},{"id":2,"name":"data","type":"string","required":false}]}'::JSONB,
    'file:///tmp/drop/src'
);
                                                                                                                                                                                                                                                                                                                                                                      create_table                                                                                                                                                                                                                                                                                                                                                                       
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}, {"id": 2, "name": "data", "type": "string", "required": false}], "schema-id": 0}], "location": "file:///tmp/drop/src", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 2, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/drop/src/metadata/00000-<uuid>.metadata.json"}
(1 row)
INSERT INTO drop_table_test_ids(label, table_uuid)
SELECT 'basic', table_uuid
FROM iceberg_catalog.tables_internal
WHERE namespace = 'drop_ns'
  AND table_name = 'drop_tbl';
INSERT 0 1
SELECT iceberg_catalog.create_table(
    'drop_false_ns',
    'drop_false_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::JSONB
);
                                                                                                                                                                                                                                                                                                                                                                            create_table                                                                                                                                                                                                                                                                                                                                                                             
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}], "schema-id": 0}], "location": "file:///tmp/iceberg_warehouse/drop_false_ns/drop_false_tbl", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 1, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/iceberg_warehouse/drop_false_ns/drop_false_tbl/metadata/00000-<uuid>.metadata.json"}
(1 row)
INSERT INTO drop_table_test_ids(label, table_uuid)
SELECT 'explicit_false', table_uuid
FROM iceberg_catalog.tables_internal
WHERE namespace = 'drop_false_ns'
  AND table_name = 'drop_false_tbl';
INSERT 0 1
-- 1. 基础调用：返回 {"success": true}
SELECT iceberg_catalog.drop_table('drop_ns', 'drop_tbl') AS drop_result;
    drop_result    
-------------------
 {"success": true}
(1 row)
-- 2. 验证 drop 后元信息表数据已清理
SELECT count(*) = 0 AS table_head_deleted
FROM iceberg_catalog.tables_internal
WHERE table_uuid = (
    SELECT table_uuid FROM drop_table_test_ids WHERE label = 'basic'
);
 table_head_deleted 
--------------------
 t
(1 row)
SELECT count(*) = 0 AS schema_rows_deleted
FROM iceberg_catalog.table_schemas
WHERE table_uuid = (
    SELECT table_uuid FROM drop_table_test_ids WHERE label = 'basic'
);
 schema_rows_deleted 
---------------------
 t
(1 row)
SELECT count(*) = 0 AS partition_rows_deleted
FROM iceberg_catalog.partition_specs
WHERE table_uuid = (
    SELECT table_uuid FROM drop_table_test_ids WHERE label = 'basic'
);
 partition_rows_deleted 
------------------------
 t
(1 row)
-- 2.1 验证外表已删除
SELECT count(*) = 0 AS foreign_table_dropped
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'drop_ns' AND c.relname = 'drop_tbl' AND c.relkind = 'f';
 foreign_table_dropped 
-----------------------
 t
(1 row)
-- 3. p_purge = FALSE（显式传入）
SELECT iceberg_catalog.drop_table('drop_false_ns', 'drop_false_tbl', FALSE) AS drop_false_result;
 drop_false_result 
-------------------
 {"success": true}
(1 row)
SELECT count(*) = 0 AS explicit_false_table_deleted
FROM iceberg_catalog.tables_internal
WHERE table_uuid = (
    SELECT table_uuid FROM drop_table_test_ids WHERE label = 'explicit_false'
);
 explicit_false_table_deleted 
------------------------------
 t
(1 row)
-- 4. p_purge = TRUE → 报错（暂不支持）
SAVEPOINT sp4;
SAVEPOINT
SELECT iceberg_catalog.drop_table('ns', 'tbl', TRUE);
gsql:test/sql/drop_table.sql:79: ERROR:  p_purge is not yet supported
CONTEXT:  referenced column: drop_table
ROLLBACK TO SAVEPOINT sp4;
ROLLBACK
-- 5. p_namespace 为空串 → 报错
SAVEPOINT sp5;
SAVEPOINT
SELECT iceberg_catalog.drop_table('', 'tbl');
gsql:test/sql/drop_table.sql:84: ERROR:  p_namespace is required and must not be empty
CONTEXT:  referenced column: drop_table
ROLLBACK TO SAVEPOINT sp5;
ROLLBACK
-- 6. p_table 为空串 → 报错
SAVEPOINT sp6;
SAVEPOINT
SELECT iceberg_catalog.drop_table('ns', '');
gsql:test/sql/drop_table.sql:89: ERROR:  p_table is required and must not be empty
CONTEXT:  referenced column: drop_table
ROLLBACK TO SAVEPOINT sp6;
ROLLBACK
-- 7. p_namespace 为 NULL → 报错
SAVEPOINT sp7;
SAVEPOINT
SELECT iceberg_catalog.drop_table(NULL, 'tbl');
gsql:test/sql/drop_table.sql:94: ERROR:  p_namespace is required and must not be empty
CONTEXT:  referenced column: drop_table
ROLLBACK TO SAVEPOINT sp7;
ROLLBACK
-- 8. p_table 为 NULL → 报错
SAVEPOINT sp8;
SAVEPOINT
SELECT iceberg_catalog.drop_table('ns', NULL);
gsql:test/sql/drop_table.sql:99: ERROR:  p_table is required and must not be empty
CONTEXT:  referenced column: drop_table
ROLLBACK TO SAVEPOINT sp8;
ROLLBACK
-- 9. 表不存在 → 报错
SAVEPOINT sp9;
SAVEPOINT
SELECT iceberg_catalog.drop_table('drop_ns', 'drop_tbl');
gsql:test/sql/drop_table.sql:104: ERROR:  Drop foreign table failed: failed to finish SPI
CONTEXT:  referenced column: drop_table
ROLLBACK TO SAVEPOINT sp9;
ROLLBACK
-- 10. 创建后立即删除（覆盖 hook 插入点的正常路径）
SELECT iceberg_catalog.create_table(
    'drop_ns',
    'drop_immediate_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::JSONB
);
                                                                                                                                                                                                                                                                                                                                                                          create_table                                                                                                                                                                                                                                                                                                                                                                           
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}], "schema-id": 0}], "location": "file:///tmp/iceberg_warehouse/drop_ns/drop_immediate_tbl", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 1, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/iceberg_warehouse/drop_ns/drop_immediate_tbl/metadata/00000-<uuid>.metadata.json"}
(1 row)
SELECT iceberg_catalog.drop_table('drop_ns', 'drop_immediate_tbl') AS drop_immediate_result;
 drop_immediate_result 
-----------------------
 {"success": true}
(1 row)
-- 10.1 验证外表已删除
SELECT count(*) = 0 AS immediate_drop_fdw_removed
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'drop_ns' AND c.relname = 'drop_immediate_tbl' AND c.relkind = 'f';
 immediate_drop_fdw_removed 
----------------------------
 t
(1 row)
ROLLBACK;
ROLLBACK
