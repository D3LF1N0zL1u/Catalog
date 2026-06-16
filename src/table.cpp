/*-------------------------------------------------------------------------
 *
 * table.cpp
 *    Iceberg table SQL function implementations.
 *
 * Stub implementation: all openGauss catalog metadata-table operations
 * and Iceberg SDK calls are marked as TODO, pending the underlying
 * modules to be wired up. Currently returns a minimal response.
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
#include "utils/jsonb.h"

#include <stdlib.h>
#include <string.h>

#include "errors.h"
#include "iceberg_catalog.h"
#include "metadata.h"
#include "table.h"


static char *
jsonb_to_cstring(Jsonb *value)
{
    return DatumGetCString(DirectFunctionCall1(jsonb_out, PointerGetDatum(value)));
}

static int
temporary_last_column_id(const char *schema_json)
{
    const char *cursor = schema_json;
    int max_id = 0;

    /*
     * Temporary bridge until SDK schema parsing is wired in.  The metadata
     * layer still validates the full schema JSON before writing cache rows.
     */
    while ((cursor = strstr(cursor, "\"id\"")) != NULL) {
        const char *colon = strchr(cursor, ':');
        long value;

        if (colon == NULL)
            break;
        colon++;
        while (*colon == ' ' || *colon == '\t')
            colon++;
        value = strtol(colon, NULL, 10);
        if (value > max_id)
            max_id = (int) value;
        cursor = colon;
    }

    return max_id;
}


/* ---- create_table ---- */

PG_FUNCTION_INFO_V1(iceberg_create_table);

