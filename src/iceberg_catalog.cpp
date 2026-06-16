/*-------------------------------------------------------------------------
 *
 * iceberg_catalog.cpp
 *    Minimal shared library entrypoint for the iceberg_catalog extension.
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"
#include "fmgr.h"

#include "iceberg_catalog.h"
#include "iceberg_catalog_hook.h"
#include "namespace.h"

PG_MODULE_MAGIC;

/*
 * _PG_init
 *
 * Create the rendezvous variable that optional extensions can use to
 * register a delta-table creation hook.  If no extension registers the
 * hook, the pointer remains NULL and create_table proceeds normally.
 */
void
_PG_init(void)
{
    (void) find_rendezvous_variable(ICEBERG_CREATE_DELTA_TABLE_HOOK_VAR);
}
