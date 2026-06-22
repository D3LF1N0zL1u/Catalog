-- ============================================================================
-- iceberg_catalog.rename_table 测试用例
-- ============================================================================
BEGIN;
BEGIN
SELECT iceberg_catalog.create_namespace('rename_src_ns', '{}'::jsonb);
                  create_namespace                  
----------------------------------------------------
 {"namespace": ["rename_src_ns"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_namespace('rename_dst_ns', '{}'::jsonb);
                  create_namespace                  
----------------------------------------------------
 {"namespace": ["rename_dst_ns"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_namespace('rename_same_ns', '{}'::jsonb);
                  create_namespace                   
-----------------------------------------------------
 {"namespace": ["rename_same_ns"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_namespace('rename_conflict_ns', '{}'::jsonb);
                    create_namespace                     
---------------------------------------------------------
 {"namespace": ["rename_conflict_ns"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_table(
    'rename_src_ns',
    'rename_src_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true},{"id":2,"name":"data","type":"string","required":false}]}'::JSONB,
    'file:///tmp/rename/src'
);
                                                                                                                                                                                                                                                                                                                                                                        create_table                                                                                                                                                                                                                                                                                                                                                                         
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}, {"id": 2, "name": "data", "type": "string", "required": false}], "schema-id": 0}], "location": "file:///tmp/rename/src", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 2, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/rename/src/metadata/00000-<uuid>.metadata.json"}
(1 row)
SELECT iceberg_catalog.create_table(
    'rename_same_ns',
    'old_name',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::JSONB
);
                                                                                                                                                                                                                                                                                                                                                                       create_table                                                                                                                                                                                                                                                                                                                                                                        
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}], "schema-id": 0}], "location": "file:///tmp/iceberg_warehouse/rename_same_ns/old_name", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 1, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/iceberg_warehouse/rename_same_ns/old_name/metadata/00000-<uuid>.metadata.json"}
(1 row)
SELECT iceberg_catalog.create_table(
    'rename_src_ns',
    'type_check_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::JSONB
);
                                                                                                                                                                                                                                                                                                                                                                            create_table                                                                                                                                                                                                                                                                                                                                                                             
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}], "schema-id": 0}], "location": "file:///tmp/iceberg_warehouse/rename_src_ns/type_check_tbl", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 1, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/iceberg_warehouse/rename_src_ns/type_check_tbl/metadata/00000-<uuid>.metadata.json"}
(1 row)
SELECT iceberg_catalog.create_table(
    'rename_conflict_ns',
    'rename_conflict_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::JSONB,
    'file:///tmp/rename/conflict'
);
                                                                                                                                                                                                                                                                                                                                             create_table                                                                                                                                                                                                                                                                                                                                              
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 {"config": {}, "metadata": {"refs": {}, "schemas": [{"type": "struct", "fields": [{"id": 1, "name": "id", "type": "long", "required": true}], "schema-id": 0}], "location": "file:///tmp/rename/conflict", "table-uuid": "<uuid>", "sort-orders": [{"fields": [], "order-id": 0}], "format-version": 2, "last-column-id": 1, "default-spec-id": 0, "last-updated-ms": <ts>, "partition-specs": [{"fields": [], "spec-id": 0}], "current-schema-id": 0, "last-partition-id": 999, "last-sequence-number": 0, "default-sort-order-id": 0}, "metadata-location": "file:///tmp/rename/conflict/metadata/00000-<uuid>.metadata.json"}
(1 row)
-- 1. 基础调用：返回 {"success": true}
SELECT iceberg_catalog.rename_table(
    'rename_src_ns',
    'rename_src_tbl',
    'rename_dst_ns',
    'rename_dst_tbl'
) AS rename_result;
   rename_result   
-------------------
 {"success": true}
(1 row)
-- 1.1 验证外表已迁移
SELECT count(*) = 0 AS old_table_gone
FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'rename_src_ns' AND c.relname = 'rename_src_tbl' AND c.relkind = 'f';
 old_table_gone 