Datum
iceberg_create_table(PG_FUNCTION_ARGS)
{
    /*-------------------------------------------------------------------------
     * Parameters:
     *   1. p_namespace       TEXT     (required)
     *   2. p_table_name      TEXT     (required)
     *   3. p_schema          JSONB    (required)
     *   4. p_location        TEXT     (optional, default NULL)
     *   5. p_partition_spec  JSONB    (optional, default NULL)
     *   6. p_write_order     JSONB    (optional, default NULL)
     *   7. p_stage_create    BOOLEAN  (optional, default FALSE)
     *   8. p_properties      JSONB    (optional, default NULL)
     *
     * Returns: JSONB (LoadTableResult)
     *-------------------------------------------------------------------------
     */

    /* 1. Extract parameters from PG_FUNCTION_ARGS */

    if (PG_NARGS() < 3)
        elog(ERROR, "iceberg_create_table: expected at least 3 arguments, got %d", PG_NARGS());

    /* p_namespace (required) */
    char *p_namespace = NULL;
    if (!PG_ARGISNULL(0))
        p_namespace = text_to_cstring(PG_GETARG_TEXT_P(0));

    /* p_table_name (required) */
    char *p_table_name = NULL;
    if (!PG_ARGISNULL(1))
        p_table_name = text_to_cstring(PG_GETARG_TEXT_P(1));

    /* p_schema (required) */
    Jsonb *p_schema = NULL;
    if (!PG_ARGISNULL(2))
        p_schema = DatumGetJsonb(PG_GETARG_DATUM(2));

    /* p_location (optional, default NULL) */
    char *p_location = NULL;
    if (PG_NARGS() > 3 && !PG_ARGISNULL(3))
        p_location = text_to_cstring(PG_GETARG_TEXT_P(3));

    /* p_partition_spec (optional, default NULL) */
    Jsonb *p_partition_spec = NULL;
    if (PG_NARGS() > 4 && !PG_ARGISNULL(4))
        p_partition_spec = DatumGetJsonb(PG_GETARG_DATUM(4));

    /* p_write_order (optional, default NULL) */
    Jsonb *p_write_order = NULL;
    if (PG_NARGS() > 5 && !PG_ARGISNULL(5))
        p_write_order = DatumGetJsonb(PG_GETARG_DATUM(5));

    /* p_stage_create (optional, default FALSE) */
    bool p_stage_create = false;
    if (PG_NARGS() > 6 && !PG_ARGISNULL(6))
        p_stage_create = PG_GETARG_BOOL(6);

    /* p_properties (optional, default NULL) */
    Jsonb *p_properties = NULL;
    if (PG_NARGS() > 7 && !PG_ARGISNULL(7))
        p_properties = DatumGetJsonb(PG_GETARG_DATUM(7));

    /* 2. Validate required parameters */

    if (p_namespace == NULL || strlen(p_namespace) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_namespace is required and must not be empty")));

    if (p_table_name == NULL || strlen(p_table_name) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_table_name is required and must not be empty")));

    if (p_schema == NULL)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_schema is required and must not be NULL")));

    /* 3. TODO: Validate p_schema type == "struct", ValidateType for each field */

    /* TODO: Validate p_schema type is "struct" */
    /* TODO: For each field in p_schema.fields[], call catalog->ValidateType(field.type) */

    /* 4. Check namespace exists */

    PG_TRY();
    {
        if (!iceberg_meta_namespace_exists(p_namespace))
            ereport(ERROR,
                    (errcode(ERRCODE_ICEBERG_NOT_FOUND),
                     errmsg("namespace not found")));
    }
    PG_CATCH();
    {
        ErrorData *edata = CopyErrorData();
        iceberg_err_rethrow_metadata(edata, "create table namespace check");
    }
    PG_END_TRY();

    /* 5. Check table does not already exist */

    PG_TRY();
    {
        if (iceberg_meta_table_exists(p_namespace, p_table_name))
            ereport(ERROR,
                    (errcode(ERRCODE_ICEBERG_CONFLICT),
                     errmsg("table already exists")));
    }
    PG_CATCH();
    {
        ErrorData *edata = CopyErrorData();
        iceberg_err_rethrow_metadata(edata, "create table existence check");
    }
    PG_END_TRY();

    /* 6. TODO: SDK CreateTable */

    /* TODO:
     * IcebergCatalog *catalog = get_iceberg_catalog();
     * LoadTableResult result = catalog->CreateTable(
     *     p_namespace, p_table_name, p_schema,
     *     p_location, p_partition_spec, p_write_order,
     *     p_stage_create, p_properties);
     * if (result.error)
     *     iceberg_error(ERRCODE_ICEBERG_INTERNAL_ERROR,
     *                   "RuntimeException",
     *                   "Failed to create table via SDK");
     */

    /* 7. TODO: DDL CreateStorage */

    /* TODO:
     * iceberg_ddl_CreateStorage(p_namespace, p_table_name, result);
     */

    /* 8. META InsertTable */

    {
        /*
         * TODO: Replace these temporary values with the SDK CreateTable result
         * and the DDL CreateStorage relation OID once those modules are wired.
         */
        static Oid next_temporary_relid = 800000;
        static unsigned int next_temporary_uuid = 1;
        char *schema_json = jsonb_to_cstring(p_schema);
        char *partition_fields_json = p_partition_spec == NULL ? NULL : jsonb_to_cstring(p_partition_spec);
        char *metadata_location = psprintf("file:///tmp/iceberg_catalog/%s/%s/metadata/v1.metadata.json",
                                           p_namespace, p_table_name);
        char *table_location = p_location == NULL
                                   ? psprintf("file:///tmp/iceberg_catalog/%s/%s", p_namespace, p_table_name)
                                   : p_location;
        char *table_uuid = psprintf("00000000-0000-0000-0000-%012u", next_temporary_uuid++);
        MetaRegisterTableInput meta_input;

        memset(&meta_input, 0, sizeof(meta_input));
        meta_input.table_info.relid = next_temporary_relid++;
        meta_input.table_info.namespace_name = p_namespace;
        meta_input.table_info.table_name = p_table_name;
        meta_input.table_info.table_uuid = table_uuid;
        meta_input.table_info.metadata_location = metadata_location;
        meta_input.table_info.previous_metadata_location = NULL;
        meta_input.table_info.table_location = table_location;
        meta_input.table_info.last_column_id = temporary_last_column_id(schema_json);
        meta_input.table_info.current_schema_id = 0;
        meta_input.table_info.has_current_schema_id = true;
        meta_input.table_info.has_current_snapshot_id = false;
        meta_input.table_info.default_spec_id = 0;
        meta_input.table_info.has_default_spec_id = true;
        meta_input.schema_json = schema_json;
        meta_input.partition_fields_json = partition_fields_json;
        meta_input.schema_id = 0;
        meta_input.spec_id = 0;

        PG_TRY();
        {
            iceberg_meta_register_table(p_namespace, p_table_name, &meta_input);
        }
        PG_CATCH();
        {
            ErrorData *edata = CopyErrorData();
            iceberg_err_rethrow_metadata(edata, "create table metadata registration");
        }
        PG_END_TRY();
    }

    /* 9. TODO: Construct and return JSONB response */

    /* TODO:
     * StringInfo buf = makeStringInfo();
     * appendStringInfo(buf,
     *     "{\"metadata-location\":\"%s\",\"metadata\":{...},\"config\":{...}}",
     *     result.metadata_location);
     * Jsonb *ret = ...;
     * PG_RETURN_JSONB_P(ret);
     */

    /* 10. Return minimal JSONB response (TODO: replace with real data from SDK/META) */

    /* TODO: Build response from IcebergTable returned by catalog->CreateTable()
     * once SDK & META modules are available. */

    PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
        CStringGetDatum("{\"metadata-location\": \"TODO\", \"metadata\": {}, \"config\": {}}")));
}


