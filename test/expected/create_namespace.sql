-- ============================================================================
-- iceberg_catalog.create_namespace 测试用例
--
-- 前置条件：iceberg_catalog 扩展已安装
-- ============================================================================
BEGIN;
BEGIN
-- ============================================================================
-- 第一部分：正常场景
-- ============================================================================
-- 1. 基础调用：仅填必填参数 p_namespace，返回合法 JSONB
SELECT jsonb_typeof(iceberg_catalog.create_namespace('test_ns')) AS result_type;
 result_type 
-------------
 object
(1 row)
-- 2. 返回结构的顶层 key 校验：应包含 "namespace" 和 "properties"
WITH created AS (
    SELECT iceberg_catalog.create_namespace('test_ns_keys') AS result
)
SELECT
    result ? 'namespace'  AS has_namespace,
    result ? 'properties' AS has_properties
FROM created;
 has_namespace | has_properties 
---------------+----------------
 t             | t
(1 row)
-- 3. "namespace" 字段应为数组，且包含传入的命名空间
WITH created AS (
    SELECT iceberg_catalog.create_namespace('sales') AS result
)
SELECT
    jsonb_typeof(result -> 'namespace') AS namespace_type,
    (result -> 'namespace' -> 0)        AS first_element
FROM created;
 namespace_type | first_element 
----------------+---------------
 array          | "sales"
(1 row)
-- 4. p_properties 传入空对象
SELECT iceberg_catalog.create_namespace('ns_empty_props', '{}'::JSONB);
                  create_namespace                   
-----------------------------------------------------
 {"namespace": ["ns_empty_props"], "properties": {}}
(1 row)
-- 5. p_properties 传入自定义属性
SELECT iceberg_catalog.create_namespace(
    'accounting',
    '{"owner": "Ralph", "created_at": "1452120468"}'::JSONB
);
                                      create_namespace                                       
---------------------------------------------------------------------------------------------
 {"namespace": ["accounting"], "properties": {"owner": "Ralph", "created_at": "1452120468"}}
(1 row)
-- 6. 使用命名参数调用
SELECT iceberg_catalog.create_namespace(
    p_namespace => 'hr_dept',
    p_properties => '{"region": "us-east-1"}'::JSONB
);
                         create_namespace                          
-------------------------------------------------------------------
 {"namespace": ["hr_dept"], "properties": {"region": "us-east-1"}}
(1 row)
-- 7. p_properties 显式传入 NULL（等价于不传）
SELECT iceberg_catalog.create_namespace('nullable_props', NULL::JSONB);
                  create_namespace                   
-----------------------------------------------------
 {"namespace": ["nullable_props"], "properties": {}}
(1 row)
-- ============================================================================
-- 第二部分：参数校验 — 报错场景
-- ============================================================================
-- 8. p_namespace 为空字符串 → 报错 (P0001)
SAVEPOINT sp8;
SAVEPOINT
SELECT iceberg_catalog.create_namespace('', '{"key":"val"}'::JSONB);
gsql:test/sql/create_namespace.sql:58: ERROR:  namespace must not be empty
CONTEXT:  referenced column: create_namespace
ROLLBACK TO SAVEPOINT sp8;
ROLLBACK
-- 9. p_namespace 为 NULL → 报错 (P0001)
SAVEPOINT sp9;
SAVEPOINT
SELECT iceberg_catalog.create_namespace(NULL::TEXT, '{}'::JSONB);
gsql:test/sql/create_namespace.sql:63: ERROR:  namespace must not be empty
CONTEXT:  referenced column: create_namespace
ROLLBACK TO SAVEPOINT sp9;
ROLLBACK
-- 10. p_properties 为 JSONB string（非 object） → 报错 (P0001)
SAVEPOINT sp10;
SAVEPOINT
SELECT iceberg_catalog.create_namespace('ns', '"not_an_object"'::JSONB);
gsql:test/sql/create_namespace.sql:68: ERROR:  p_properties must be a JSONB object
CONTEXT:  referenced column: create_namespace
ROLLBACK TO SAVEPOINT sp10;
ROLLBACK
-- 11. p_properties 为 JSONB array（非 object） → 报错 (P0001)
SAVEPOINT sp11;
SAVEPOINT
SELECT iceberg_catalog.create_namespace('ns', '["array"]'::JSONB);
gsql:test/sql/create_namespace.sql:73: ERROR:  p_properties must be a JSONB object
CONTEXT:  referenced column: create_namespace
ROLLBACK TO SAVEPOINT sp11;
ROLLBACK
-- 12. p_properties 为 JSONB number（非 object） → 报错 (P0001)
SAVEPOINT sp12;
SAVEPOINT
SELECT iceberg_catalog.create_namespace('ns', '42'::JSONB);
gsql:test/sql/create_namespace.sql:78: ERROR:  p_properties must be a JSONB object
CONTEXT:  referenced column: create_namespace
ROLLBACK TO SAVEPOINT sp12;
ROLLBACK
-- ============================================================================
-- 第三部分：未实现的功能 — 报错场景 (Stub 阶段不触发，但预留)
-- ============================================================================
-- 13. 重复创建同一 namespace → 报错 (P0005)
SAVEPOINT sp13;
SAVEPOINT
SELECT iceberg_catalog.create_namespace('dup_ns');
              create_namespace               
