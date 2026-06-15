/*-------------------------------------------------------------------------
 *
 * namespace.cpp
 *    Iceberg namespace SQL function implementations.
 *
 * Stub implementation: META operations are marked as TODO, pending the
 * underlying modules to be wired up. Currently returns a minimal response.
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
#include "utils/jsonb.h"
#include "lib/stringinfo.h"

#include <string.h>

#include "iceberg_catalog.h"
#include "namespace.h"


/* ---- create_namespace ---- */
PG_FUNCTION_INFO_V1(iceberg_create_namespace);

Datum
iceberg_create_namespace(PG_FUNCTION_ARGS)
{
    /*-------------------------------------------------------------------------
     * Parameters:
     *   1. p_namespace   TEXT    (required)
     *   2. p_properties  JSONB   (optional, default NULL)
     *
     * Returns: JSONB (CreateNamespaceResponse)
     *   {"namespace": ["<namespace>"], "properties": {<key>: <value>, ...}}
     *-------------------------------------------------------------------------
     */

    /* 1. Extract parameters from PG_FUNCTION_ARGS */
    if (PG_NARGS() < 1)
        elog(ERROR, "iceberg_create_namespace: expected at least 1 argument, got %d", PG_NARGS());

    /* p_namespace (required) */
    char *p_namespace = NULL;
    if (!PG_ARGISNULL(0))
        p_namespace = text_to_cstring(PG_GETARG_TEXT_P(0));

    /* p_properties (optional, default NULL -> treat as empty object {}) */
    Jsonb *p_properties = NULL;
    if (PG_NARGS() > 1 && !PG_ARGISNULL(1))
        p_properties = DatumGetJsonb(PG_GETARG_DATUM(1));

    /* 2. Validate p_namespace */
    if (p_namespace == NULL || strlen(p_namespace) == 0)
        ereport(ERROR,
                (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                 errmsg("namespace must not be empty")));

    /* 3. Validate p_properties (if provided, must be a JSONB object) */
    if (p_properties != NULL)
    {
        Datum type_datum = DirectFunctionCall1(jsonb_typeof,
                               JsonbGetDatum(p_properties));
        char *type_str = text_to_cstring(DatumGetTextP(type_datum));

        if (strcmp(type_str, "object") != 0)
            ereport(ERROR,
                    (errcode(ERRCODE_ICEBERG_INVALID_PARAM),
                     errmsg("p_properties must be a JSONB object")));
        pfree(type_str);
    }

    /* 4. Serialize properties for InsertNamespace and response */
    char *props_str;
    if (p_properties != NULL)
        props_str = DatumGetCString(
            DirectFunctionCall1(jsonb_out,
                JsonbGetDatum(p_properties)));
    else
        props_str = pstrdup("{}");

    /* 5. TODO: META InsertNamespace
     *
     * iceberg_meta_insert_namespace(p_namespace, props_str);
     * // PK violation → ereport(P0005) translated by META layer
     */

    /* 6. Construct and return response */
    StringInfoData buf;

    initStringInfo(&buf);
    appendStringInfo(&buf,
        "{\"namespace\":[\"%s\"],\"properties\":%s}",
        p_namespace, props_str);
    PG_RETURN_DATUM(DirectFunctionCall1(jsonb_in,
        CStringGetDatum(buf.data)));
}