/* ---- is_table_existed ---- */

PG_FUNCTION_INFO_V1(iceberg_is_table_existed);

Datum
iceberg_is_table_existed(PG_FUNCTION_ARGS)
{
    /*-------------------------------------------------------------------------
     * Parameters:
     *   1. p_namespace    TEXT     (required)
     *   2. p_table        TEXT     (required)
     *
     * Returns: JSONB ({"exists": true} or {"exists": false})
     *-------------------------------------------------------------------------
     */

    /* 1. Extract parameters */

    if (PG_NARGS() < 2)
        elog(ERROR, "iceberg_is_table_existed: expected 2 arguments, got %d", PG_NARGS());

    char *p_namespace = NULL;
    if (!PG_ARGISNULL(0))
        p_namespace = text_to_cstring(PG_GETARG_TEXT_P(0));

    char *p_table = NULL;
    if (!PG_ARGISNULL(1))
        p_table = text_to_cstring(PG_GETARG_TEXT_P(1));

    /* 2. Validate required parameters */

    if (p_namespace == NULL || strlen(p_namespace) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_namespace is required and must not be empty")));

    if (p_table == NULL || strlen(p_table) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_table is required and must not be empty")));

    /* 3. TODO: Check table existence via META */

    /* TODO:
     * bool exists = iceberg_meta_table_exists(p_namespace, p_table);
     * if (exists)
     *     PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
     *         CStringGetDatum("{\"exists\": true}")));
     * else
     *     PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
     *         CStringGetDatum("{\"exists\": false}")));
     */

    /* 4. Return stub (TODO: replace with real META call) */

    PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
        CStringGetDatum("{\"exists\": true}")));
}


/* ---- load_table ---- */

PG_FUNCTION_INFO_V1(iceberg_load_table);