----------------
 t
(1 row)
SELECT count(*) = 1 AS new_table_exists
FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'rename_dst_ns' AND c.relname = 'rename_dst_tbl' AND c.relkind = 'f';
 new_table_exists 
------------------
 t
(1 row)
-- 2. 同 Namespace 内重命名
SELECT iceberg_catalog.rename_table(
    'rename_same_ns',
    'old_name',
    'rename_same_ns',
    'new_name'
) AS same_namespace_result;
 same_namespace_result 
-----------------------
 {"success": true}
(1 row)
-- 2.1 验证同 namespace 重命名后外表已更新
SELECT count(*) = 0 AS old_name_gone
FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'rename_same_ns' AND c.relname = 'old_name' AND c.relkind = 'f';
 old_name_gone 
---------------
 t
(1 row)
SELECT count(*) = 1 AS new_name_exists
FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'rename_same_ns' AND c.relname = 'new_name' AND c.relkind = 'f';
 new_name_exists 
-----------------
 t
(1 row)
-- 3. 验证返回 JSONB object
SELECT jsonb_typeof(iceberg_catalog.rename_table(
    'rename_src_ns',
    'type_check_tbl',
    'rename_dst_ns',
    'type_check_tbl_renamed'
)) AS result_type;
 result_type 
-------------
 object
(1 row)
-- 4. p_src_ns 为空串 → 报错
SAVEPOINT sp4;
SAVEPOINT
SELECT iceberg_catalog.rename_table('', 'rename_dst_tbl', 'rename_dst_ns', 'rename_dst_tbl_2');
gsql:test/sql/rename_table.sql:80: ERROR:  p_src_ns is required and must not be empty
CONTEXT:  referenced column: rename_table
ROLLBACK TO SAVEPOINT sp4;
ROLLBACK
-- 5. p_src_table 为空串 → 报错
SAVEPOINT sp5;
SAVEPOINT
SELECT iceberg_catalog.rename_table('rename_dst_ns', '', 'rename_dst_ns', 'rename_dst_tbl_2');
gsql:test/sql/rename_table.sql:85: ERROR:  p_src_table is required and must not be empty
CONTEXT:  referenced column: rename_table
ROLLBACK TO SAVEPOINT sp5;
ROLLBACK
-- 6. p_dst_ns 为空串 → 报错
SAVEPOINT sp6;
SAVEPOINT
SELECT iceberg_catalog.rename_table('rename_dst_ns', 'rename_dst_tbl', '', 'rename_dst_tbl_2');
gsql:test/sql/rename_table.sql:90: ERROR:  p_dst_ns is required and must not be empty
CONTEXT:  referenced column: rename_table
ROLLBACK TO SAVEPOINT sp6;
ROLLBACK
-- 7. p_dst_table 为空串 → 报错
SAVEPOINT sp7;
SAVEPOINT
SELECT iceberg_catalog.rename_table('rename_dst_ns', 'rename_dst_tbl', 'rename_dst_ns', '');
gsql:test/sql/rename_table.sql:95: ERROR:  p_dst_table is required and must not be empty
CONTEXT:  referenced column: rename_table
ROLLBACK TO SAVEPOINT sp7;
ROLLBACK
-- 8. p_src_ns 为 NULL → 报错
SAVEPOINT sp8;
SAVEPOINT
SELECT iceberg_catalog.rename_table(NULL, 'rename_dst_tbl', 'rename_dst_ns', 'rename_dst_tbl_2');
gsql:test/sql/rename_table.sql:100: ERROR:  p_src_ns is required and must not be empty
CONTEXT:  referenced column: rename_table
ROLLBACK TO SAVEPOINT sp8;
ROLLBACK
-- 9. 验证 rename 后元信息表只更新 namespace/table_name
SELECT namespace, table_name
FROM iceberg_catalog.tables_internal
WHERE namespace = 'rename_dst_ns'
  AND table_name = 'rename_dst_tbl';
   namespace   |   table_name   
