# AGENTS.md: agent-delegation-kit

Subagent definitions, a brief template and an install script that make model
tiering mechanical in Claude Code. Public repository. `README.md` is the full
description.

Claude Code reads this file through `CLAUDE.md`, whose entire contents are the
import line for this file. Do not replace that import with a symlink or a hard
link.

## Ground truth

Read these at session start, in this order:

1. `agent-delegation-kit-EVOLUTION.md`: the construction and evolution log.
   Why each decision was made, what was considered and rejected, what has
   been verified. **Append one entry per session**, newest at the bottom.
2. `STATUS.md`, if present. Gitignored, machine-local: done, not done, exact
   next action.
3. `README.md`, section "Known gaps", before changing any definition.

## Rules for working here

- **This repository is public.** No credentials, tokens, IP or MAC addresses,
  email addresses, other people's names, or local filesystem paths in any
  tracked file, the evolution log included. `tests/run-tests.sh` checks for
  the mechanical cases. It is a floor.
- `evidence/` is gitignored. Verification transcripts name local paths and
  belong there, not in the log.
- Every agent definition pins `model` in writing. `inherit` is a legitimate
  value. An absent field is not: it is the accident this kit exists to prevent.
- A claim about how Claude Code resolves models, loads agents or runs hooks
  needs a source: the vendor documentation with the date read, or a transcript
  check. Mark anything else as unverified, in the README's "Known gaps".
- `install.sh` never edits a settings file.
- Run `bash tests/run-tests.sh` before every commit. When adding a check, prove
  it can fail: break a throwaway copy and watch the test catch it.
- Line endings are LF everywhere (`.gitattributes`). Never round-trip a file
  through a script to make a small edit.