Datum
iceberg_load_table(PG_FUNCTION_ARGS)
{
    /*-------------------------------------------------------------------------
     * Parameters:
     *   1. p_namespace    TEXT     (required)
     *   2. p_table        TEXT     (required)
     *
     * Returns: JSONB (LoadTableResult)
     *-------------------------------------------------------------------------
     */

    /* 1. Extract parameters */

    if (PG_NARGS() < 2)
        elog(ERROR, "iceberg_load_table: expected 2 arguments, got %d", PG_NARGS());

    char *p_namespace = NULL;
    if (!PG_ARGISNULL(0))
        p_namespace = text_to_cstring(PG_GETARG_TEXT_P(0));

    char *p_table = NULL;
    if (!PG_ARGISNULL(1))
        p_table = text_to_cstring(PG_GETARG_TEXT_P(1));

    /* 2. Validate required parameters */

    if (p_namespace == NULL || strlen(p_namespace) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_namespace is required and must not be empty")));

    if (p_table == NULL || strlen(p_table) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_table is required and must not be empty")));

    /* 3. TODO: Get table metadata via META */

    /* TODO:
     * MetaTableInfo *info = iceberg_meta_get_table(p_namespace, p_table);
     * if (info == NULL)
     *     ereport(ERROR,
     *             (errcode(ERRCODE_ICEBERG_NOT_FOUND),
     *              errmsg("The given table does not exist")));
     */

    /* 4. TODO: Load table via SDK */

    /* TODO:
     * char *error_msg = NULL;
     * IcebergTable *table = catalog->LoadTable(p_namespace, p_table,
     *     info->metadata_location, &error_msg);
     * if (error_msg != NULL)
     *     ereport(ERROR,
     *             (errcode(ERRCODE_ICEBERG_INTERNAL_ERROR),
     *              errmsg("%s", error_msg)));
     */

    /* 5. TODO: Construct and return LoadTableResult JSONB */

    /* TODO:
     * const char *metadata_json = table->GetMetadataJson();
     * StringInfo buf = makeStringInfo();
     * appendStringInfo(buf,
     *     "{\"metadata-location\":\"%s\",\"metadata\":%s,\"config\":{}}",
     *     info->metadata_location, metadata_json);
     * delete table;
     * PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
     *     CStringGetDatum(buf->data)));
     */

    /* 6. Return stub (TODO: replace with real data from SDK/META) */

    PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
        CStringGetDatum("{\"metadata-location\": \"TODO\", \"metadata\": {}, \"config\": {}}")));
}


/* ---- rename_table ---- */

PG_FUNCTION_INFO_V1(iceberg_rename_table);

