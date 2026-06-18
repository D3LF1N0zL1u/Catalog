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
 * Create the rendezvous variables that optional extensions can use to
 * register delta-table creation/drop hooks.  If no extension registers a
 * hook, the pointer remains NULL and iceberg_catalog proceeds normally.
 */
extern "C" void
_PG_init(void)
{
    (void) find_rendezvous_variable(ICEBERG_CREATE_DELTA_TABLE_HOOK_VAR);
    (void) find_rendezvous_variable(ICEBERG_DROP_DELTA_TABLE_HOOK_VAR);
}
