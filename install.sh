#!/usr/bin/env bash
# Install the agent definitions in agents/ into a Claude Code agents directory.
#
#   ./install.sh                 copy into ~/.claude/agents
#   ./install.sh --check         report drift; write nothing; exit 1 on any drift
#   ./install.sh --dry-run       say what would happen; write nothing
#   ./install.sh --force         replace files that differ, keeping a .bak copy
#   ./install.sh --dest DIR      install somewhere else (a project's .claude/agents)
#
# Never edits settings.json. It prints the two lines to add instead, because a
# settings file holds things this script has no business rewriting.
#
# Exit codes: 0 done or in sync, 1 drift found by --check, 2 a differing file
# was left alone (re-run with --force), 64 bad usage.

set -u

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agents"
dest="${HOME}/.claude/agents"
mode="install"
force=0

usage() { sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

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

if [ ! -d "$src_dir" ]; then
  echo "install.sh: no agents directory at $src_dir" >&2
  exit 64
fi

created_dir=0
if [ ! -d "$dest" ]; then
  if [ "$mode" = "install" ]; then
    mkdir -p "$dest" || { echo "install.sh: cannot create $dest" >&2; exit 64; }
  fi
  created_dir=1
fi

drift=0
skipped=0
stamp="$(date +%Y%m%d%H%M%S)"

for src in "$src_dir"/*.md; do
  [ -e "$src" ] || continue
  name="$(basename "$src")"
  target="$dest/$name"

  if [ ! -e "$target" ]; then
    drift=1
    case "$mode" in
      check)   echo "missing    $name" ;;
      dry-run) echo "would add  $name" ;;
      install) cp "$src" "$target" && echo "added      $name" ;;
    esac
  elif cmp -s "$src" "$target"; then
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
          cp "$target" "$target.bak-$stamp" && cp "$src" "$target" \
            && echo "replaced   $name (backup: $name.bak-$stamp)"
        else
          echo "skipped    $name (differs from the installed copy; --force replaces it)"
          skipped=1
        fi
        ;;
    esac
  fi
done

if [ "$mode" = "check" ]; then
  [ "$drift" -eq 0 ] && echo "in sync: $dest" || echo "drift: $dest"
  exit "$drift"
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