Datum
iceberg_rename_table(PG_FUNCTION_ARGS)
{
    /*-------------------------------------------------------------------------
     * Parameters:
     *   1. p_src_ns       TEXT     (required)
     *   2. p_src_table    TEXT     (required)
     *   3. p_dst_ns       TEXT     (required)
     *   4. p_dst_table    TEXT     (required)
     *
     * Returns: JSONB ({"success": true})
     *-------------------------------------------------------------------------
     */

    /* 1. Extract parameters */

    if (PG_NARGS() < 4)
        elog(ERROR, "iceberg_rename_table: expected 4 arguments, got %d", PG_NARGS());

    char *p_src_ns = NULL;
    if (!PG_ARGISNULL(0))
        p_src_ns = text_to_cstring(PG_GETARG_TEXT_P(0));

    char *p_src_table = NULL;
    if (!PG_ARGISNULL(1))
        p_src_table = text_to_cstring(PG_GETARG_TEXT_P(1));

    char *p_dst_ns = NULL;
    if (!PG_ARGISNULL(2))
        p_dst_ns = text_to_cstring(PG_GETARG_TEXT_P(2));

    char *p_dst_table = NULL;
    if (!PG_ARGISNULL(3))
        p_dst_table = text_to_cstring(PG_GETARG_TEXT_P(3));

    /* 2. Validate required parameters */

    if (p_src_ns == NULL || strlen(p_src_ns) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_src_ns is required and must not be empty")));

    if (p_src_table == NULL || strlen(p_src_table) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_src_table is required and must not be empty")));

    if (p_dst_ns == NULL || strlen(p_dst_ns) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_dst_ns is required and must not be empty")));

    if (p_dst_table == NULL || strlen(p_dst_table) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_dst_table is required and must not be empty")));

    /* 3. META RenameTable */

    PG_TRY();
    {
        iceberg_meta_rename_table_record(p_src_ns, p_src_table, p_dst_ns, p_dst_table);
    }
    PG_CATCH();
    {
        ErrorData *edata = CopyErrorData();
        iceberg_err_rethrow_metadata(edata, "rename table metadata");
    }
    PG_END_TRY();

    /* 4. NOTE: SDK RenameTable is not needed.
     *
     * The design doc reserves catalog->RenameTable() for implementations that
     * migrate S3 paths on rename. In standard Iceberg, rename only updates the
     * (namespace, table_name) → metadata_location mapping — S3 metadata.json (keyed
     * by table-uuid) and data files are untouched. Since this mapping is managed
     * entirely by META (iceberg_meta_rename_table_record), calling SDK would
     * duplicate the operation and introduce an atomicity gap between META and SDK.
     *
     * No SDK call required. META is the single source of truth for rename.
     */

    /* 5. Return success */

    PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
        CStringGetDatum("{\"success\": true}")));
}


/* ---- drop_table ---- */

PG_FUNCTION_INFO_V1(iceberg_drop_table);

Datum
iceberg_drop_table(PG_FUNCTION_ARGS)
{
    /*-------------------------------------------------------------------------
     * Parameters:
     *   1. p_namespace    TEXT     (required)
     *   2. p_table        TEXT     (required)
     *   3. p_purge        BOOLEAN  (optional, default FALSE)
     *      TRUE  — also delete underlying S3 data files (not yet supported)
     *      FALSE — remove catalog registration and metadata only
     *
     * Returns: JSONB ({"success": true})
     *-------------------------------------------------------------------------
     */

    /* 1. Extract parameters */

    if (PG_NARGS() < 2)
        elog(ERROR, "iceberg_drop_table: expected at least 2 arguments, got %d", PG_NARGS());

    char *p_namespace = NULL;
    if (!PG_ARGISNULL(0))
        p_namespace = text_to_cstring(PG_GETARG_TEXT_P(0));

    char *p_table = NULL;
    if (!PG_ARGISNULL(1))
        p_table = text_to_cstring(PG_GETARG_TEXT_P(1));

    bool p_purge = false;
    if (PG_NARGS() > 2 && !PG_ARGISNULL(2))
        p_purge = PG_GETARG_BOOL(2);

    /* 2. Validate required parameters */

    if (p_namespace == NULL || strlen(p_namespace) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_namespace is required and must not be empty")));

    if (p_table == NULL || strlen(p_table) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_table is required and must not be empty")));

    /* 3. TODO: Check p_purge not yet supported */

    if (p_purge)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_NOT_SUPPORTED),
                 errmsg("p_purge is not yet supported")));

    /* 4. TODO: DDL DropStorage */

    /* TODO:
     * iceberg_ddl_DropStorage(p_namespace, p_table);
     */

    /* 5. META DeleteTable (cascade handles related rows) */

    PG_TRY();
    {
        iceberg_meta_drop_table_record(p_namespace, p_table);
    }
    PG_CATCH();
    {
        ErrorData *edata = CopyErrorData();
        iceberg_err_rethrow_metadata(edata, "drop table metadata delete");
    }
    PG_END_TRY();

    /* 6. TODO: SDK DropTable is reserved (best-effort metadata cleanup).
     *
     * Data file deletion (p_purge=TRUE) is a separate concern, not part of
     * this SDK call. The SDK method itself is unaffected by the purge flag.
     */

    /* TODO:
     * catalog->DropTable(p_namespace, p_table);
     */

    /* 7. Return success */

    PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
        CStringGetDatum("{\"success\": true}")));
}


/* ---- commit_table ---- */

PG_FUNCTION_INFO_V1(iceberg_commit_table);

