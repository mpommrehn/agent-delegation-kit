#!/usr/bin/env bash
# Thin wrapper for check_run.py. Picks a python that actually runs: on some
# Windows machines `python3` is a Store stub that fails.
#
#   bash evals/check-run.sh <transcript.jsonl> [--meta PATH] [--json]

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if python3 -c 1 >/dev/null 2>&1; then py=python3
elif python -c 1 >/dev/null 2>&1; then py=python
else echo "check-run: no working python found" >&2; exit 2
fi

exec "$py" "$here/check_run.py" "$@"