---------------------------------------------
 {"namespace": ["dup_ns"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_namespace('dup_ns');  -- 第二次应报 P0005
gsql:test/sql/create_namespace.sql:88: ERROR:  create namespace schema: schema "dup_ns" already exists
CONTEXT:  referenced column: create_namespace
ROLLBACK TO SAVEPOINT sp13;
ROLLBACK
-- ============================================================================
-- 第四部分：边界场景
-- ============================================================================
-- 14. 命名空间名称为特殊字符（合法标识符）
SELECT iceberg_catalog.create_namespace('ns-with-dash');
                 create_namespace                  
---------------------------------------------------
 {"namespace": ["ns-with-dash"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_namespace('ns_with_underscore');
                    create_namespace                     
---------------------------------------------------------
 {"namespace": ["ns_with_underscore"], "properties": {}}
(1 row)
SELECT iceberg_catalog.create_namespace('NS123MixedCase');
                  create_namespace                   
-----------------------------------------------------
 {"namespace": ["NS123MixedCase"], "properties": {}}
(1 row)
-- 15. properties 中包含多层嵌套对象
SELECT iceberg_catalog.create_namespace(
    'nested_ns',
    '{"env":"prod","config":{"replicas":3,"tags":{"team":"platform","cost":"low"}}}'::JSONB
);
                                                          create_namespace                                                           
-------------------------------------------------------------------------------------------------------------------------------------
 {"namespace": ["nested_ns"], "properties": {"env": "prod", "config": {"tags": {"cost": "low", "team": "platform"}, "replicas": 3}}}
(1 row)
-- 16. properties 中包含数组
SELECT iceberg_catalog.create_namespace(
    'arr_ns',
    '{"owners":["alice","bob"],"regions":["us","eu"]}'::JSONB
);
                                        create_namespace                                        
------------------------------------------------------------------------------------------------
 {"namespace": ["arr_ns"], "properties": {"owners": ["alice", "bob"], "regions": ["us", "eu"]}}
(1 row)
-- ============================================================================
-- 第五部分：持久化验证
-- ============================================================================
-- 17. 验证 namespace 写入后可通过元数据表查询
SELECT namespace, properties->>'owner' AS owner
FROM iceberg_catalog.namespaces
WHERE catalog_name = current_database()::text
  AND namespace = 'accounting';
 namespace  | owner 
------------+-------
 accounting | Ralph
(1 row)
-- 18. 验证 create_namespace 创建了对应的 openGauss schema
SELECT count(*) = 1 AS schema_created
FROM pg_namespace
WHERE nspname = 'ns-with-dash';
 schema_created 
----------------
 t
(1 row)
SELECT count(*) = 1 AS schema_created
FROM pg_namespace
WHERE nspname = 'ns_with_underscore';
 schema_created 
----------------
 t
(1 row)
SELECT count(*) = 1 AS schema_created
FROM pg_namespace
WHERE nspname = 'NS123MixedCase';
 schema_created 
----------------
 t
(1 row)
ROLLBACK;
ROLLBACK
