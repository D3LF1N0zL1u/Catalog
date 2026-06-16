/*-------------------------------------------------------------------------
 *
 * metadata.h
 *    Metadata table accessors for the iceberg_catalog extension.
 *
 * This module provides the low-level SPI-based CRUD operations on the
 * Iceberg metadata tables (tables_internal, table_schemas, partition_specs).
 * Higher-level SQL functions (e.g. create_table) call these functions
 * rather than constructing SQL themselves.
 *
 *-------------------------------------------------------------------------
 */

#ifndef ICEBERG_CATALOG_METADATA_H
#define ICEBERG_CATALOG_METADATA_H

#include "postgres.h"

/*
 * MetaTableInfo -- fields that map to columns in iceberg_catalog.tables_internal.
 *
 * Boolean "has_" flags distinguish between "field is 0 / false"
 * and "field was not provided" (i.e. NULL in the database).
 */
typedef struct MetaTableInfo {
    Oid     relid;                         /* OID of the backing storage relation */
    char   *namespace_name;                /* Iceberg namespace (logical schema) */
    char   *table_name;                    /* Iceberg table name */
    char   *table_uuid;                    /* UUID assigned to this table */
    char   *metadata_location;             /* path/URL to v<N>.metadata.json */
    char   *previous_metadata_location;    /* prior metadata location (NULL for new tables) */
    char   *table_location;                /* Iceberg table root path */
    int     last_column_id;                /* highest column id assigned in the schema */
    int     current_schema_id;             /* ID of the current schema */
    bool    has_current_schema_id;         /* false if current_schema_id is not set */
    int64_t current_snapshot_id;           /* ID of the current snapshot */
    bool    has_current_snapshot_id;       /* false if no snapshot exists yet */
    int     default_spec_id;               /* ID of the default partition spec */
    bool    has_default_spec_id;           /* false if default_spec_id is not set */
} MetaTableInfo;

/*
 * MetaRegisterTableInput -- aggregate input for iceberg_meta_register_table().
 *
 * Combines the table head record (MetaTableInfo) with the schema and
 * partition-spec data that are expanded into the dependent tables.
 */
typedef struct MetaRegisterTableInput {
    MetaTableInfo table_info;              /* table head record fields */
    const char   *schema_json;             /* Iceberg struct schema as JSON */
    const char   *partition_fields_json;   /* partition spec fields as JSON */
    int           schema_id;               /* schema version identifier */
    int           spec_id;                 /* partition spec version identifier */
} MetaRegisterTableInput;

/*
 * Check whether an Iceberg namespace exists in the local catalog.
 * Returns true if a row with matching catalog_name and namespace is found.
 */
bool iceberg_meta_namespace_exists(const char *namespace_name);

/*
 * Check whether a table already exists within the given namespace.
 * Both namespace_name and table_name are required (non-empty).
 */
bool iceberg_meta_table_exists(const char *namespace_name, const char *table_name);

/*
 * Read table metadata from the local internal catalog.
 * Returns NULL when the table does not exist.
 */
MetaTableInfo *iceberg_meta_get_table(const char *namespace_name, const char *table_name);

/*
 * Register a new Iceberg table in the local metadata tables.
 *
 * Within a single SPI transaction this function:
 *  1. Locks the namespace row for share (prevents concurrent creation races).
 *  2. Inserts the table head record into tables_internal.
 *  3. Expands the schema JSON into table_schemas.
 *  4. Expands the partition spec JSON into partition_specs.
 *
 * The caller is responsible for ensuring the namespace exists and the
 * table name is not already taken.
 */
void iceberg_meta_register_table(const char *namespace_name,
                                 const char *table_name,
                                 const MetaRegisterTableInput *input);

/*
 * Delete a table from the local metadata tables (service wrapper).
 *
 * Connects SPI, deletes the table head row from tables_internal, and
 * relies on ON DELETE CASCADE for dependent rows.
 */
void iceberg_meta_drop_table_record(const char *namespace_name,
                                     const char *table_name);

/*
 * Rename a table in the local metadata tables (service wrapper).
 *
 * Connects SPI, validates preconditions (source exists, destination does not),
 * performs the rename via UPDATE, and finishes SPI.  Errors are translated
 * via the internal throw_translated_spi_error pattern.
 */
