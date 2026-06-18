# FDW 集成设计

## 1. 依赖

需要 `iceberg_fdw` 扩展。

```bash
git clone https://github.com/DataInfraLab/iceberg_fdw ../iceberg_fdw
cd ../iceberg_fdw
make && make install
```

安装后在数据库中执行 `CREATE EXTENSION iceberg_fdw`。

## 2. 目标

`iceberg_catalog.create_table()` 调用时自动创建 openGauss 外表，让用户无需手动执行 `CREATE FOREIGN TABLE`。

## 3. 架构

```
create_table()
├── section 6:  SDK CreateTable → 写入 Iceberg 元数据（S3/MinIO）
├── section 7.1: delta-table hook（可选，内部表插件）
├── section 7.2: fdw_util → SPI 执行 CREATE FOREIGN TABLE
│     └── iceberg_fdw ProcessUtility hook → 创建 PG 外表对象
└── section 8:  META → 写 iceberg_catalog.tables_internal
```

## 3. fdw_util 模块

`src/fdw_util.cpp` — 通过 SPI 执行 `CREATE FOREIGN TABLE`，触发 `iceberg_fdw` 的 hook。

### 3.1 流程

1. 查找或自动创建 `iceberg_catalog_server`：

```sql
CREATE SERVER "iceberg_catalog_server" FOREIGN DATA WRAPPER iceberg_fdw
  OPTIONS (warehouse 's3://iceberg-bucket')
```

   warehouse 优先 `ICEBERG_WAREHOUSE`，fallback `file:///tmp/iceberg_warehouse`
2. 用 jsonb 函数解析 Iceberg schema → 提取字段名和类型
3. Iceberg 类型映射为 SQL 类型
4. 构造并执行：

```sql
CREATE FOREIGN TABLE "t1" (
    "id" integer,
    "name" text
) SERVER "iceberg_catalog_server"
  OPTIONS (namespace 'ns', table_name 't1')
```

5. 返回外表 OID，section 8 使用该 OID 写入元数据

### 3.2 类型映射

| Iceberg | SQL |
|---|---|
| boolean | boolean |
| int | integer |
| long | bigint |
| float | real |
| double | double precision |
| decimal / decimal(P,S) | numeric |
| date | date |
| time | time |
| timestamp | timestamp |
| timestamptz | timestamptz |
| string | text |
| uuid | uuid |
| binary / fixed(L) | bytea |
| list / map / struct | text（placeholder） |
