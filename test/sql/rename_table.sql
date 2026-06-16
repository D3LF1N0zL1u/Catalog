-- ============================================================================
-- iceberg_catalog.rename_table 测试用例
-- ============================================================================

BEGIN;

-- TODO: 暴露 create_namespace 后，替换这里直接写 namespaces 的前置数据。
INSERT INTO iceberg_catalog.namespaces(catalog_name, namespace, properties)
VALUES
    (current_database(), 'rename_src_ns', '{}'::jsonb),
    (current_database(), 'rename_dst_ns', '{}'::jsonb),
    (current_database(), 'rename_same_ns', '{}'::jsonb),
    (current_database(), 'rename_conflict_ns', '{}'::jsonb);

SELECT iceberg_catalog.create_table(
    'rename_src_ns',
    'rename_src_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true},{"id":2,"name":"data","type":"string","required":false}]}'::JSONB,
    'file:///tmp/rename/src'
);

SELECT iceberg_catalog.create_table(
    'rename_same_ns',
    'old_name',
    '{"type":"struct","fields":[]}'::JSONB
);

SELECT iceberg_catalog.create_table(
    'rename_src_ns',
    'type_check_tbl',
    '{"type":"struct","fields":[]}'::JSONB
);

SELECT iceberg_catalog.create_table(
    'rename_conflict_ns',
    'rename_conflict_tbl',
    '{"type":"struct","fields":[{"id":1,"name":"id","type":"long","required":true}]}'::JSONB,
    'file:///tmp/rename/conflict'
);

-- 1. 基础调用：返回 {"success": true}
SELECT iceberg_catalog.rename_table(
    'rename_src_ns',
    'rename_src_tbl',
    'rename_dst_ns',
    'rename_dst_tbl'
) AS rename_result;

-- 2. 同 Namespace 内重命名
SELECT iceberg_catalog.rename_table(
    'rename_same_ns',
    'old_name',
    'rename_same_ns',
    'new_name'
) AS same_namespace_result;

-- 3. 验证返回 JSONB object
SELECT jsonb_typeof(iceberg_catalog.rename_table(
    'rename_src_ns',
    'type_check_tbl',
    'rename_dst_ns',
    'type_check_tbl_renamed'
)) AS result_type;

-- 4. p_src_ns 为空串 → 报错
SAVEPOINT sp4;
SELECT iceberg_catalog.rename_table('', 'rename_dst_tbl', 'rename_dst_ns', 'rename_dst_tbl_2');
ROLLBACK TO SAVEPOINT sp4;

-- 5. p_src_table 为空串 → 报错
SAVEPOINT sp5;
SELECT iceberg_catalog.rename_table('rename_dst_ns', '', 'rename_dst_ns', 'rename_dst_tbl_2');
ROLLBACK TO SAVEPOINT sp5;

-- 6. p_dst_ns 为空串 → 报错
SAVEPOINT sp6;
SELECT iceberg_catalog.rename_table('rename_dst_ns', 'rename_dst_tbl', '', 'rename_dst_tbl_2');
ROLLBACK TO SAVEPOINT sp6;

-- 7. p_dst_table 为空串 → 报错
SAVEPOINT sp7;
SELECT iceberg_catalog.rename_table('rename_dst_ns', 'rename_dst_tbl', 'rename_dst_ns', '');
ROLLBACK TO SAVEPOINT sp7;

-- 8. p_src_ns 为 NULL → 报错
SAVEPOINT sp8;
SELECT iceberg_catalog.rename_table(NULL, 'rename_dst_tbl', 'rename_dst_ns', 'rename_dst_tbl_2');
ROLLBACK TO SAVEPOINT sp8;

-- 9. 验证 rename 后元信息表只更新 namespace/table_name
SELECT namespace, table_name
FROM iceberg_catalog.tables_internal
WHERE namespace = 'rename_dst_ns'
  AND table_name = 'rename_dst_tbl';

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

SELECT count(*) = 2 AS schema_fields_preserved
FROM iceberg_catalog.table_schemas s
JOIN iceberg_catalog.tables_internal t
  ON s.table_uuid = t.table_uuid
WHERE t.namespace = 'rename_dst_ns'
  AND t.table_name = 'rename_dst_tbl';

SELECT count(*) = 1 AS partition_spec_preserved
FROM iceberg_catalog.partition_specs p
JOIN iceberg_catalog.tables_internal t
  ON p.table_uuid = t.table_uuid
WHERE t.namespace = 'rename_dst_ns'
  AND t.table_name = 'rename_dst_tbl';

SELECT count(*) AS old_name_count
FROM iceberg_catalog.tables_internal
WHERE namespace = 'rename_src_ns'
  AND table_name = 'rename_src_tbl';

-- 10. 源表不存在 → 报错
SAVEPOINT sp10;
SELECT iceberg_catalog.rename_table(
    'rename_src_ns',
    'rename_src_tbl',
    'rename_dst_ns',
    'rename_dst_tbl_2'
);
ROLLBACK TO SAVEPOINT sp10;

-- 11. 目标 Namespace 不存在 → 报错
SAVEPOINT sp11;
SELECT iceberg_catalog.rename_table(
    'rename_dst_ns',
    'rename_dst_tbl',
    'rename_missing_ns',
    'rename_dst_tbl_2'
);
ROLLBACK TO SAVEPOINT sp11;

-- 12. 目标表已存在 → 报错
SAVEPOINT sp12;
SELECT iceberg_catalog.rename_table(
    'rename_dst_ns',
    'rename_dst_tbl',
    'rename_conflict_ns',
    'rename_conflict_tbl'
);
ROLLBACK TO SAVEPOINT sp12;

ROLLBACK;
