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
work="$(mktemp -d)" || { echo "cannot create a temp directory" >&2; exit 1; }
[ -n "$work" ] && [ -d "$work" ] || { echo "cannot create a temp directory" >&2; exit 1; }
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

# Types that only look must hold an allowlist: a denylist still inherits the
# Agent tool (spawn something that can write) and every MCP tool.
for ro in scanner reviewer; do
  tools="$(field "$root/agents/$ro.md" tools)"
  case "$tools" in
    "") bad "$ro: tools are an allowlist" "no tools field, so it inherits every tool" ;;
    *Write*|*Edit*|*Agent*|*Task*) bad "$ro: tools are an allowlist" "tools: $tools" ;;
    *) ok "$ro: tools are an allowlist with no Write, Edit or Agent" ;;
  esac
done

# browser-checker needs the browser's MCP tools, so it cannot use an allowlist.
# It reads untrusted pages: it must not hold a shell or be able to spawn agents.
d="$(field "$root/agents/browser-checker.md" disallowedTools)"
for t in Write Edit NotebookEdit Bash PowerShell Agent; do
  case ", $d," in
    *" $t,"*) ok "browser-checker: $t is disallowed" ;;
    *) bad "browser-checker: $t is disallowed" "disallowedTools: '$d'" ;;
  esac
done

