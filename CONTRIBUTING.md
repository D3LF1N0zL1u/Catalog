# openGauss 插件开发规范

本文档定义 openGauss 插件项目的开发规范，用于指导 Agent 进行代码生成和项目维护。

---

## 1. 项目结构规范

### 1.1 标准目录布局

```
gv_catalog/
├── CLAUDE.md              # Claude AI 行为准则
├── CONTRIBUTING.md        # 本文档 - 开发规范
├── README.md              # 项目说明文档
├── Makefile               # 编译构建入口
├── {plugin_name}.control  # 扩展控制文件
├── {plugin_name}--{version}.sql  # SQL 脚本
├── design/                # 需求与设计文档
│   ├── {feature}_req.md   # 需求文档
│   └── {feature}_design.md # 设计文档
├── sql/                   # SQL 源文件
│   ├── {plugin_name}.sql.in
│   └── upgrades/          # 版本升级脚本
├── src/                   # C/C++ 源代码
│   ├── include/           # 头文件
│   │   └── {plugin_name}.h
│   └── {plugin_name}.c    # 主实现文件
├── test/                  # 测试文件
│   ├── sql/               # SQL 测试用例
│   └── expected/          # 预期输出
├── doc/                   # 用户文档
└── deps/                  # 第三方依赖
```

### 1.2 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 插件名 | 小写，下划线分隔 | `gv_catalog` |
| C 文件 | 与插件名一致 | `gv_catalog.c` |
| 头文件 | 与插件名一致 | `gv_catalog.h` |
| 函数名 | 插件名前缀 + 下划线 | `gv_catalog_init()` |
| 数据类型 | 插件名前缀 + 驼峰 | `GvCatalogEntry` |
| 宏定义 | 全大写，下划线分隔 | `GV_CATALOG_MAX_SIZE` |
| SQL 对象 | 插件名前缀 | `gv_catalog_query()` |

---

## 2. C/C++ 编码规范

### 2.1 代码风格

```c
/* 文件头注释 */
/*-------------------------------------------------------------------------
 *
 * gv_catalog.c
 *    简要描述插件功能
 *
 * Copyright (c) 2024, 作者/组织
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"

/* 必须放在 include 之后 */
PG_MODULE_MAGIC;

/* 宏定义 - 全大写下划线 */
#define GV_CATALOG_VERSION     "1.0.0"
#define GV_CATALOG_MAX_ENTRIES 1024

/* 类型定义 - 插件名前缀 + 驼峰 */
typedef struct GvCatalogEntry
{
    int32       id;
    char        name[NAMEDATALEN];
    Timestamp   created_at;
} GvCatalogEntry;

/* 内部函数 - static 声明 */
static void gv_catalog_init(void);
static int  gv_catalog_compare(const void *a, const void *b);

/* PG 函数声明 */
PG_FUNCTION_INFO_V1(gv_catalog_create);
PG_FUNCTION_INFO_V1(gv_catalog_query);
```

### 2.2 PostgreSQL/openGauss 函数定义

```c
/*
 * gv_catalog_create - 创建目录条目
 *
 * 参数:
 *   name: 条目名称
 *   description: 条目描述（可选）
 *
 * 返回: 新创建条目的 ID
 */
Datum
gv_catalog_create(PG_FUNCTION_ARGS)
{
    text       *name;
    char       *name_str;
    int32       result_id;

    /* 参数检查 */
    if (PG_ARGISNULL(0))
        ereport(ERROR,
                (errcode(ERRCODE_NULL_VALUE_NOT_ALLOWED),
                 errmsg("name cannot be NULL")));

    name = PG_GETARG_TEXT_PP(0);
    name_str = text_to_cstring(name);

    /* 业务逻辑 */
    result_id = create_catalog_entry(name_str);

    /* 内存释放 */
    pfree(name_str);

    PG_RETURN_INT32(result_id);
}
```

### 2.3 错误处理规范

```c
/* 使用 ereport 报告错误 */
ereport(ERROR,
        (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
         errmsg("invalid parameter value"),
         errdetail("Expected positive integer, got %d", value)));

/* 警告信息 */
ereport(WARNING,
        (errmsg("deprecated function called")));

/* 日志信息 */
elog(LOG, "processing entry %d", entry_id);
elog(DEBUG1, "detailed debug info: %s", debug_str);
```

### 2.4 内存管理

```c
/* 在合适的上下文中分配内存 */
MemoryContext oldcontext = MemoryContextSwitchTo(MyMemoryContext);
void *ptr = palloc(size);
MemoryContextSwitchTo(oldcontext);

/* 使用 pfree 释放 */
pfree(ptr);

/* 重置整个上下文 */
MemoryContextReset(MyMemoryContext);
```

---

## 3. SQL 编码规范

### 3.1 对象创建