void iceberg_meta_rename_table_record(const char *src_ns, const char *src_table,
                                      const char *dst_ns, const char *dst_table);

/*
 * Free a MetaTableInfo structure and all of its palloc'd string members.
 * Safe to call with NULL (no-op).
 */
void iceberg_meta_free_table_info(MetaTableInfo *info);

/*
 * Create a namespace in the local catalog.
 *
 * Validates the namespace name and properties JSON, then inserts a row
 * into iceberg_catalog.namespaces.  Raises ERRCODE_DUPLICATE_OBJECT if
 * the namespace already exists.
 */
void iceberg_meta_create_namespace(const char *namespace_name,
                                    const char *properties_json);

/*
 * MetaCommitTableInput -- input for iceberg_meta_commit_table().
 *
 * Carries the metadata changes produced by the SDK CommitTable operation:
 * a new metadata pointer and an optional snapshot summary row.
 */
typedef struct MetaCommitTableInput {
    const char *namespace_name;
    const char *table_name;
    const char *table_uuid;
    const char *old_metadata_location;
    const char *new_metadata_location;
    int64_t     new_snapshot_id;
    int         snapshot_schema_id;
    bool        has_snapshot_schema_id;
    int64_t     snapshot_timestamp_ms;
    const char *manifest_list;
    int64_t     total_records;
    bool        has_total_records;
} MetaCommitTableInput;

/*
 * MetaCommitSchemaChangeInput -- input for iceberg_meta_commit_schema_change().
 *
 * Carries the metadata changes produced by the SDK AddColumn operation:
 * a new metadata pointer, a new schema id, and the schema definition JSON.
 */
typedef struct MetaCommitSchemaChangeInput {
    const char *namespace_name;
    const char *table_name;
    const char *table_uuid;
    const char *old_metadata_location;
    const char *new_metadata_location;
    int         new_schema_id;
    const char *schema_json;
    int         new_last_column_id;
} MetaCommitSchemaChangeInput;

/*
 * Lock a table row for write-path operations (SELECT ... FOR UPDATE).
 * Returns a palloc'd MetaTableInfo; caller must free via iceberg_meta_free_table_info.
 * Returns NULL if the table does not exist.
 * Internal function; does not manage SPI.
 */
MetaTableInfo* iceberg_meta_get_table_for_update(const char *namespace_name,
                                                  const char *table_name);

/*
 * Lock a table row for write-path operations (service wrapper).
 * Connects SPI, acquires a FOR UPDATE lock, and returns the table metadata.
 * Raises UNDEFINED_OBJECT if the table does not exist.
 */
MetaTableInfo* iceberg_meta_lock_table(const char *namespace_name,
                                        const char *table_name);

/*
 * Update table metadata pointers and optional summary fields with optimistic locking.
 * Uses CAS: WHERE metadata_location = old AND table_uuid check.
 * Internal function; does not manage SPI.
 */
void iceberg_meta_update_table(const char *ns, const char *tbl, const char *uuid,
                                const char *old_meta, const char *new_meta,
                                int64_t new_snap_id, bool has_new_snap,
                                int new_schema_id, bool has_new_schema,
                                int new_last_col_id, bool has_new_last_col,
                                int new_def_spec_id, bool has_new_def_spec);

/*
 * Insert a snapshot summary row into iceberg_catalog.snapshots.
 * Internal function; does not manage SPI.
 */
void iceberg_meta_insert_snapshot(const char *table_uuid, int64_t snapshot_id,
                                   int schema_id, bool has_schema_id,
                                   int64_t timestamp_ms, const char *manifest_list,
                                   int64_t total_records, bool has_total_records);

/*
 * Scene-level commit: update table pointer + insert snapshot cache.
 * This is the primary entry-point for commit_table.
 */
void iceberg_meta_commit_table(const MetaCommitTableInput *input);

/*
 * Scene-level schema change commit: update table pointer + insert schema cache.
 * This is the primary entry-point for add_column.
 */
void iceberg_meta_commit_schema_change(const MetaCommitSchemaChangeInput *input);

#endif /* ICEBERG_CATALOG_METADATA_H */
