-- ============================================================================
-- iceberg_catalog.list_namespaces 测试用例
--
-- 前置条件：iceberg_catalog 扩展已安装
-- ============================================================================

BEGIN;

-- ============================================================================
-- 第一部分：正常场景 — 返回类型与结构校验
-- ============================================================================

-- 1. 默认参数调用，返回合法 JSONB
SELECT jsonb_typeof(iceberg_catalog.list_namespaces()) AS result_type;

-- 2. 返回结构包含 "namespaces" 和 "next-page-token" 两个顶层 key
SELECT
    iceberg_catalog.list_namespaces() ? 'namespaces'       AS has_namespaces,
    iceberg_catalog.list_namespaces() ? 'next-page-token'  AS has_next_page_token;

-- 3. "namespaces" 字段应为数组
SELECT jsonb_typeof(iceberg_catalog.list_namespaces() -> 'namespaces') AS namespaces_type;

-- 4. 首页 next-page-token 存在（空 catalog 返回 null）
SELECT iceberg_catalog.list_namespaces() -> 'next-page-token' AS next_token;

-- ============================================================================
-- 第二部分：参数组合
-- ============================================================================

-- 5. 指定 p_parent = NULL（列出顶层 namespace，默认行为）
SELECT iceberg_catalog.list_namespaces(p_parent => NULL);

-- 6. 指定 p_page_size
SELECT iceberg_catalog.list_namespaces(p_page_size => 50);

-- 7. 使用位置参数
SELECT iceberg_catalog.list_namespaces(NULL, 100, NULL);

-- 8. 指定 p_page_token（分页）
SELECT iceberg_catalog.list_namespaces(
    p_page_token => 'eyJ2IjoxLCJ0eXBlIjoibmFtZXNwYWNlIiwibGFzdCI6ImFjY291bnRpbmcifQ=='
);

-- 9. 全部参数使用命名传参
INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES (current_database(), 'accounting', '{}'::JSONB);

SELECT iceberg_catalog.list_namespaces(
    p_parent     => 'accounting',
    p_page_size  => 20,
    p_page_token => NULL
);

-- ============================================================================
-- 第三部分：参数校验 — 报错场景
-- ============================================================================

-- 10. p_page_size = 0 → 报错 (P0001)
SAVEPOINT sp10;
SELECT iceberg_catalog.list_namespaces(p_page_size => 0);
ROLLBACK TO SAVEPOINT sp10;

-- 11. p_page_size = -1 → 报错 (P0001)
SAVEPOINT sp11;
SELECT iceberg_catalog.list_namespaces(p_page_size => -1);
ROLLBACK TO SAVEPOINT sp11;

-- ============================================================================
-- 第四部分：Parent namespace 不存在 — 报错场景
-- ============================================================================

-- 12. p_parent 指定的父级 Namespace 不存在 → 报错 (P0004)
SAVEPOINT sp12;
SELECT iceberg_catalog.list_namespaces(p_parent => 'non_existent_parent');
ROLLBACK TO SAVEPOINT sp12;

-- ============================================================================
-- 第五部分：边界场景
-- ============================================================================

-- 13. p_page_size 为大值
SELECT iceberg_catalog.list_namespaces(p_page_size => 1000000) @>
       '{"namespaces":[["accounting"]]}'::JSONB AS contains_accounting;

-- 14. p_page_size = 1（最小值合法）
SELECT iceberg_catalog.list_namespaces(p_page_size => 1) -> 'namespaces' =
       '[["accounting"]]'::JSONB AS first_page_is_accounting;

-- 15. 插入 namespace 后调用 list，应包含已插入的 namespace
INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES (current_database(), 'dept_a', '{}'::JSONB);

INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES (current_database(), 'dept_b', '{"owner": "alice"}'::JSONB);

SELECT iceberg_catalog.list_namespaces() @>
       '{"namespaces":[["accounting"],["dept_a"],["dept_b"]]}'::JSONB AS contains_inserted_namespaces;

WITH first_page AS (
    SELECT iceberg_catalog.list_namespaces(NULL, 2, NULL) AS result
)
SELECT
    jsonb_array_length(result -> 'namespaces') AS namespace_count,
    jsonb_typeof(result -> 'next-page-token') AS next_token_type
FROM first_page;

WITH first_page AS (
    SELECT iceberg_catalog.list_namespaces(NULL, 2, NULL) AS result
)
SELECT iceberg_catalog.list_namespaces(
    NULL,
    2,
    result ->> 'next-page-token'
) @> '{"namespaces":[["dept_b"]]}'::JSONB AS second_page_contains_dept_b
FROM first_page;

ROLLBACK;
