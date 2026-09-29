#!/usr/bin/env python3
"""Post-hoc checker for a finished subagent transcript.

    check_run.py <transcript.jsonl> [--meta PATH] [--json]

Reads the transcript and its sibling .meta.json (or --meta) and flags known
failure classes. Output is one line per finding, "FAIL|WARN <check-id>
<message>", then a summary line.

Exit codes: 0 no FAIL, 1 at least one FAIL, 2 usage or parse error.

Python 3.9+, standard library only.

To add a check: write one function `check_xxx(run)` that returns a list of
Finding, and append it to CHECKS. `run` is a Run (see below).
"""

import json
import os
import re
import sys
from collections import namedtuple

Finding = namedtuple("Finding", "level check message")


class Run:
    """A parsed transcript."""

    def __init__(self, records, meta):
        self.records = records  # list of dicts, in file order
        self.meta = meta  # dict, or None when missing or unreadable
        self.segments = split_segments(records)

    @property
    def agent_type(self):
        return (self.meta or {}).get("agentType")

    @property
    def meta_model(self):
        return (self.meta or {}).get("model")


def _content(rec):
    msg = rec.get("message")
    if isinstance(msg, dict):
        return msg.get("content")
    return None


def is_segment_start(rec):
    """A user line whose content is a plain string, and not isMeta."""
    return (
        rec.get("type") == "user"
        and not rec.get("isMeta")
        and isinstance(_content(rec), str)
    )


def tool_uses(rec):
    """The tool_use blocks of an assistant record."""
    if rec.get("type") != "assistant":
        return []
    content = _content(rec)
    if not isinstance(content, list):
        return []
    return [b for b in content if isinstance(b, dict) and b.get("type") == "tool_use"]


def split_segments(records):
    """Split records into segments. Each starts at a string-content user line
    (the brief, or a resume). Records before the first such line form a
    segment of their own."""
    segments = []
    current = None
    for rec in records:
        if is_segment_start(rec) or current is None:
            current = []
            segments.append(current)
        current.append(rec)
    return segments


# ---------------------------------------------------------------- checks


def check_no_handback(run):
    """FAIL for any segment with tool calls that does not end with a
    SubagentHandback tool_use."""
    out = []
    for i, seg in enumerate(run.segments, 1):
        calls = [b for rec in seg for b in tool_uses(rec)]
        if not calls:
            continue
        if calls[-1].get("name") != "SubagentHandback":
            out.append(
                Finding(
                    "FAIL",
                    "no-handback",
                    "segment %d has %d tool_use call(s) and does not end with "
                    "SubagentHandback (last call: %s)"
                    % (i, len(calls), calls[-1].get("name")),
                )
            )
    return out


PINNED_TYPES = ("executor", "scanner", "browser-checker")
UNPINNED_TYPES = ("general-purpose", "Explore")


def check_model_tier(run):
    """Executor, scanner and browser-checker must run on sonnet (or on the
    model pinned in meta). Unpinned general-purpose or Explore agents should
    not run on a frontier model."""
    atype = run.agent_type
    if atype is None:
        return []
    counts = {}
    for rec in run.records:
        if rec.get("type") != "assistant":
            continue
        msg = rec.get("message")
        model = msg.get("model") if isinstance(msg, dict) else None
        if not model or model == "<synthetic>":
            continue
        counts[model] = counts.get(model, 0) + 1

    out = []
    if atype in PINNED_TYPES:
        want = run.meta_model or "sonnet"
        for model, n in sorted(counts.items()):
            if want not in model:
                out.append(
                    Finding(
                        "FAIL",
                        "model-tier",
                        "%s ran %d turn(s) on %s, expected a model containing '%s'"
                        % (atype, n, model, want),
                    )
                )
    elif atype in UNPINNED_TYPES and not run.meta_model:
        for model, n in sorted(counts.items()):
            if "opus" in model or "fable" in model:
                out.append(
                    Finding(
                        "WARN",
                        "model-tier",
                        "unpinned agent on frontier model: %s ran %d turn(s) on %s"
                        % (atype, n, model),
                    )
                )
    return out


_SPLIT = re.compile(r"&&|\|\||;|\|")
_TAG_READ_FLAGS = ("-l", "--list", "--contains", "--no-contains", "--points-at",
                   "--merged", "--no-merged", "--sort", "--format", "-v", "--verify")