Datum
iceberg_commit_table(PG_FUNCTION_ARGS)
{
    /*-------------------------------------------------------------------------
     * Parameters:
     *   1. p_namespace    TEXT   (required)
     *   2. p_table        TEXT   (required)
     *   3. p_requirements JSONB  (required)
     *   4. p_updates      JSONB  (required)
     *
     * Returns: JSONB
     *   {"metadata-location": "<path>", "metadata": {...}}
     *-------------------------------------------------------------------------
     */

    /* 1. Extract parameters from PG_FUNCTION_ARGS */

    if (PG_NARGS() < 4)
        elog(ERROR, "iceberg_commit_table: expected at least 4 arguments, got %d", PG_NARGS());

    /* p_namespace (required) */
    char *p_namespace = NULL;
    if (!PG_ARGISNULL(0))
        p_namespace = text_to_cstring(PG_GETARG_TEXT_P(0));

    /* p_table (required) */
    char *p_table = NULL;
    if (!PG_ARGISNULL(1))
        p_table = text_to_cstring(PG_GETARG_TEXT_P(1));

    /* p_requirements (required) */
    Jsonb *p_requirements = NULL;
    if (!PG_ARGISNULL(2))
        p_requirements = DatumGetJsonb(PG_GETARG_DATUM(2));

    /* p_updates (required) */
    Jsonb *p_updates = NULL;
    if (!PG_ARGISNULL(3))
        p_updates = DatumGetJsonb(PG_GETARG_DATUM(3));

    /* 2. Validate required parameters */

    if (p_namespace == NULL || strlen(p_namespace) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_namespace is required and must not be empty")));

    if (p_table == NULL || strlen(p_table) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_table is required and must not be empty")));

    if (p_requirements == NULL)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_requirements is required and must not be NULL")));

    if (p_updates == NULL)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_updates is required and must not be NULL")));

    /* 3. TODO: Validate p_updates elements have action = "add-snapshot" */

    /* TODO: Validate each element in p_updates has "action" = "add-snapshot" */

    /* 4. TODO: META GetTableForUpdate */

    /* TODO:
     * info = META.GetTableForUpdate(p_namespace, p_table);
     * if (info == NULL)
     *     ereport(ERROR, (errcode(ERRCODE_ICEBERG_NOT_FOUND),
     *                     errmsg("table not found")));
     */

    /* 5. TODO: SDK LoadTable */

    /* TODO:
     * error_msg = NULL;
     * table = catalog->LoadTable(p_namespace, p_table, info->metadata_location, &error_msg);
     * if (error_msg != NULL)
     *     ereport(ERROR, (errcode(ERRCODE_ICEBERG_INTERNAL_ERROR),
     *                     errmsg("{\"type\":\"ServiceUnavailable\",\"message\":\"%s\",\"stack\":[]}", error_msg)));
     */

    /* 6. TODO: SDK CommitTable (apply requirements + updates + write S3) */

    /* TODO:
     * newMdlLocation = table->CommitTable(jsonb_to_cstring(p_requirements),
     *                                      jsonb_to_cstring(p_updates), &error_msg);
     * if (error_msg != NULL)
     *     ereport(ERROR, (errcode(ERRCODE_ICEBERG_CONFLICT),
     *                     errmsg("{\"type\":\"CommitFailedException\",\"message\":\"%s\",\"stack\":[]}", error_msg)));
     */

    /* 7. META commit_table (update table pointer + insert snapshot row) */

    /*
     * TODO: Replace these temporary values with the SDK CommitTable result
     * once the SDK modules are wired up.
     */
    {
        MetaTableInfo *info = iceberg_meta_lock_table(p_namespace, p_table);
        static int64_t next_snapshot_id = 1;

        MetaCommitTableInput meta_input;

        memset(&meta_input, 0, sizeof(meta_input));
        meta_input.namespace_name = p_namespace;
        meta_input.table_name = p_table;
        meta_input.table_uuid = info->table_uuid;
        meta_input.old_metadata_location = info->metadata_location;
        meta_input.new_metadata_location = psprintf("file:///tmp/iceberg_catalog/%s/%s/metadata/v2.metadata.json",
                                                     p_namespace, p_table);
        meta_input.new_snapshot_id = next_snapshot_id++;
        meta_input.snapshot_schema_id = info->current_schema_id;
        meta_input.has_snapshot_schema_id = info->has_current_schema_id;
        meta_input.snapshot_timestamp_ms = 0;
        meta_input.manifest_list = NULL;
        meta_input.total_records = 0;
        meta_input.has_total_records = false;

        iceberg_meta_commit_table(&meta_input);
        iceberg_meta_free_table_info(info);

        /* 8. Return response with the new metadata location */

        PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
            CStringGetDatum(psprintf("{\"metadata-location\": \"%s\", \"metadata\": {}}",
                                     meta_input.new_metadata_location))));
    }
}