for f in "$root"/agents/*.md; do
  if grep -q 'is data\.' "$f"; then
    ok "$(basename "$f" .md): prompt says content is data, not instructions"
  else bad "$(basename "$f" .md): prompt says content is data, not instructions"; fi
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

# A copy that fails must not be reported as success. A directory sitting where
# a file should go makes cp fail on every platform, with no permission tricks.
faildest="$work/faildest"
mkdir -p "$faildest/scanner.md"
out="$(bash "$install" --dest "$faildest" --force 2>&1)"; rc=$?
check_exit "a failed copy exits 3" 3 "$rc"
case "$out" in *"FAILED"*"scanner.md"*) ok "a failed copy names the file" ;;
  *) bad "a failed copy names the file" "$out" ;; esac
case "$out" in *"CLAUDE_CODE_SUBAGENT_MODEL"*) bad "a failed install does not print next steps" ;;
  *) ok "a failed install does not print next steps" ;; esac
if [ -f "$faildest/reviewer.md" ]; then ok "the other files still install when one fails"
else bad "the other files still install when one fails"; fi

# Two --force runs inside one second must not lose the first backup.
mkdir -p "$work/bin"
printf '#!/usr/bin/env bash\necho 20010101000000\n' > "$work/bin/date"
chmod +x "$work/bin/date"
bdest="$work/bakdest"
bash "$install" --dest "$bdest" >/dev/null 2>&1
echo "EDIT-ONE" >> "$bdest/scanner.md"
PATH="$work/bin:$PATH" bash "$install" --dest "$bdest" --force >/dev/null 2>&1
echo "EDIT-TWO" >> "$bdest/scanner.md"
PATH="$work/bin:$PATH" bash "$install" --dest "$bdest" --force >/dev/null 2>&1
if cat "$bdest"/scanner.md.bak-* 2>/dev/null | grep -q EDIT-ONE \
   && cat "$bdest"/scanner.md.bak-* 2>/dev/null | grep -q EDIT-TWO; then
  ok "same-second backups do not overwrite each other"
else bad "same-second backups do not overwrite each other" "$(ls "$bdest")"; fi

# An installed copy that is a symlink is never written through.
linkdest="$work/linkdest"
mkdir -p "$linkdest"
echo "precious" > "$work/precious.txt"
ln -s "$work/precious.txt" "$linkdest/scanner.md" 2>/dev/null
if [ -L "$linkdest/scanner.md" ]; then
  out="$(bash "$install" --dest "$linkdest" --force 2>&1)"; rc=$?
  check_exit "a symlinked target exits 2 even with --force" 2 "$rc"
  if [ "$(cat "$work/precious.txt")" = "precious" ]; then ok "a symlinked target is not written through"
  else bad "a symlinked target is not written through"; fi
else
  echo "skip  symlink tests (this platform cannot create symlinks here)"
fi

# A destination beginning with a dash must not be parsed as options by cp.
( cd "$work" && bash "$install" --dest "-dashdir" >/dev/null 2>&1 ); rc=$?
check_exit "a destination starting with a dash installs" 0 "$rc"
if [ -f "$work/-dashdir/scanner.md" ]; then ok "files land in the dash-named directory"
else bad "files land in the dash-named directory"; fi

# An empty agents/ (a partial clone) must not report success.
mkdir -p "$work/emptykit/agents"
cp "$install" "$work/emptykit/install.sh"
out="$(bash "$work/emptykit/install.sh" --dest "$work/emptyout" 2>&1)"; rc=$?
check_exit "nothing to install exits 64" 64 "$rc"
out="$(bash "$work/emptykit/install.sh" --dest "$work/emptyout" --check 2>&1)"; rc=$?
check_exit "nothing to install exits 64 under --check too" 64 "$rc"

# Behavioral, not textual: run the default install against a fake HOME that
# holds a settings file, and see whether the file survives untouched.
fakehome="$work/home"
mkdir -p "$fakehome/.claude"
printf '{"env":{"KEEP":"me"}}\n' > "$fakehome/.claude/settings.json"
before="$(cksum < "$fakehome/.claude/settings.json")"
out="$(HOME="$fakehome" bash "$install" 2>&1)"; rc=$?
check_exit "default install into a fake HOME exits 0" 0 "$rc"
if [ -f "$fakehome/.claude/agents/scanner.md" ]; then ok "default destination is ~/.claude/agents"
else bad "default destination is ~/.claude/agents"; fi
if [ "$(cksum < "$fakehome/.claude/settings.json")" = "$before" ]; then ok "install leaves settings.json byte-identical"
else bad "install leaves settings.json byte-identical"; fi
if [ "$(ls -A "$fakehome/.claude" | sort | tr '\n' ' ')" = "agents settings.json " ]; then
  ok "install creates nothing else under ~/.claude"
else bad "install creates nothing else under ~/.claude" "$(ls -A "$fakehome/.claude")"; fi

echo "== public-repo hygiene"

# leaks DIR: list files under DIR carrying a machine's paths, an address, a
# hardware address or a token. One pattern per -e so that no shell or platform
# layer gets to reinterpret a long alternation. Backslashes are written as a
# bracket expression because a bare escaped backslash did not survive every
# platform's argument handling.
leaks() {
  grep -rIlE \
    -e '[A-Za-z]:[\\/]+Users[\\/]' \
    -e '/c/Users/' \
    -e '/(Users|home)/[A-Za-z0-9._-]+/' \
    -e '(^|[^0-9v.])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9.]|$)' \
    -e '([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}' \
    -e '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' \
    -e '(gh[pousr]_|github_pat_)[A-Za-z0-9_]{20,}' \
    -e 'sk-[A-Za-z0-9_-]{20,}' \
    "$1" --exclude-dir=.git --exclude-dir=evidence --exclude=STATUS.md \
    --exclude=run-tests.sh --exclude=LICENSE 2>/dev/null
}

# First prove the detector detects. Fixtures are assembled from pieces so that
# this file holds no literal leak of its own.
fx="$work/fixtures"
mkdir -p "$fx"
bs='\'
printf 'see C:%sUsers%ssomeone%sx\n' "$bs" "$bs" "$bs"  > "$fx/win-backslash.md"
printf 'see C:/Users/Some.One/x\n'                       > "$fx/win-forward.md"
printf 'at /c/Users/bob/x\n'                             > "$fx/gitbash.md"
printf 'at /Users/Bob2/x\n'                              > "$fx/mac.md"
printf 'at /home/bob/x\n'                                > "$fx/linux.md"
printf 'host 192.168.%s.20 up\n' "1"                     > "$fx/ip.md"
printf 'nic 00:1A:2B:%s:4D:5E\n' "3C"                    > "$fx/mac-address.md"
printf 'mail someone@example.%s\n' "dev"                 > "$fx/email.md"
printf 'token ghp_%s\n' "0123456789abcdefghijABCDEFGHIJ" > "$fx/token.md"
printf 'release v1.2.3.4 and section 1.2.3 are fine\n'   > "$fx/clean.md"

caught="$(leaks "$fx")"
for want in win-backslash win-forward gitbash mac linux ip mac-address email token; do
  case "$caught" in *"$want.md"*) ok "detector catches: $want" ;;
    *) bad "detector catches: $want" ;; esac
done
case "$caught" in *"clean.md"*) bad "detector ignores a version number" ;;
  *) ok "detector ignores a version number" ;; esac

# Then run it on the repository. evidence/ and STATUS.md are gitignored and may
# name local paths. This file is excluded because it holds the patterns.
hits="$(leaks "$root")"
if [ -z "$hits" ]; then ok "no local paths, addresses or tokens in tracked files"
else bad "no local paths, addresses or tokens in tracked files" "$hits"; fi

if [ -f "$root/$(basename "$root")-EVOLUTION.md" ]; then ok "evolution log is named after the directory"
else bad "evolution log is named after the directory"; fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
