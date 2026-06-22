-- ============================================================================
-- iceberg_catalog.drop_namespace 测试用例
--
-- 前置条件：iceberg_catalog 扩展已安装
-- ============================================================================
BEGIN;
BEGIN
-- ============================================================================
-- 第一部分：正常场景 — 返回类型与结构校验
-- ============================================================================
-- 1. 返回合法 JSONB
SELECT iceberg_catalog.create_namespace('some_ns');
               create_namespace               
----------------------------------------------
 {"namespace": ["some_ns"], "properties": {}}
(1 row)
SELECT jsonb_typeof(iceberg_catalog.drop_namespace('some_ns')) AS result_type;
 result_type 
-------------
 object
(1 row)
-- 2. 返回结构包含 "success" key，且值为 true
SELECT iceberg_catalog.create_namespace('ns_success_key');
                  create_namespace                   
-----------------------------------------------------
 {"namespace": ["ns_success_key"], "properties": {}}
(1 row)
SELECT iceberg_catalog.drop_namespace('ns_success_key') ? 'success' AS has_success;
 has_success 
-------------
 t
(1 row)
SELECT iceberg_catalog.create_namespace('ns_success_val');
                  create_namespace                   
-----------------------------------------------------
 {"namespace": ["ns_success_val"], "properties": {}}
(1 row)
SELECT (iceberg_catalog.drop_namespace('ns_success_val') ->> 'success')::BOOLEAN AS success_value;
 success_value 
---------------
 t
(1 row)
-- ============================================================================
-- 第二部分：删除已存在的 Namespace（stub 阶段不实际删除）
-- ============================================================================
-- TODO: 以下测试在 stub 替换为 META 调用后启用
-- 3. 创建 namespace 后删除，验证已删除
-- INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
-- VALUES (current_database(), 'temp_ns', '{"owner": "test"}'::JSONB);
-- SELECT iceberg_catalog.drop_namespace('temp_ns');
-- SELECT count(*) = 0 AS is_deleted
-- FROM iceberg_catalog.namespaces
-- WHERE namespace = 'temp_ns';
-- ============================================================================
-- 第三部分：参数校验 — 报错场景
-- ============================================================================
-- 4. p_namespace 为空字符串 → 报错 (P0001)
SAVEPOINT sp4;
SAVEPOINT
SELECT iceberg_catalog.drop_namespace('');
gsql:test/sql/drop_namespace.sql:43: ERROR:  namespace must not be empty
CONTEXT:  referenced column: drop_namespace
ROLLBACK TO SAVEPOINT sp4;
ROLLBACK
-- 5. p_namespace 为 NULL → 报错 (P0001)
SAVEPOINT sp5;
SAVEPOINT
SELECT iceberg_catalog.drop_namespace(NULL::TEXT);
gsql:test/sql/drop_namespace.sql:48: ERROR:  namespace must not be empty
CONTEXT:  referenced column: drop_namespace
ROLLBACK TO SAVEPOINT sp5;
ROLLBACK
-- ============================================================================
-- 第四部分：Namespace 不存在 — 报错场景
-- ============================================================================
-- 6. Namespace 不存在 → 报错 (P0004)
SAVEPOINT sp6;
SAVEPOINT
SELECT iceberg_catalog.drop_namespace('non_existent_namespace');
gsql:test/sql/drop_namespace.sql:57: ERROR:  The given namespace does not exist
CONTEXT:  referenced column: drop_namespace
ROLLBACK TO SAVEPOINT sp6;
ROLLBACK
-- ============================================================================
-- 第五部分：未实现的功能 — 报错场景 (Stub 阶段不触发，预留)
-- ============================================================================
-- ============================================================================
-- 第六部分：Schema 删除验证
-- ============================================================================
-- 7. drop_namespace 应删除对应的 openGauss schema
SAVEPOINT sp7;
SAVEPOINT
SELECT iceberg_catalog.create_namespace('ns_schema_check');
                   create_namespace                   
------------------------------------------------------
 {"namespace": ["ns_schema_check"], "properties": {}}
(1 row)
-- 删除前 schema 存在
SELECT count(*) = 1 AS schema_exists_before
FROM pg_namespace
WHERE nspname = 'ns_schema_check';
 schema_exists_before 
----------------------
 t
(1 row)
SELECT iceberg_catalog.drop_namespace('ns_schema_check');
  drop_namespace   
-------------------
 {"success": true}
(1 row)
-- 删除后 schema 不存在
SELECT count(*) = 0 AS schema_gone_after
FROM pg_namespace
WHERE nspname = 'ns_schema_check';
 schema_gone_after 
-------------------
 t
(1 row)
ROLLBACK TO SAVEPOINT sp7;
ROLLBACK
-- ============================================================================
-- 第七部分：未实现的功能 — 报错场景 (Stub 阶段不触发，预留)
-- ============================================================================
-- 8. TODO: Namespace 下有表 → 报错 (P0005)
-- SAVEPOINT sp8;
-- INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
-- VALUES (current_database(), 'ns_with_tables', '{}'::JSONB);
-- INSERT INTO iceberg_catalog.tables_external(catalog_name, namespace, table_name, metadata_location)
-- VALUES (current_database(), 'ns_with_tables', 'some_table', 'file:///tmp/metadata.json');
-- SELECT iceberg_catalog.drop_namespace('ns_with_tables');
-- ROLLBACK TO SAVEPOINT sp7;
ROLLBACK;
ROLLBACK
