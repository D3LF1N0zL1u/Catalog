/*-------------------------------------------------------------------------
 *
 * iceberg_catalog_hook.h
 *    Public hook interface for the iceberg_catalog extension.
 *
 * Other extensions can register callbacks by calling the exported
 * registration functions declared below.  iceberg_catalog will invoke
 * the registered callbacks during CREATE TABLE and DROP TABLE processing.
 *
 * The legacy rendezvous variable mechanism has been removed; callers
 * should use register_iceberg_create_delta_table_hook() and
 * register_iceberg_drop_delta_table_hook() instead.
 *-------------------------------------------------------------------------
 */

#ifndef ICEBERG_CATALOG_HOOK_H
#define ICEBERG_CATALOG_HOOK_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Hook called during iceberg_catalog.create_table() after validation and
 * existence checks, inside the DDL CreateStorage step.  Another extension
 * can use this hook to create an internal openGauss table with the same
 * schema.
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
 * Hook called during iceberg_catalog.drop_table() after validation and the
 * purge check, before the META DeleteTable step.  Another extension can use
 * this hook to drop the internal openGauss table that was created alongside
 * the Iceberg table.
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
 * Exported registration functions.
 *
 * The delta plugin discovers these symbols (for example via
 * dlsym(RTLD_DEFAULT, ...)) and calls them to register its callbacks.
 * Both extensions must be loaded in the same backend process.
 */
PGDLLEXPORT void register_iceberg_create_delta_table_hook(
    iceberg_create_delta_table_hook_type callback);
PGDLLEXPORT void register_iceberg_drop_delta_table_hook(
    iceberg_drop_delta_table_hook_type callback);

/*
 * Internal callback storage, defined in iceberg_catalog.cpp and referenced
 * from table.cpp.  External code should not touch these directly; use the
 * registration functions above.
 */
extern iceberg_create_delta_table_hook_type create_delta_table_hook;
extern iceberg_drop_delta_table_hook_type   drop_delta_table_hook;

#ifdef __cplusplus
}
#endif

#endif /* ICEBERG_CATALOG_HOOK_H */