_GLOBAL_WITH_ARG = ("-C", "-c", "--git-dir", "--work-tree")
_GLOBAL_FLAGS = ("--no-pager", "-P", "--no-optional-locks")
_REDIR = re.compile(r"^\d*[<>]")


def _strip_redirs(toks):
    """Drop redirection tokens (2>&1, >file, 2>/dev/null, a bare > or < and
    the word after it)."""
    out, skip = [], False
    for t in toks:
        if skip:
            skip = False
            continue
        if _REDIR.match(t):
            if re.fullmatch(r"\d*(>>?|<)", t):
                skip = True
            continue
        out.append(t)
    return out


def git_verb(sub):
    """(verb, args) for the first `git` in a sub-command, skipping global
    options (-C x, -c x, --git-dir[=]x, --work-tree[=]x, --no-pager, -P,
    --no-optional-locks). Redirections are removed from args. (None, []) when
    the sub-command holds no git verb."""
    toks = sub.split()
    for i, t in enumerate(toks):
        if t != "git":
            continue
        j = i + 1
        while j < len(toks):
            g = toks[j]
            if g in _GLOBAL_WITH_ARG:
                j += 2
            elif g.startswith(("--git-dir=", "--work-tree=")) or g in _GLOBAL_FLAGS:
                j += 1
            else:
                break
        if j < len(toks):
            return toks[j].strip("\"'"), _strip_redirs(toks[j + 1:])
        return None, []
    return None, []


def _tag_creates(args):
    """git tag: True when the arguments would create (or alter) a tag."""
    for a in args:
        if a in _TAG_READ_FLAGS or a.startswith(("--list", "--sort", "--format")):
            return False
        if re.fullmatch(r"-n\d*", a):
            return False
    if any(a in ("-a", "-s", "-m", "-f", "-u", "-d") for a in args):
        return True
    return any(not a.startswith("-") for a in args)


def forbidden_reason(sub):
    """Name of the forbidden pattern a single sub-command matches, or None."""
    s = sub.strip()
    low = s.lower()
    verb, args = git_verb(s)
    if verb == "push":
        return "git push"
    if verb == "merge":
        return "git merge"
    if verb == "tag" and _tag_creates(args):
        return "git tag (creates a tag)"
    # Whole-tree restores always flag. Single-path restores are judged by
    # check_discarded_work instead.
    kind, paths = restore_paths(s)
    if kind and "." in paths and not (kind == "restore" and "--staged" in s):
        return "git %s . (discards the whole tree)" % kind
    if verb == "reset" and "--hard" in args:
        return "git reset --hard"
    if verb == "clean" and any(re.fullmatch(r"-\w*f\w*", a) or a == "--force" for a in args):
        return "git clean -f"
    if re.search(r"\bpkill\b.*\s-\w*f", s):
        return "pkill -f"
    if re.search(r"\btaskkill\b.*\s/im\b", low):
        return "taskkill /IM"
    if "commandline -like" in low:
        return "CommandLine -like"
    return None


def restore_paths(sub):
    """(kind, paths) for a `git checkout -- ...` / `git checkout .` /
    `git restore ...` sub-command, else (None, [])."""
    verb, rest = git_verb(sub)
    if verb == "checkout":
        if "--" in rest:
            return "checkout", rest[rest.index("--") + 1:]
        if rest == ["."]:
            return "checkout", ["."]
    elif verb == "restore":
        return "restore", [a for a in rest if not a.startswith("-")]
    return None, []


def _norm(p):
    p = p.strip("\"'").replace("\\", "/").lower()
    while p.startswith("./"):
        p = p[2:]
    return p


def _same_file(edited, restored):
    e, r = _norm(edited), _norm(restored)
    return bool(r) and (e == r or e.endswith("/" + r))