```sql
-- 扩展控制文件: gv_catalog.control
comment = 'GV Catalog extension for openGauss'
default_version = '1.0.0'
module_pathname = '$libdir/gv_catalog'
relocatable = false

-- SQL 脚本: gv_catalog--1.0.0.sql
-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION gv_catalog" to load this file. \quit

-- 创建 Schema（可选）
CREATE SCHEMA IF NOT EXISTS gv_catalog;

-- 设置搜索路径
SET search_path = gv_catalog, pg_catalog;

-- 创建类型
CREATE TYPE gv_catalog.entry AS (
    id          integer,
    name        text,
    created_at  timestamp
);

-- 创建函数
CREATE OR REPLACE FUNCTION gv_catalog.create_entry(
    name        text,
    description text DEFAULT NULL
) RETURNS integer
AS 'MODULE_PATHNAME', 'gv_catalog_create'
LANGUAGE C STRICT;

-- 创建操作符
CREATE OPERATOR gv_catalog.-> (
    LEFTARG = integer,
    RIGHTARG = text,
    FUNCTION = gv_catalog.create_entry
);

-- 重置搜索路径
RESET search_path;
```

### 3.2 注释规范

```sql
-- 单行注释用于简短说明

/*
 * 多行注释用于
 * 详细说明复杂逻辑
 */

-- 为对象添加 COMMENT
COMMENT ON FUNCTION gv_catalog.create_entry(text, text) IS
'Creates a new catalog entry with the given name and optional description.';

COMMENT ON TYPE gv_catalog.entry IS
'Represents a single entry in the GV catalog system.';
```

---

## 4. 构建系统规范

### 4.1 Makefile 模板

```makefile
# Makefile for openGauss extension

MODULES = gv_catalog
EXTENSION = gv_catalog
DATA = gv_catalog--1.0.0.sql
DATA_built = 
REGRESS = gv_catalog_test

# openGauss/PostgreSQL 配置
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# 自定义编译选项
CFLAGS += -Wall -Werror -std=c99
CPPFLAGS += -I./src/include

# 源文件
SRCS = src/gv_catalog.c
OBJS = $(SRCS:.c=.o)

# 额外清理
EXTRA_CLEAN = $(OBJS)

# 默认目标
all: $(OBJS)

# 安装
install: all install-data
	$(INSTALL_SHLIB) $(OBJS) '$(DESTDIR)$(pkglibdir)'

# 测试
check: regress
regress:
	$(pg_regress_check) $(REGRESS_OPTS) $(REGRESS)
```

### 4.2 编译命令

```bash
# 编译
make

# 安装
make install

# 测试
make check

# 清理
make clean

# 完整构建
make clean && make && make install && make check
```

---

## 5. 测试规范

### 5.1 SQL 测试文件

```sql
-- test/sql/gv_catalog_test.sql

-- 测试环境设置
SET client_min_messages TO warning;

-- 测试 1: 基本创建
SELECT gv_catalog.create_entry('test_entry');

-- 测试 2: 查询验证
SELECT * FROM gv_catalog.entries WHERE name = 'test_entry';

-- 测试 3: 边界情况
SELECT gv_catalog.create_entry(NULL);  -- 应该报错

-- 测试 4: 性能基准
EXPLAIN ANALYZE SELECT * FROM gv_catalog.entries;

-- 清理
DROP EXTENSION gv_catalog CASCADE;
```

### 5.2 预期输出文件

```
-- test/expected/gv_catalog_test.out

SET client_min_messages TO warning;
SET
SELECT gv_catalog.create_entry('test_entry');
 create_entry
--------------
            1
(1 row)

SELECT * FROM gv_catalog.entries WHERE name = 'test_entry';
 id |    name    |         created_at
----+------------+----------------------------
  1 | test_entry | 2024-01-15 10:30:00.123456
(1 row)

SELECT gv_catalog.create_entry(NULL);
ERROR:  name cannot be NULL
```

---

## 6. 文档规范

### 6.1 README.md 结构

```markdown
# gv_catalog

## 简介
简要描述插件功能和用途。

## 安装
安装步骤说明。

## 使用方法
基本使用示例。

## API 文档
详细的函数和类型说明。

## 构建
编译和安装说明。

## 测试
测试运行说明。

## 许可证
许可证信息。
```

### 6.2 代码注释要求

- 每个公开函数必须有注释说明
- 复杂算法必须添加逻辑说明
- 关键数据结构必须有字段说明
- 非显而易见的代码需要行内注释

---

## 7. Agent 开发指导原则

### 7.1 任务执行流程

```
1. 理解需求 → 确认理解正确
2. 分析现有代码 → 确认风格一致
3. 设计方案 → 确认方案合理
4. 实现代码 → 最小化变更
5. 编写测试 → 验证功能正确
6. 更新文档 → 保持同步
```

### 7.2 代码生成检查清单

