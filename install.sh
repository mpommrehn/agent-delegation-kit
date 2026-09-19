#!/usr/bin/env bash
# Install the agent definitions in agents/ into a Claude Code agents directory.
#
#   ./install.sh                 copy into ~/.claude/agents
#   ./install.sh --check         report drift; write nothing; exit 1 on any drift
#   ./install.sh --dry-run       say what would happen; write nothing
#   ./install.sh --force         replace files that differ, keeping a .bak copy
#   ./install.sh --dest DIR      install somewhere else (a project's .claude/agents)
#
# Never edits settings.json. It prints the line to add instead, because a
# settings file holds things this script has no business rewriting.
#
# Exit codes: 0 done or in sync, 1 drift found by --check, 2 a file was left
# alone (it differs, or it is a symlink; see the output), 3 a copy failed,
# 64 bad usage or nothing to install.

set -u

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agents"
dest="${HOME}/.claude/agents"
mode="install"
force=0

usage() { sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --check)   mode="check" ;;
    --dry-run) mode="dry-run" ;;
    --force)   force=1 ;;
    --dest)
      shift
      if [ $# -eq 0 ] || [ -z "$1" ]; then
        echo "install.sh: --dest needs a directory" >&2
        exit 64
      fi
      dest="$1"
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
  shift
done

# A destination that starts with a dash would be read as an option by cp.
case "$dest" in -*) dest="./$dest" ;; esac

if [ ! -d "$src_dir" ]; then
  echo "install.sh: no agents directory at $src_dir" >&2
  exit 64
fi

found=0
for src in "$src_dir"/*.md; do [ -f "$src" ] && found=1; done
if [ "$found" -eq 0 ]; then
  echo "install.sh: nothing to install: no .md files in $src_dir (partial clone?)" >&2
  exit 64
fi

created_dir=0
if [ ! -d "$dest" ]; then
  if [ "$mode" = "install" ]; then
    mkdir -p -- "$dest" || { echo "install.sh: cannot create $dest" >&2; exit 64; }
  fi
  created_dir=1
fi

drift=0
skipped=0
failed=0
stamp="$(date +%Y%m%d%H%M%S)"

# backup_path FILE: a name for FILE's backup that does not exist yet
backup_path() {
  local candidate="$1.bak-$stamp" n=1
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    n=$((n + 1))
    candidate="$1.bak-$stamp-$n"
  done
  printf '%s' "$candidate"
}

copy_failed() { echo "FAILED     $1 (copy error; see above)" >&2; failed=1; }

for src in "$src_dir"/*.md; do
  [ -f "$src" ] || continue
  name="$(basename "$src")"
  target="$dest/$name"

  if [ -L "$target" ]; then
    # Writing through a link would change whatever it points at.
    drift=1
    case "$mode" in
      check) echo "symlink    $name" ;;
      *)     echo "skipped    $name (the installed copy is a symlink; replace it by hand)"
             skipped=1 ;;
    esac
  elif [ ! -e "$target" ]; then
    drift=1
    case "$mode" in
      check)   echo "missing    $name" ;;
      dry-run) echo "would add  $name" ;;
      install)
        if cp -- "$src" "$target"; then echo "added      $name"
        else copy_failed "$name"; fi
        ;;
    esac
  elif [ -f "$target" ] && cmp -s -- "$src" "$target"; then
    echo "unchanged  $name"
  else
    drift=1
    case "$mode" in
      check)   echo "differs    $name" ;;
      dry-run)
        if [ "$force" -eq 1 ]; then echo "would replace $name (backup kept)"
        else echo "would skip $name (differs; --force replaces it)"; fi
        ;;
      install)
        if [ "$force" -eq 1 ]; then
          bak="$(backup_path "$target")"
          if cp -- "$target" "$bak" && cp -- "$src" "$target"; then
            echo "replaced   $name (backup: $(basename "$bak"))"
          else
            copy_failed "$name"
          fi
        else
          echo "skipped    $name (differs from the installed copy; --force replaces it)"
          skipped=1
        fi
        ;;
    esac
  fi
done

if [ "$mode" = "check" ]; then
  if [ "$drift" -eq 0 ]; then echo "in sync: $dest"; else echo "drift: $dest"; fi
  exit "$drift"
fi

if [ "$failed" -eq 1 ]; then
  echo >&2
  echo "install.sh: at least one file was NOT installed. Fix the error above and re-run." >&2
  exit 3
fi

if [ "$mode" = "install" ] && [ "$created_dir" -eq 1 ]; then
  echo
  echo "Created $dest. Claude Code only notices a new agents directory at"
  echo "session start: restart any open session before using these types."
fi

if [ "$mode" = "install" ]; then
  cat <<'EOF'

Not done by this script: the default subagent model. Add this to the "env"
block of ~/.claude/settings.json, so that a dispatch with no model named lands
on Sonnet and not on the parent session's model:

    "CLAUDE_CODE_SUBAGENT_MODEL": "sonnet"

Do not also set CLAUDE_CODE_SUBAGENT_MODEL_FORCE. It would pull the reviewer
type, and any explicit per-call model, down to Sonnet as well.
EOF
fi

[ "$skipped" -eq 1 ] && exit 2
exit 0
