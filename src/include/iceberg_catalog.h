#ifndef ICEBERG_CATALOG_H
#define ICEBERG_CATALOG_H

#define ICEBERG_CATALOG_VERSION "1.0.0"

/* Custom SQLSTATE codes for Iceberg REST Catalog error mapping */
#define ERRCODE_ICEBERG_INVALID_PARAM     MAKE_SQLSTATE('P','0','0','0','1')  /* 400 Bad Request */
#define ERRCODE_ICEBERG_UNAUTHORIZED      MAKE_SQLSTATE('P','0','0','0','2')  /* 401 Unauthorized */
#define ERRCODE_ICEBERG_FORBIDDEN         MAKE_SQLSTATE('P','0','0','0','3')  /* 403 Forbidden */
#define ERRCODE_ICEBERG_NOT_FOUND         MAKE_SQLSTATE('P','0','0','0','4')  /* 404 Not Found */
#define ERRCODE_ICEBERG_CONFLICT          MAKE_SQLSTATE('P','0','0','0','5')  /* 409 Conflict */
#define ERRCODE_ICEBERG_CONSTRAINT_VIOL   MAKE_SQLSTATE('P','0','0','0','6')  /* 422 Unprocessable */
#define ERRCODE_ICEBERG_NOT_SUPPORTED     MAKE_SQLSTATE('P','0','0','0','8')  /* 501 Not Implemented */
#define ERRCODE_ICEBERG_INTERNAL_ERROR    MAKE_SQLSTATE('P','0','0','0','9')  /* 500 Internal Error */

#endif /* ICEBERG_CATALOG_H */
