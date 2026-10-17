#!/bin/sh
# Regenerate Facts_Tables.thy from the shipped stores (then run tables_check.py and the check-native build).
exec env PYTHONDONTWRITEBYTECODE=1 python3 -I "$(dirname "$0")/gen_tables.py"