/* ---- add_column ---- */

PG_FUNCTION_INFO_V1(iceberg_add_column);

Datum
iceberg_add_column(PG_FUNCTION_ARGS)
{
    /*-------------------------------------------------------------------------
     * Parameters:
     *   1. p_namespace   TEXT    (required)
     *   2. p_table       TEXT    (required)
     *   3. p_column_name TEXT    (required)
     *   4. p_column_type TEXT    (required)
     *   5. p_column_doc  TEXT    (optional, default NULL)
     *
     * Returns: JSONB
     *   {"metadata-location": "<path>", "metadata": {...}}
     *-------------------------------------------------------------------------
     */

    /* 1. Extract parameters from PG_FUNCTION_ARGS */

    if (PG_NARGS() < 4)
        elog(ERROR, "iceberg_add_column: expected at least 4 arguments, got %d", PG_NARGS());

    /* p_namespace (required) */
    char *p_namespace = NULL;
    if (!PG_ARGISNULL(0))
        p_namespace = text_to_cstring(PG_GETARG_TEXT_P(0));

    /* p_table (required) */
    char *p_table = NULL;
    if (!PG_ARGISNULL(1))
        p_table = text_to_cstring(PG_GETARG_TEXT_P(1));

    /* p_column_name (required) */
    char *p_column_name = NULL;
    if (!PG_ARGISNULL(2))
        p_column_name = text_to_cstring(PG_GETARG_TEXT_P(2));

    /* p_column_type (required) */
    char *p_column_type = NULL;
    if (!PG_ARGISNULL(3))
        p_column_type = text_to_cstring(PG_GETARG_TEXT_P(3));

    /* p_column_doc (optional, default NULL) */
    char *p_column_doc = NULL;
    if (PG_NARGS() > 4 && !PG_ARGISNULL(4))
        p_column_doc = text_to_cstring(PG_GETARG_TEXT_P(4));

    /* 2. Validate required parameters */

    if (p_namespace == NULL || strlen(p_namespace) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_namespace is required and must not be empty")));

    if (p_table == NULL || strlen(p_table) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_table is required and must not be empty")));

    if (p_column_name == NULL || strlen(p_column_name) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_column_name is required and must not be empty")));

    if (p_column_type == NULL || strlen(p_column_type) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_column_type is required and must not be empty")));

    /* 3. TODO: Validate p_column_type via SDK */

    /* TODO:
     * if (!catalog->ValidateType(p_column_type, &err))
     *     ereport(ERROR, (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
     *                     errmsg("invalid column type: %s", err)));
     */

    /* 4. TODO: SDK LoadTable */

    /* TODO:
     * error_msg = NULL;
     * table = catalog->LoadTable(p_namespace, p_table, info->metadata_location, &error_msg);
     * if (error_msg != NULL)
     *     ereport(ERROR, (errcode(ERRCODE_ICEBERG_INTERNAL_ERROR),
     *                     errmsg("{\"type\":\"ServiceUnavailable\",\"message\":\"%s\",\"stack\":[]}", error_msg)));
     */

    /* 5. TODO: Check column name conflict against current schema */

    /* TODO:
     * currentSchema = table->GetCurrentSchema();
     * if currentSchema has field named p_column_name → ereport(P0001, "column already exists")
     */

    /* 6. TODO: SDK AddColumn → new schema + new field ID */

    /* TODO:
     * newFieldId = 0;
     * newSchema = table->AddColumn(p_column_name, p_column_type, p_column_doc, &newFieldId);
     * newSchemaId = table->GetCurrentSchemaId() + 1;
     */

    /* 7. META commit_schema_change (update table pointer + insert schema row) */

    /*
     * TODO: Replace these temporary values with the SDK AddColumn/CommitTable
     * result once the SDK modules are wired up.
     */
    {
        MetaTableInfo *info = iceberg_meta_lock_table(p_namespace, p_table);
        int new_last_column_id = info->last_column_id + 1;
        int new_schema_id = info->current_schema_id + 1;

        /*
         * TODO: Replace this temporary schema JSON with the real schema from
         * the SDK AddColumn result once wired up.
         */
        char *new_schema_json = psprintf(
            "{\"type\":\"struct\",\"fields\":["
            "{\"id\":%d,\"name\":\"%s\",\"required\":false,\"type\":\"%s\""
            "%s%s}]}",
            new_last_column_id, p_column_name, p_column_type,
            p_column_doc != NULL ? ",\"doc\":\"" : "",
            p_column_doc != NULL ? p_column_doc : "");

        MetaCommitSchemaChangeInput meta_input;

        memset(&meta_input, 0, sizeof(meta_input));
        meta_input.namespace_name = p_namespace;
        meta_input.table_name = p_table;
        meta_input.table_uuid = info->table_uuid;
        meta_input.old_metadata_location = info->metadata_location;
        meta_input.new_metadata_location = psprintf("file:///tmp/iceberg_catalog/%s/%s/metadata/v2.metadata.json",
                                                     p_namespace, p_table);
        meta_input.new_schema_id = new_schema_id;
        meta_input.schema_json = new_schema_json;
        meta_input.new_last_column_id = new_last_column_id;

        iceberg_meta_commit_schema_change(&meta_input);
        iceberg_meta_free_table_info(info);

        /* 8. Return response with the new metadata location */

        PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
            CStringGetDatum(psprintf("{\"metadata-location\": \"%s\", \"metadata\": {}}",
                                     meta_input.new_metadata_location))));
    }
}


/* ---- list_tables ---- */

PG_FUNCTION_INFO_V1(iceberg_list_tables);

Datum
iceberg_list_tables(PG_FUNCTION_ARGS)
{
    /*-------------------------------------------------------------------------
     * Parameters:
     *   1. p_namespace    TEXT     (required)
     *   2. p_page_size    INTEGER  (optional, default 1000)
     *   3. p_page_token   TEXT     (optional, default NULL)
     *
     * Returns: JSONB (ListTablesResponse)
     *-------------------------------------------------------------------------
     */

    /* 1. Extract parameters */

    if (PG_NARGS() < 1)
        elog(ERROR, "iceberg_list_tables: expected at least 1 argument, got %d", PG_NARGS());

    char *p_namespace = NULL;
    if (!PG_ARGISNULL(0))
        p_namespace = text_to_cstring(PG_GETARG_TEXT_P(0));

    int p_page_size = 1000;
    if (PG_NARGS() > 1 && !PG_ARGISNULL(1))
        p_page_size = PG_GETARG_INT32(1);

    char *p_page_token = NULL;
    if (PG_NARGS() > 2 && !PG_ARGISNULL(2))
        p_page_token = text_to_cstring(PG_GETARG_TEXT_P(2));

    /* 2. Validate parameters */

    if (p_namespace == NULL || strlen(p_namespace) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_namespace is required and must not be empty")));

    if (p_page_size < 1)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("p_page_size must be >= 1")));

    /* 3. TODO: Check namespace exists via META */

    /* TODO:
     * if (!iceberg_meta_namespace_exists(p_namespace))
     *     ereport(ERROR,
     *             (errcode(ERRCODE_ICEBERG_NOT_FOUND),
     *              errmsg("The given namespace does not exist")));
     */

    /* 4. TODO: List tables via META */

    /* TODO:
     * char *result = iceberg_meta_list_tables(p_namespace, p_page_size, p_page_token);
     * PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
     *     CStringGetDatum(result)));
     * pfree(result);
     */

    /* 5. Return stub (TODO: replace with real META call) */

    PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
        CStringGetDatum("{\"identifiers\": [], \"next-page-token\": null}")));
}
