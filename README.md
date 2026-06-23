# iceberg_catalog

Iceberg catalog extension for openGauss.

## 依赖

- **[iceberg_fdw](https://github.com/DataInfraLab/iceberg_fdw)**：openGauss FDW 扩展，负责 Iceberg 外表创建和全表扫描。

  ```bash
  git clone https://github.com/DataInfraLab/iceberg_fdw.git
  cd iceberg_fdw
  make && make install
  gsql -c "CREATE EXTENSION iceberg_fdw;"
  ```

- **[Rust bridge SDK](https://github.com/DataInfraLab/iceberg-rust-bridge)**：Iceberg REST catalog 和文件 IO 的 C ABI 实现。

  ```bash
  git clone https://github.com/DataInfraLab/iceberg-rust-bridge.git
  cd iceberg-rust-bridge
  cargo build --release
  cp target/release/libiceberg_rust_bridge.so /path/to/Catalog/deps/
  cp include/iceberg_bridge.h /path/to/Catalog/deps/
  ```

  本仓库下新建 `deps/` 目录，并包含编译产物：

```
deps/
├── iceberg_bridge.h           # C ABI 头文件
└── libiceberg_rust_bridge.so  # Rust bridge 动态库
```

Makefile 会自动链接 `-L$(srcdir)/deps -liceberg_rust_bridge`。

## 编译

```bash
GAUSS_SRC=/path/to/openGauss-server make && make install
```

## 测试

确保数据库已启动（需要 `ICEBERG_WAREHOUSE=file:///tmp/iceberg_warehouse`）：

```bash
make test
```

## 环境变量

### 必需

| 变量 | 说明 | 示例 |
|---|---|---|
| `ICEBERG_WAREHOUSE` | 数据仓库根路径，支持 `s3://` 和 `file://` 两种 scheme | `s3://iceberg-bucket` 或 `file:///tmp/iceberg_warehouse` |

### 按 scheme 可选

当 `ICEBERG_WAREHOUSE` 以 `s3://` 开头时，还需设置以下变量：

| 变量 | 说明 | 示例 |
|---|---|---|
| `ICEBERG_S3_ENDPOINT` | S3 / MinIO API 地址 | `http://localhost:9000` |
| `ICEBERG_S3_ACCESS_KEY` | S3 Access Key | `minioadmin` |
| `ICEBERG_S3_SECRET_KEY` | S3 Secret Key | `minioadmin` |
| `ICEBERG_S3_REGION` | S3 Region | `us-east-1` |

以 `file://` 开头时无需额外变量，元数据直接写入本地文件系统。

> **注意**：`open_iceberg_storage()` 按 warehouse 前缀自动选择存储后端，`s3://` 走 S3，`file://` 走本地文件系统。