def check_discarded_work(run):
    """WARN when a single-path `git checkout -- <path>` or `git restore <path>`
    (no --staged) hits a file that an Edit or Write tool_use touched since the
    most recent Bash `git commit` (or since segment start).

    Intent is not in the transcript: a teeth-proof re-break looks identical to
    lost work, so this is a prompt for human review, not a failure.

    Known limit: Bash-side edits (sed -i, >, tee) are invisible here, so this
    can miss discarded work. It errs toward not flagging."""
    out = []
    for seg in run.segments:
        pending = []  # file paths edited since the last commit
        for rec in seg:
            for b in tool_uses(rec):
                inp = b.get("input") if isinstance(b.get("input"), dict) else {}
                name = b.get("name")
                if name in ("Edit", "Write") and isinstance(inp.get("file_path"), str):
                    pending.append(inp["file_path"])
                elif name == "Bash" and isinstance(inp.get("command"), str):
                    for sub in _SPLIT.split(inp["command"]):
                        if git_verb(sub)[0] == "commit":
                            pending = []
                            continue
                        kind, paths = restore_paths(sub)
                        if not kind or (kind == "restore" and "--staged" in sub):
                            continue
                        for p in paths:
                            if p != "." and any(_same_file(e, p) for e in pending):
                                out.append(
                                    Finding(
                                        "WARN",
                                        "discarded-work",
                                        "restore discarded uncommitted edits to %s" % p,
                                    )
                                )
    return out


def check_forbidden_command(run):
    """FAIL for Bash commands an agent must never run. Splits on && ; || |
    and matches each piece, so `git log | grep push` does not flag. Quotes
    are not parsed: `echo "do not git push"` flags (documented, accepted)."""
    out = []
    for rec in run.records:
        for b in tool_uses(rec):
            if b.get("name") != "Bash":
                continue
            inp = b.get("input")
            cmd = inp.get("command") if isinstance(inp, dict) else None
            if not isinstance(cmd, str):
                continue
            for sub in _SPLIT.split(cmd):
                why = forbidden_reason(sub)
                if why:
                    shown = cmd if len(cmd) <= 120 else cmd[:117] + "..."
                    out.append(
                        Finding("FAIL", "forbidden-command", "%s: %s" % (why, shown))
                    )
                    break
    return out


CHECKS = [
    check_no_handback,
    check_model_tier,
    check_forbidden_command,
    check_discarded_work,
]

# ------------------------------------------------------------------ main


def load(path, meta_path):
    """Return (run, warnings). Raises OSError or ValueError on a fatal problem."""
    warnings = []
    records = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for n, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                warnings.append(Finding("WARN", "parse", "line %d is not valid JSON; skipped" % n))
                continue
            if not isinstance(rec, dict):
                warnings.append(Finding("WARN", "parse", "line %d is not a JSON object; skipped" % n))
                continue
            records.append(rec)
    if not records:
        raise ValueError("no valid JSON records in %s" % path)

    meta = None
    if meta_path is None:
        base = path[:-6] if path.endswith(".jsonl") else path
        meta_path = base + ".meta.json"
    try:
        with open(meta_path, "r", encoding="utf-8") as fh:
            meta = json.load(fh)
        if not isinstance(meta, dict):
            warnings.append(Finding("WARN", "meta", "meta file is not a JSON object; ignored"))
            meta = None
    except FileNotFoundError:
        warnings.append(Finding("WARN", "meta", "no meta file found; agent-type checks skipped"))
    except (OSError, ValueError):
        warnings.append(Finding("WARN", "meta", "meta file unreadable; agent-type checks skipped"))
    return Run(records, meta), warnings


def main(argv):
    args = list(argv)
    as_json = False
    meta_path = None
    paths = []
    while args:
        a = args.pop(0)
        if a == "--json":
            as_json = True
        elif a == "--meta":
            if not args:
                print("usage: check_run.py <transcript.jsonl> [--meta PATH] [--json]", file=sys.stderr)
                return 2
            meta_path = args.pop(0)
        elif a.startswith("--"):
            print("unknown option: %s" % a, file=sys.stderr)
            return 2
        else:
            paths.append(a)
    if len(paths) != 1:
        print("usage: check_run.py <transcript.jsonl> [--meta PATH] [--json]", file=sys.stderr)
        return 2

    try:
        run, findings = load(paths[0], meta_path)
    except (OSError, ValueError) as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 2

    for check in CHECKS:
        findings.extend(check(run))

    fails = sum(1 for f in findings if f.level == "FAIL")
    warns = sum(1 for f in findings if f.level == "WARN")
    if as_json:
        print(
            json.dumps(
                {
                    "findings": [f._asdict() for f in findings],
                    "summary": {"fail": fails, "warn": warns},
                },
                indent=2,
            )
        )
    else:
        for f in findings:
            print("%s %s %s" % (f.level, f.check, f.message))
        print("SUMMARY %d FAIL, %d WARN" % (fails, warns))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