- [ ] 遵循命名规范
- [ ] 添加必要的错误处理
- [ ] 内存分配后有对应释放
- [ ] SQL 注释和 COMMENT 完整
- [ ] 测试用例覆盖关键场景
- [ ] 文档与代码同步更新

### 7.3 禁止事项

- 不修改不相关的代码
- 不添加未请求的功能
- 不引入不必要的依赖
- 不使用已废弃的 API
- 不忽略编译警告

---

## 8. Git 提交规范

### 8.1 提交消息格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 8.2 Type 类型说明

| Type | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat(query): add range query support` |
| `fix` | Bug 修复 | `fix(memory): correct palloc size calculation` |
| `docs` | 文档更新 | `docs(readme): update installation guide` |
| `style` | 代码格式（不影响逻辑） | `style(src): fix indentation` |
| `refactor` | 重构（不新增功能或修复） | `refactor(parser): simplify expression parsing` |
| `perf` | 性能优化 | `perf(index): improve search speed by 20%` |
| `test` | 测试相关 | `test(sql): add edge case tests for create_entry` |
| `chore` | 构建/工具变动 | `chore(makefile): add debug build target` |
| `revert` | 回滚提交 | `revert: feat(query): add range query support` |

### 8.3 Scope 范围说明

| Scope | 说明 |
|-------|------|
| `src` | C/C++ 源代码 |
| `sql` | SQL 脚本 |
| `test` | 测试文件 |
| `docs` | 文档 |
| `build` | 构建系统 |
| `design` | 设计文档 |
| `*` | 多个范围 |

### 8.4 提交消息示例

**简单提交：**
```
fix(src): handle NULL pointer in entry validation
```

**详细提交：**
```
feat(sql): add batch insert function for catalog entries

Add gv_catalog.batch_insert() function to support inserting
multiple entries in a single transaction for better performance.

- Add batch_insert() SQL function definition
- Implement gv_catalog_batch_insert() in C
- Add memory context management for batch operations
- Add test cases for batch insert

Closes #123
```

**破坏性变更：**
```
refactor(src)!: change entry ID type from int32 to int64

BREAKING CHANGE: The entry ID type is changed from integer to bigint.
Existing queries using integer type may need to be updated.

Migration: Run the upgrade script sql/upgrades/1.0.0--1.1.0.sql
```

### 8.5 提交最佳实践

**每个提交应该：**
- 只做一件事，保持原子性
- 包含清晰的标题（50 字符以内）
- 标题使用祈使语气
- 解释"为什么"而不仅是"做了什么"
- 关联相关的 Issue 或 PR

**避免：**
- ❌ `fix: fix bug`
- ❌ `update code`
- ❌ `WIP`
- ❌ 包含多个不相关改动
- ❌ 提交无法编译的代码

### 8.6 分支命名规范

| 分支类型 | 命名格式 | 示例 |
|----------|----------|------|
| 功能开发 | `feat/<feature-name>` | `feat/batch-insert` |
| Bug 修复 | `fix/<bug-description>` | `fix/null-pointer-crash` |
| 发布分支 | `release/<version>` | `release/1.0.0` |
| 热修复 | `hotfix/<version>-<description>` | `hotfix/1.0.1-memory-leak` |

---

## 9. 版本兼容性

### 9.1 支持的 openGauss 版本

- openGauss 3.0+
- openGauss 5.0+

### 9.2 版本升级脚本

```sql
-- gv_catalog--1.0.0--1.1.0.sql

-- 添加新字段
ALTER TABLE gv_catalog.entries ADD COLUMN description text;

-- 添加新函数
CREATE FUNCTION gv_catalog.update_description(integer, text)
RETURNS void AS 'MODULE_PATHNAME'
LANGUAGE C;

-- 记录版本
COMMENT ON EXTENSION gv_catalog IS 'GV Catalog extension, version 1.1.0';
```

---

## 附录 A: 常用宏和函数

```c
/* 参数获取 */
PG_GETARG_INT32(n)
PG_GETARG_TEXT_PP(n)
PG_GETARG_VARCHAR_PP(n)
PG_GETARG_BYTEA_PP(n)

/* 返回值 */
PG_RETURN_INT32(val)
PG_RETURN_TEXT_P(val)
PG_RETURN_NULL()

/* NULL 检查 */
PG_ARGISNULL(n)
PG_RETURN_NULL_IF_NULL()

/* 文本操作 */
text_to_cstring(text *)
cstring_to_text(char *)
```

## 附录 B: 调试技巧

```c
/* 调试输出 */
elog(DEBUG1, "variable x = %d", x);

/* 断言 */
Assert(ptr != NULL);

/* 内存上下文调试 */
MemoryContextStats(TopMemoryContext);
```

## 附录 C: 参考资源

- [openGauss 官方文档](https://opengauss.org/zh/)
- [PostgreSQL 扩展开发指南](https://www.postgresql.org/docs/current/extend.html)
- [PostgreSQL 源码](https://www.postgresql.org/docs/current/backend.html)