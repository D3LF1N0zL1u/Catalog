#!/bin/bash
# run_tests.sh — Run test SQL files, produce results, compare with expected.
# Usage:
#   bash test/run_tests.sh                          # run all tests
#   bash test/run_tests.sh -g                       # regenerate all expected baselines
#   bash test/run_tests.sh [-g] <test_name>         # run/generate single test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_DIR="$SCRIPT_DIR/sql"
EXPECTED_DIR="$SCRIPT_DIR/expected"
RESULTS_DIR="$SCRIPT_DIR/results"
PORT="${TEST_PORT:-37555}"
DB="iceberg_test"
GEN=false
FILTER=""

# Parse args
for arg in "$@"; do
    case "$arg" in
        -g) GEN=true ;;
        *)  FILTER="$arg" ;;
    esac
done

mkdir -p "$RESULTS_DIR" "$EXPECTED_DIR"

normalize() {
    sed -E '
        /^total time: /d
        /^[[:space:]]*$/d
        s/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/<uuid>/g
        s/"last-updated-ms": [0-9]+/"last-updated-ms": <ts>/g
        s/iceberg_test/<test_db>/g
	        s#gsql:[^ ]+test/sql/#gsql:test/sql/#g
    '
}

# ── Prepare database ──────────────────────────────────────────────────────
# Note: gaussdb must be started with ICEBERG_WAREHOUSE=file:///tmp/iceberg_warehouse
# (no S3/MinIO required).  Example:
#   export ICEBERG_WAREHOUSE=file:///tmp/iceberg_warehouse
#   gaussdb -D /path/to/data --single_node -p 37555 &

gsql -d postgres -p "$PORT" -c "DROP DATABASE IF EXISTS $DB;" 2>/dev/null
gsql -d postgres -p "$PORT" -c "CREATE DATABASE $DB;" 2>/dev/null
gsql -d "$DB" -p "$PORT" -c "CREATE EXTENSION iceberg_fdw;" 2>/dev/null
gsql -d "$DB" -p "$PORT" -c "CREATE EXTENSION iceberg_catalog;" 2>/dev/null

# ── Collect test files ────────────────────────────────────────────────────

tests=()
if [ -n "$FILTER" ]; then
    # Remove .sql suffix if given, in case user types "verify_extension.sql"
    base="${FILTER%.sql}"
    found="$SQL_DIR/$base.sql"
    if [ ! -f "$found" ]; then
        echo "ERROR: test '$base' not found in $SQL_DIR/"
        echo "Available tests:"
        for f in "$SQL_DIR"/*.sql; do
            echo "  $(basename "$f" .sql)"
        done
        exit 1
    fi
    tests+=("$found")
else
    for f in "$SQL_DIR"/*.sql; do
        [ -f "$f" ] && tests+=("$f")
    done
fi

# ── Run each test ─────────────────────────────────────────────────────────

pass=0
fail=0

for sql in "${tests[@]}"; do
    name="$(basename "$sql" .sql)"
    out_file="$RESULTS_DIR/$name.out"
    exp_file="$EXPECTED_DIR/$name.sql"

    echo ""
    echo "──── $name ────"

    gsql -a -d "$DB" -p "$PORT" -f "$sql" 2>&1 | normalize > "$out_file"

    if $GEN; then
        echo "----- $name expected output -----"
        cat "$out_file"
        echo "---------------------------------"
        read -r -p "Accept as baseline? [Y/n] " reply
        case "$reply" in
            n|N|no|NO) echo "  → SKIPPED"; continue ;;
            *) cp "$out_file" "$exp_file"; echo "  → BASELINE SAVED" ;;
        esac
        continue
    fi

    if [ ! -f "$exp_file" ]; then
        echo "  → No expected file — run with -g to generate"
        continue
    fi

    if diff -q "$out_file" "$exp_file" > /dev/null 2>&1; then
        echo "  ✓ PASS"
        pass=$((pass + 1))
    else
        echo "  ✗ FAIL"
        diff "$out_file" "$exp_file" | head -40
        fail=$((fail + 1))
    fi
done

# ── Cleanup ───────────────────────────────────────────────────────────────

gsql -d postgres -p "$PORT" -c "DROP DATABASE IF EXISTS $DB;" 2>/dev/null

echo ""
echo "═══════════════════════════════════════"
if $GEN; then
    echo " Expected baselines generation complete."
else
    echo " ${pass} passed, ${fail} failed"
fi
echo "═══════════════════════════════════════"