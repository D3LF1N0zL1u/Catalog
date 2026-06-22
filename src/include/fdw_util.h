/*-------------------------------------------------------------------------
 *
 * fdw_util.h
 *    Direct foreign-table creation bridge for iceberg_catalog.
 *
 * Instead of the rendezvous hook mechanism, section 7.2 can call
 * iceberg_fdw_create_foreign_table() which executes a CREATE FOREIGN
 * TABLE statement via SPI.  iceberg_fdw's ProcessUtility hook intercepts
 * the statement and handles the actual DDL + catalog metadata writes.
 *-------------------------------------------------------------------------
 */

#ifndef ICEBERG_FDW_UTIL_H
#define ICEBERG_FDW_UTIL_H

#include "postgres.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Attempt to create an openGauss foreign table backed by the Iceberg table
 * described by p_namespace / p_table_name / p_schema.
 *
 * Returns the Oid of the newly created foreign table, or InvalidOid if
 * foreign-table creation is not configured (e.g. iceberg_fdw not installed).
 *
 * The warehouse path comes from the ICEBERG_WAREHOUSE environment variable
 * when set, otherwise defaults to file:///tmp/iceberg_warehouse.
 *
 * On error the function ereport(ERROR)s.
 */
extern Oid iceberg_fdw_create_foreign_table(
    const char *p_namespace,
    const char *p_table_name,
    Jsonb *schema);

/*
 * Drop the foreign table for an Iceberg table via SPI.
 * Returns InvalidOid when iceberg_fdw is not installed.
 */
extern Oid iceberg_fdw_drop_foreign_table(
    const char *p_namespace,
    const char *p_table_name);

#ifdef __cplusplus
}
#endif

#endif /* ICEBERG_FDW_UTIL_H */