---------------+----------------
 rename_dst_ns | rename_dst_tbl
(1 row)
SELECT
    relid IS NOT NULL AS relid_preserved,
    namespace,
    table_name,
    table_uuid IS NOT NULL AS table_uuid_preserved,
    metadata_location,
    previous_metadata_location IS NULL AS previous_metadata_location_preserved,
    table_location,
    last_column_id,
    current_schema_id,
    current_snapshot_id IS NULL AS current_snapshot_id_preserved,
    default_spec_id
FROM iceberg_catalog.tables_internal
WHERE namespace = 'rename_dst_ns'
  AND table_name = 'rename_dst_tbl';
 relid_preserved |   namespace   |   table_name   | table_uuid_preserved |                                    metadata_location                                     | previous_metadata_location_preserved |     table_location     | last_column_id | current_schema_id | current_snapshot_id_preserved | default_spec_id 
-----------------+---------------+----------------+----------------------+------------------------------------------------------------------------------------------+--------------------------------------+------------------------+----------------+-------------------+-------------------------------+-----------------
 t               | rename_dst_ns | rename_dst_tbl | t                    | file:///tmp/rename/src/metadata/00000-<uuid>.metadata.json | t                                    | file:///tmp/rename/src |              2 |                 0 | t                             |               0
(1 row)
SELECT count(*) = 2 AS schema_fields_preserved
FROM iceberg_catalog.table_schemas s
JOIN iceberg_catalog.tables_internal t
  ON s.table_uuid = t.table_uuid
WHERE t.namespace = 'rename_dst_ns'
  AND t.table_name = 'rename_dst_tbl';
 schema_fields_preserved 
-------------------------
 t
(1 row)
SELECT count(*) = 1 AS partition_spec_preserved
FROM iceberg_catalog.partition_specs p
JOIN iceberg_catalog.tables_internal t
  ON p.table_uuid = t.table_uuid
WHERE t.namespace = 'rename_dst_ns'
  AND t.table_name = 'rename_dst_tbl';
 partition_spec_preserved 
--------------------------
 t
(1 row)
SELECT count(*) AS old_name_count
FROM iceberg_catalog.tables_internal
WHERE namespace = 'rename_src_ns'
  AND table_name = 'rename_src_tbl';
 old_name_count 
----------------
              0
(1 row)
-- 10. 源表不存在 → 报错
SAVEPOINT sp10;
SAVEPOINT
SELECT iceberg_catalog.rename_table(
    'rename_src_ns',
    'rename_src_tbl',
    'rename_dst_ns',
    'rename_dst_tbl_2'
);
gsql:test/sql/rename_table.sql:151: ERROR:  rename table metadata: source table not found
CONTEXT:  referenced column: rename_table
ROLLBACK TO SAVEPOINT sp10;
ROLLBACK
-- 11. 目标 Namespace 不存在 → 报错
SAVEPOINT sp11;
SAVEPOINT
SELECT iceberg_catalog.rename_table(
    'rename_dst_ns',
    'rename_dst_tbl',
    'rename_missing_ns',
    'rename_dst_tbl_2'
);
gsql:test/sql/rename_table.sql:161: ERROR:  rename table metadata: destination namespace not found
CONTEXT:  referenced column: rename_table
ROLLBACK TO SAVEPOINT sp11;
ROLLBACK
-- 12. 目标表已存在 → 报错
SAVEPOINT sp12;
SAVEPOINT
SELECT iceberg_catalog.rename_table(
    'rename_dst_ns',
    'rename_dst_tbl',
    'rename_conflict_ns',
    'rename_conflict_tbl'
);
gsql:test/sql/rename_table.sql:171: ERROR:  rename table metadata: destination table already exists
CONTEXT:  referenced column: rename_table
ROLLBACK TO SAVEPOINT sp12;
ROLLBACK
ROLLBACK;
ROLLBACK
