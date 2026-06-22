-- ============================================================================
-- iceberg_catalog.add_column 测试用例
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
-- 1. 基础调用：传入 4 个必填参数，返回合法 JSONB
SELECT jsonb_typeof(iceberg_catalog.add_column(
    'test_ns',
    'test_tbl',
    'new_col',
    'string'
)) AS result_type;
 result_type 
-------------
 object
(1 row)
-- 2. 返回结构包含两个顶层 key
SELECT
    iceberg_catalog.add_column('test_ns', 'test_tbl', 'col_a', 'int') ? 'metadata-location' AS has_metadata_location,
    iceberg_catalog.add_column('test_ns', 'test_tbl', 'col_b', 'long') ? 'metadata'          AS has_metadata;
 has_metadata_location | has_metadata 
-----------------------+--------------
 t                     | t
(1 row)
-- 3. 传入 p_column_doc 参数
SELECT iceberg_catalog.add_column(
    'test_ns',
    'test_tbl',
    'col_with_doc',
    'decimal(10,2)',
    p_column_doc => 'A documented column'
);
                                                   add_column                                                    
-----------------------------------------------------------------------------------------------------------------
 {"metadata": {}, "metadata-location": "file:///tmp/iceberg_catalog/test_ns/test_tbl/metadata/v2.metadata.json"}
(1 row)
-- 3.1 验证外表已增加新列
SELECT count(*) = 1 AS col_new_col_exists
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'test_ns' AND c.relname = 'test_tbl'
  AND a.attname = 'new_col' AND a.attnum > 0 AND NOT a.attisdropped;
 col_new_col_exists 
--------------------
 t
(1 row)
SELECT count(*) = 1 AS col_col_a_exists
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'test_ns' AND c.relname = 'test_tbl'
  AND a.attname = 'col_a' AND a.attnum > 0 AND NOT a.attisdropped;
 col_col_a_exists 
------------------
 t
(1 row)
SELECT count(*) = 1 AS col_col_with_doc_exists
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'test_ns' AND c.relname = 'test_tbl'
  AND a.attname = 'col_with_doc' AND a.attnum > 0 AND NOT a.attisdropped;
 col_col_with_doc_exists 
-------------------------
 t
(1 row)
-- 4. p_namespace 为空串 → 报错
SAVEPOINT sp4;
SAVEPOINT
SELECT iceberg_catalog.add_column('', 'tbl', 'col', 'string');
gsql:test/sql/add_column.sql:59: ERROR:  p_namespace is required and must not be empty
CONTEXT:  referenced column: add_column
ROLLBACK TO SAVEPOINT sp4;
ROLLBACK
-- 5. p_table 为空串 → 报错
SAVEPOINT sp5;
SAVEPOINT
SELECT iceberg_catalog.add_column('ns', '', 'col', 'string');
gsql:test/sql/add_column.sql:64: ERROR:  p_table is required and must not be empty
CONTEXT:  referenced column: add_column
ROLLBACK TO SAVEPOINT sp5;
ROLLBACK
-- 6. p_column_name 为空串 → 报错
SAVEPOINT sp6;
SAVEPOINT
SELECT iceberg_catalog.add_column('ns', 'tbl', '', 'string');
gsql:test/sql/add_column.sql:69: ERROR:  p_column_name is required and must not be empty
CONTEXT:  referenced column: add_column
ROLLBACK TO SAVEPOINT sp6;
ROLLBACK
-- 7. p_column_type 为空串 → 报错
SAVEPOINT sp7;
SAVEPOINT
SELECT iceberg_catalog.add_column('ns', 'tbl', 'col', '');
gsql:test/sql/add_column.sql:74: ERROR:  p_column_type is required and must not be empty
CONTEXT:  referenced column: add_column
ROLLBACK TO SAVEPOINT sp7;
ROLLBACK
ROLLBACK;
ROLLBACK
