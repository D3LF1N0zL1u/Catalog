/*-------------------------------------------------------------------------
 *
 * fdw_util.cpp
 *    Direct foreign-table creation via SPI CREATE FOREIGN TABLE.
 *
 * When iceberg_fdw is installed, we skip the rendezvous hook and simply
 * execute DDL — iceberg_fdw's ProcessUtility hook intercepts CREATE
 * FOREIGN TABLE and handles both the DDL and catalog metadata.
 *-------------------------------------------------------------------------
 */

#include "postgres.h"

#include "catalog/namespace.h"
#include "catalog/pg_foreign_server.h"
#include "executor/spi.h"
#include "foreign/foreign.h"
#include "lib/stringinfo.h"
#include "utils/builtins.h"
#include "utils/elog.h"
#include "utils/json.h"
#include "utils/jsonb.h"
#include "utils/lsyscache.h"
#include "utils/rel.h"

#include <string.h>

#include "fdw_util.h"
#include "iceberg_catalog.h"
#include "metadata.h"

/* ------------------------------------------------------------------ */
/*  Iceberg → SQL type mapping                                         */
/* ------------------------------------------------------------------ */

static const char *
iceberg_type_to_sql(const char *iceberg_type)
{
    if (iceberg_type == NULL)
        return "text";

    if (strcmp(iceberg_type, "boolean") == 0)    return "boolean";
    if (strcmp(iceberg_type, "int") == 0)         return "int";
    if (strcmp(iceberg_type, "long") == 0)        return "bigint";
    if (strcmp(iceberg_type, "float") == 0)       return "real";
    if (strcmp(iceberg_type, "double") == 0)      return "double precision";
    if (strcmp(iceberg_type, "decimal") == 0)     return "numeric";
    if (strcmp(iceberg_type, "date") == 0)        return "date";
    if (strcmp(iceberg_type, "time") == 0)        return "time";
    if (strcmp(iceberg_type, "timestamp") == 0)   return "timestamp";
    if (strcmp(iceberg_type, "timestamptz") == 0) return "timestamptz";
    if (strcmp(iceberg_type, "string") == 0)      return "text";
    if (strcmp(iceberg_type, "uuid") == 0)        return "uuid";
    if (strcmp(iceberg_type, "binary") == 0)      return "bytea";

    /* parameterised types */
    if (strncmp(iceberg_type, "decimal", 7) == 0) return "numeric";  /* decimal(P,S) */
    if (strncmp(iceberg_type, "fixed", 5) == 0)   return "bytea";    /* fixed(L) */

    /* list / map / struct → text as placeholder */
    return "text";
}

/* ------------------------------------------------------------------ */
/*  Foreign server lookup                                              */
/* ------------------------------------------------------------------ */

#define ICEBERG_DEFAULT_SERVER_NAME "iceberg_catalog_server"

/*
 * Find (or create) a foreign server for iceberg_fdw.  Returns InvalidOid
 * if iceberg_fdw is not installed.
 */
static Oid
find_or_create_iceberg_fdw_server(void)
{
    Relation rel;
    SysScanDesc scan;
    HeapTuple tuple;
    Oid fdw_oid;
    Oid server_oid = InvalidOid;

    fdw_oid = get_foreign_data_wrapper_oid("iceberg_fdw", true);
    if (!OidIsValid(fdw_oid))
        return InvalidOid;

    /* Look for an existing server */
    rel = heap_open(ForeignServerRelationId, AccessShareLock);
    scan = systable_beginscan(rel, InvalidOid, false, NULL, 0, NULL);

    while ((tuple = systable_getnext(scan)) != NULL) {
        Form_pg_foreign_server svr = (Form_pg_foreign_server) GETSTRUCT(tuple);

        if (svr->srvfdw == fdw_oid) {
            server_oid = HeapTupleGetOid(tuple);
            break;
        }
    }

    systable_endscan(scan);
    heap_close(rel, AccessShareLock);

    if (OidIsValid(server_oid))
        return server_oid;

    /* None found — create a default one via SPI */
    {
        const char *warehouse = getenv("ICEBERG_WAREHOUSE");

        if (warehouse == NULL || warehouse[0] == '\0')
            warehouse = "file:///tmp/iceberg_warehouse";

        connect_spi();

        PG_TRY();
        {
            char *escaped = quote_literal_cstr(warehouse);
            char *sql = psprintf(
                "CREATE SERVER \"%s\" FOREIGN DATA WRAPPER iceberg_fdw "
                "OPTIONS (warehouse %s)",
                ICEBERG_DEFAULT_SERVER_NAME, escaped);
            pfree(escaped);
            SPI_execute(sql, false, 0);
            finish_spi();
        }
        PG_CATCH();
        {
            finish_spi();
            PG_RE_THROW();
        }
        PG_END_TRY();
    }

    /* Look it up again to get the OID */
    server_oid = get_foreign_server_oid(ICEBERG_DEFAULT_SERVER_NAME, true);
    return server_oid;
}

/* ------------------------------------------------------------------ */
/*  Schema parsing helpers                                             */
/* ------------------------------------------------------------------ */

/*
 * We receive a schema like:
 *   {"type":"struct","fields":[
 *     {"id":1,"name":"col1","required":true,"type":"string"},
 *     {"id":2,"name":"col2","required":false,"type":"int"}
 *   ]}
 *
 * We extract "name" and "type" from each field to build column
 * definitions.
 */

#define MAX_FIELDS 256

