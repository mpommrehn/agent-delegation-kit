#!/usr/bin/env bash
# Tests for the agent definitions and install.sh. Plain bash, no dependencies,
# so the same file runs on macOS, Linux and Git Bash on Windows.
#
#   bash tests/run-tests.sh
#
# Every install test runs against a throwaway directory. Nothing here touches
# the real ~/.claude.

set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install="$root/install.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pass=0
fail=0

ok()   { pass=$((pass + 1)); echo "ok    $1"; }
bad()  { fail=$((fail + 1)); echo "FAIL  $1"; [ $# -gt 1 ] && echo "      $2"; }

# check "name" expected-exit actual-exit
check_exit() {
  if [ "$2" -eq "$3" ]; then ok "$1"; else bad "$1" "expected exit $2, got $3"; fi
}

# frontmatter FILE: print the block between the first two '---' lines
frontmatter() { awk 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit} f' "$1"; }

# field FILE KEY: print the value of a top-level frontmatter key
field() { frontmatter "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -n 1; }

echo "== agent definitions"

count=0
for f in "$root"/agents/*.md; do
  count=$((count + 1))
  base="$(basename "$f" .md)"

  if [ "$(head -n 1 "$f")" = "---" ] && [ -n "$(frontmatter "$f")" ]; then
    ok "$base: has frontmatter"
  else
    bad "$base: has frontmatter"
    continue
  fi

  if [ "$(field "$f" name)" = "$base" ]; then ok "$base: name matches filename"
  else bad "$base: name matches filename" "name is '$(field "$f" name)'"; fi

  if [ -n "$(field "$f" description)" ]; then ok "$base: has a description"
  else bad "$base: has a description"; fi

  # The point of the kit: no definition may leave the model to inheritance by
  # omission. 'inherit' is allowed, but only when written down.
  model="$(field "$f" model)"
  case "$model" in
    sonnet|haiku|opus|fable|inherit) ok "$base: model is pinned ($model)" ;;
    "") bad "$base: model is pinned" "no model field: this type would inherit by accident" ;;
    *)  bad "$base: model is pinned" "unexpected value '$model'" ;;
  esac

  if [ -n "$(field "$f" maxTurns)" ]; then ok "$base: has a turn budget"
  else bad "$base: has a turn budget"; fi

  if grep -q '^## Stop-losses' "$f"; then ok "$base: prompt carries stop-losses"
  else bad "$base: prompt carries stop-losses"; fi

  if file "$f" 2>/dev/null | grep -q CRLF || grep -q $'\r' "$f"; then
    bad "$base: LF line endings" "CRLF found; frontmatter parsers can choke on it"
  else ok "$base: LF line endings"; fi
done

if [ "$count" -eq 4 ]; then ok "four agent types present"
else bad "four agent types present" "found $count"; fi

echo "== tiering policy"

for cheap in scanner browser-checker executor; do
  m="$(field "$root/agents/$cheap.md" model)"
  if [ "$m" = "sonnet" ] || [ "$m" = "haiku" ]; then ok "$cheap runs on a cheap tier ($m)"
  else bad "$cheap runs on a cheap tier" "model is '$m'"; fi
done

if [ "$(field "$root/agents/reviewer.md" model)" = "inherit" ]; then
  ok "reviewer inherits the parent's model"
else bad "reviewer inherits the parent's model"; fi

if [ "$(field "$root/agents/executor.md" isolation)" = "worktree" ]; then
  ok "executor is isolated in a worktree"
else bad "executor is isolated in a worktree"; fi

# Read-only types must not be able to reach the file-writing tools.
tools="$(field "$root/agents/scanner.md" tools)"
case "$tools" in
  *Write*|*Edit*) bad "scanner has no write tools" "tools: $tools" ;;
  "") bad "scanner has no write tools" "no tools allowlist, so it inherits every tool" ;;
  *) ok "scanner has no write tools" ;;
esac

for ro in browser-checker reviewer; do
  d="$(field "$root/agents/$ro.md" disallowedTools)"
  case "$d" in
    *Write*Edit*|*Edit*Write*) ok "$ro: Write and Edit are disallowed" ;;
    *) bad "$ro: Write and Edit are disallowed" "disallowedTools: '$d'" ;;
  esac
done

echo "== install.sh"

dest="$work/agents"

out="$(bash "$install" --dest "$dest" --dry-run 2>&1)"; rc=$?
check_exit "dry-run exits 0" 0 "$rc"
if [ ! -e "$dest" ]; then ok "dry-run creates nothing"
else bad "dry-run creates nothing" "$dest exists"; fi

out="$(bash "$install" --dest "$dest" --check 2>&1)"; rc=$?
check_exit "check reports drift before install" 1 "$rc"
if [ ! -e "$dest" ]; then ok "check creates nothing"
else bad "check creates nothing" "$dest exists"; fi

out="$(bash "$install" --dest "$dest" 2>&1)"; rc=$?
check_exit "fresh install exits 0" 0 "$rc"
if [ "$(ls "$dest"/*.md 2>/dev/null | wc -l)" -eq 4 ]; then ok "fresh install copies four files"
else bad "fresh install copies four files"; fi
case "$out" in *"restart"*) ok "fresh install warns that a new directory needs a restart" ;;
  *) bad "fresh install warns that a new directory needs a restart" ;; esac
case "$out" in *"CLAUDE_CODE_SUBAGENT_MODEL"*) ok "install prints the settings line" ;;
  *) bad "install prints the settings line" ;; esac

out="$(bash "$install" --dest "$dest" --check 2>&1)"; rc=$?
check_exit "check is clean after install" 0 "$rc"

out="$(bash "$install" --dest "$dest" 2>&1)"; rc=$?
check_exit "second install exits 0" 0 "$rc"
case "$out" in *"added"*|*"replaced"*) bad "second install changes nothing" "$out" ;;
  *) ok "second install changes nothing" ;; esac
case "$out" in *"restart any open session"*) bad "no restart warning when the directory existed" ;;
  *) ok "no restart warning when the directory existed" ;; esac

echo "local edit" >> "$dest/scanner.md"
before="$(cksum < "$dest/scanner.md")"

out="$(bash "$install" --dest "$dest" --check 2>&1)"; rc=$?
check_exit "check reports a locally edited file" 1 "$rc"

out="$(bash "$install" --dest "$dest" 2>&1)"; rc=$?
check_exit "install without --force exits 2 on a differing file" 2 "$rc"
if [ "$(cksum < "$dest/scanner.md")" = "$before" ]; then ok "a differing file is left alone without --force"
else bad "a differing file is left alone without --force"; fi

out="$(bash "$install" --dest "$dest" --force 2>&1)"; rc=$?
check_exit "install --force exits 0" 0 "$rc"
if cmp -s "$root/agents/scanner.md" "$dest/scanner.md"; then ok "--force replaces the differing file"
else bad "--force replaces the differing file"; fi
bak="$(ls "$dest"/scanner.md.bak-* 2>/dev/null | head -n 1)"
if [ -n "$bak" ] && grep -q "local edit" "$bak"; then ok "--force keeps the old copy as a backup"
else bad "--force keeps the old copy as a backup"; fi

out="$(bash "$install" --dest "$dest" --check 2>&1)"; rc=$?
check_exit "backups do not count as drift" 0 "$rc"

out="$(bash "$install" --bogus 2>&1)"; rc=$?
check_exit "unknown argument exits 64" 64 "$rc"
out="$(bash "$install" --dest 2>&1)"; rc=$?
check_exit "--dest with no value exits 64" 64 "$rc"

spaced="$work/dir with spaces/agents"
out="$(bash "$install" --dest "$spaced" 2>&1)"; rc=$?
check_exit "installs into a path with spaces" 0 "$rc"
if [ -f "$spaced/reviewer.md" ]; then ok "file present in the spaced path"
else bad "file present in the spaced path"; fi

if grep -Eq 'settings\.json' "$install" && ! grep -Eq '(>|>>|tee|sed -i|cp|mv)[^|]*settings\.json' "$install"; then
  ok "install.sh never writes settings.json"
else bad "install.sh never writes settings.json"; fi

echo "== public-repo hygiene"

# Tracked content must not carry a machine's paths, a user name, or an address.
# evidence/ and STATUS.md are gitignored and are allowed to.
hits="$(grep -rIlE '[A-Za-z]:\\+Users|/c/Users/|/Users/[a-z]+/|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[A-Za-z0-9._-]+@[A-Za-z0-9-]+\.(com|net|org)' \
  "$root" --exclude-dir=.git --exclude-dir=evidence --exclude=STATUS.md --exclude=run-tests.sh 2>/dev/null)"
if [ -z "$hits" ]; then ok "no local paths, IP addresses or email addresses in tracked files"
else bad "no local paths, IP addresses or email addresses in tracked files" "$hits"; fi

if [ -f "$root/$(basename "$root")-EVOLUTION.md" ]; then ok "evolution log is named after the directory"
else bad "evolution log is named after the directory"; fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
