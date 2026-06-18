/*-------------------------------------------------------------------------
 *
 * iceberg_catalog_hook.h
 *    Public hook interface for the iceberg_catalog extension.
 *
 * Other extensions can register callbacks via the rendezvous variables
 * defined below.  iceberg_catalog will invoke the registered callbacks
 * during CREATE TABLE and DROP TABLE processing.
 *-------------------------------------------------------------------------
 */

#ifndef ICEBERG_CATALOG_HOOK_H
#define ICEBERG_CATALOG_HOOK_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Hook called during iceberg_catalog.create_table() after validation and
 * existence checks, inside the DDL CreateStorage step.  Plugin B can use
 * this hook to create an internal openGauss table with the same schema.
 *
 * Parameters:
 *   namespace_name - target namespace
 *   table_name     - target table name
 *   schema_json    - Iceberg schema as a JSON string
 *
 * The hook has no return value.  On error it should use ereport(ERROR, ...);
 * the error will be propagated by iceberg_catalog.
 */
typedef void (*iceberg_create_delta_table_hook_type)(
    const char *namespace_name,
    const char *table_name,
    const char *schema_json
);

/*
 * Rendezvous variable name.  Plugin B sets the pointer stored at this
 * variable in its _PG_init(); iceberg_catalog reads it during create_table.
 */
#define ICEBERG_CREATE_DELTA_TABLE_HOOK_VAR "iceberg_create_delta_table_hook"

/*
 * Hook called during iceberg_catalog.drop_table() after validation and the
 * purge check, before the META DeleteTable step.  Plugin B can use this
 * hook to drop the internal openGauss table that was created alongside the
 * Iceberg table.
 *
 * Parameters:
 *   namespace_name - target namespace
 *   table_name     - target table name
 *   purge          - whether the caller requested purge
 *
 * The hook has no return value.  On error it should use ereport(ERROR, ...);
 * the error will be propagated by iceberg_catalog.
 */
typedef void (*iceberg_drop_delta_table_hook_type)(
    const char *namespace_name,
    const char *table_name,
    bool        purge
);

/*
 * Rendezvous variable name.  Plugin B sets the pointer stored at this
 * variable in its _PG_init(); iceberg_catalog reads it during drop_table.
 */
#define ICEBERG_DROP_DELTA_TABLE_HOOK_VAR "iceberg_drop_delta_table_hook"

#ifdef __cplusplus
}
#endif

#endif /* ICEBERG_CATALOG_HOOK_H */