typedef struct {
    char *name;
    const char *sql_type;
} FieldDef;


static int
parse_schema_fields(Jsonb *schema, FieldDef *fields, int max_fields)
{
    Jsonb *farr;
    int len, i, nfields = 0;

    /* schema->"fields" */
    farr = DatumGetJsonb(
        DirectFunctionCall2Coll(jsonb_object_field,
                                InvalidOid,
                                JsonbGetDatum(schema),
                                CStringGetTextDatum("fields")));

    if (farr == NULL || !JB_ROOT_IS_ARRAY(farr))
        return 0;

    len = DatumGetInt32(
        DirectFunctionCall1Coll(jsonb_array_length, InvalidOid,
                                JsonbGetDatum(farr)));

    for (i = 0; i < len && nfields < max_fields; i++) {
        Jsonb *field;
        text *name_txt, *type_txt;

        /* farr[i] */
        field = DatumGetJsonb(
            DirectFunctionCall2Coll(jsonb_array_element,
                                    InvalidOid,
                                    JsonbGetDatum(farr),
                                    Int32GetDatum(i)));

        /* field->>"name" */
        name_txt = DatumGetTextP(
            DirectFunctionCall2Coll(jsonb_object_field_text,
                                    InvalidOid,
                                    JsonbGetDatum(field),
                                    CStringGetTextDatum("name")));

        /* field->>"type" */
        type_txt = DatumGetTextP(
            DirectFunctionCall2Coll(jsonb_object_field_text,
                                    InvalidOid,
                                    JsonbGetDatum(field),
                                    CStringGetTextDatum("type")));

        fields[nfields].name = pstrdup(text_to_cstring(name_txt));
        fields[nfields].sql_type = iceberg_type_to_sql(text_to_cstring(type_txt));
        nfields++;
    }

    return nfields;
}
/* ------------------------------------------------------------------ */
/*  Public API                                                         */
/* ------------------------------------------------------------------ */

Oid
iceberg_fdw_create_foreign_table(const char *p_namespace,
                                    const char *p_table_name,
                                    Jsonb *schema)
{
    Oid server_oid;
    char *server_name;
    Oid namespace_oid;
    Oid relid;
    FieldDef fields[MAX_FIELDS];
    int nfields;
    StringInfo sql;
    int i;

    /* 1. Find or auto-create an iceberg_fdw server */
    server_oid = find_or_create_iceberg_fdw_server();
    if (!OidIsValid(server_oid))
        return InvalidOid;

    server_name = GetForeignServer(server_oid)->servername;
    if (server_name == NULL)
        return InvalidOid;

    /* 2. Parse schema fields */
    nfields = parse_schema_fields(schema, fields, MAX_FIELDS);
    if (nfields == 0) {
        /*
         * Empty schema — still create the table but with no user columns.
         * Iceberg requires at least one column, but we'll trust the caller.
         */
    }

    /* 3. Build CREATE FOREIGN TABLE statement. */
    sql = makeStringInfo();

    appendStringInfo(sql,
        "CREATE FOREIGN TABLE %s.%s (",
        quote_identifier(p_namespace), quote_identifier(p_table_name));

    for (i = 0; i < nfields; i++) {
        if (i > 0)
            appendStringInfoString(sql, ", ");
        appendStringInfo(sql, "%s %s",
                         quote_identifier(fields[i].name), fields[i].sql_type);
    }

    appendStringInfo(sql,
        ") SERVER %s OPTIONS (namespace %s, table_name %s)",
        quote_identifier(server_name),
        quote_literal_cstr(p_namespace),
        quote_literal_cstr(p_table_name));

    /* 4. Execute via SPI.
     *
     * iceberg_fdw's ProcessUtility hook intercepts CREATE FOREIGN TABLE
     * and writes catalog metadata via its own catalog_adapter.  Section 8
     * is therefore skipped when ft_relid is valid.
     */
    connect_spi();

    PG_TRY();
    {
        SPI_execute(sql->data, false, 0);
        finish_spi();
    }
    PG_CATCH();
    {
        finish_spi();
        PG_RE_THROW();
    }
    PG_END_TRY();

    /* 5. Look up the OID in the namespace's SQL schema. */
    namespace_oid = get_namespace_oid(p_namespace, true);
    if (!OidIsValid(namespace_oid))
        namespace_oid = get_namespace_oid("public", false);
    relid = get_relname_relid(p_table_name, namespace_oid);

    /* Clean up field names */
    for (i = 0; i < nfields; i++)
        pfree(fields[i].name);

    pfree(sql->data);
    pfree(sql);

    return relid;
}

/*
 * Drop the foreign table created for an Iceberg table.
 * Returns InvalidOid if iceberg_fdw is not installed, otherwise
 * ereport(ERROR)s on failure.
 */
Oid
iceberg_fdw_drop_foreign_table(const char *p_namespace,
                                const char *p_table_name)
{
    Oid server_oid;

    server_oid = find_or_create_iceberg_fdw_server();
    if (!OidIsValid(server_oid))
        return InvalidOid;

    connect_spi();

    PG_TRY();
    {
        char *sql = psprintf("DROP FOREIGN TABLE %s.%s",
                             quote_identifier(p_namespace),
                             quote_identifier(p_table_name));
        SPI_execute(sql, false, 0);
        pfree(sql);
        finish_spi();
    }
    PG_CATCH();
    {
        finish_spi();
        PG_RE_THROW();
    }
    PG_END_TRY();

    return InvalidOid;
}
