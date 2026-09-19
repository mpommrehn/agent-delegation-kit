# agent-delegation-kit

Four Claude Code subagent definitions, a brief template and an install script.
Together they make one rule mechanical: **routine delegated work runs on a cheap
model, and judgment does not.**

## The problem

A Claude Code subagent that is dispatched with no model named, to an agent type
that pins none, runs on the parent session's model. If the parent is your most
capable and most expensive model, so is the subagent that was sent to count the
rows in a CSV.

This kit came out of exactly that. A project's instructions said "Sonnet is the
default executor." Nothing enforced the sentence. A delegation to read a 6.3 MB
file ran on the top-tier model and spent 74,000 tokens on `wc` and `grep`. The
delegation itself was right, because the file stayed out of the main context
window. Only the tiering failed, and it failed because it was prose.

Rules for an agent live in three layers:

1. **Prose**, in `CLAUDE.md` or `AGENTS.md`. Enforced by the model remembering.
2. **Harness configuration**, in `settings.json`: hooks, permissions,
   environment. Enforced before the model sees anything.
3. **Agent definitions**, in `.claude/agents/*.md`. Enforced by the harness
   whenever that type is dispatched.

A rule that costs money when forgotten belongs in layer 2 or 3. This kit moves
model tiering there.

## What is in it

| Type | Model | For | Mechanism |
|---|---|---|---|
| `scanner` | sonnet | Logs, CSVs, telemetry, unfamiliar directories. Conclusions only. | Tool allowlist (Read, Grep, Glob, Bash), turn budget, skips `CLAUDE.md` |
| `browser-checker` | sonnet | Open a page, check a written list, report a paragraph. | No shell, no file editing, no spawning agents. Turn budget, skips `CLAUDE.md` |
| `executor` | sonnet | Mechanical, specified, tested work. | Git worktree isolation, turn budget, evidence-file contract |
| `reviewer` | inherit | Judging a diff, a plan or an evidence file. | Tool allowlist (Read, Grep, Glob, Bash). Deliberately stays on the parent's model |

Read "What the tool limits do not do" below before trusting any of these with
something that matters.

Also `templates/BRIEF-TEMPLATE.md`: the test for whether work should be
delegated at all, and the brief to write when it should.

`scanner` and `browser-checker` set `omitClaudeMd: true`. An agent sent to
count rows does not need a project's full governance file in its context. Each
carries a short copy of the stop-losses in its own prompt instead. That is a
second copy that can drift. It is a trade made on purpose, and the prompts say
that a brief overrides them.

## Install

```
git clone https://github.com/mpommrehn/agent-delegation-kit
cd agent-delegation-kit
bash tests/run-tests.sh
./install.sh
```

`install.sh` copies `agents/*.md` into `~/.claude/agents/`. It leaves a file
that differs from the installed copy alone unless you pass `--force`, which
keeps a timestamped backup. `--check` reports drift and writes nothing.
`--dest DIR` installs into a single project's `.claude/agents/` instead.

User level is the default because a session started in any directory finds
the types there. A project-level copy takes precedence over a user-level one
of the same name, which is how to specialize a type for one project.

Two things the script does not do:

1. **Restart.** Claude Code picks up new and changed agent files within
   seconds, but it notices a brand-new `agents` directory only at session
   start. After a first install, restart any open session.
2. **Set the default model.** Add this to the `env` block of
   `~/.claude/settings.json`:

   ```json
   { "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "sonnet" } }
   ```

   The script never edits a settings file. Yours holds things it has no
   business rewriting.

## How the model gets chosen

Claude Code resolves a subagent's model in this order:

1. The `model` parameter on the dispatch itself
2. The `model` field in the agent definition, including `inherit`
3. The `CLAUDE_CODE_SUBAGENT_MODEL` environment variable
4. The parent session's model

The kit uses levels 2 and 3 together. The definitions pin the named types. The
environment variable catches what is left: a `general-purpose` dispatch where
the model was forgotten, which is the failure this began with.

Do not set `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`. It overrides the whole order,
so the `reviewer` type and every explicit per-call model would be pulled down
to the default too. Without it, the default is a floor you can step above on
purpose.

## Known gaps

- **The built-in `Explore` type ignores the environment variable** and runs on
  the parent's model. Use `scanner` instead. You can shadow a built-in with a
  definition of the same name, but then you own a prompt that the vendor
  maintains, and this kit chose not to.
- **A fork always inherits the parent's model.** No configuration changes it.
- **Level 1 outranks level 2.** A dispatch that names an expensive model
  explicitly gets it, even for `scanner`. The kit prevents forgetting. It does
  not prevent a decision.
- The default now fails in the other direction: review work dispatched with no
  model named and no `reviewer` type lands on the cheap tier, and a quality
  loss is harder to see than a token bill. Dispatch judgment work as `reviewer`.

## What the tool limits do not do

None of these types is a sandbox. An independent review of this kit found the
first version calling types "read-only" that were not, so here is what each
limit is worth.

- **`scanner` and `reviewer` hold a shell.** They need one, for `awk` and `wc`
  and for re-running tests, and a shell can write, delete and reach the
  network. Their allowlist withholds the editing tools, the Agent tool (so
  they cannot spawn something less restricted) and every MCP tool. Not
  writing through the shell is an instruction in the prompt and nothing more.
- **`browser-checker` reads pages nobody here controls**, in a browser that may
  be logged in to your accounts. It has no shell, no editing tools and no
  Agent tool. It does have the browser's own tools, page scripting among
  them, because it cannot work without them. Its defense against a page that
  says "ignore your instructions" is its prompt. Do not point it at a hostile
  page from a browser profile that is logged in to anything you care about.
  It uses a denylist, not an allowlist, because it needs MCP tools whose
  names vary by setup. A tool added to your setup later is one it inherits.
- **`executor`'s worktree isolates git, not the filesystem.** Its shell can
  reach anything your user can.
- **`executor` is told not to push or merge, and nothing enforces that.** Its
  prompt applies separation of duties: commit on the worktree branch only,
  and leave integration to the dispatching session or a human who has read
  the diff. In a commercial setting the real control is a protected default
  branch with required review, and an agent that holds no push credential.
  Set those up on the server; do not rely on the prompt.
- A permission prompt, if your setup shows one, is still the real control.
  These definitions reduce what an agent reaches for by accident. They do not
  stop one that has been talked into something.

## Prove which model ran

Do not take an agent's word for it, and do not take this README's. Each
subagent's transcript records the model on every turn:

```
~/.claude/projects/<project-slug>/<session-id>/subagents/agent-<id>.jsonl
```

```
grep -o '"model":"[^"]*"' agent-<id>.jsonl | sort | uniq -c
```

One model name, with a count, is a pass.

## Status

`scanner` and `browser-checker` are the two types this kit was first built to
use. `executor` and `reviewer` are defined and tested for shape, and had not
been exercised on real work when this was written. In particular,
`isolation: worktree` has not been tried from a directory that is not a git
repository. The evolution log says what has been verified since.

The behavior described under "How the model gets chosen" and "Known gaps" comes
from the Claude Code subagent documentation as read on 2026-09-18. Check it
against the current documentation before relying on it.

## Tests

```
bash tests/run-tests.sh
```

Plain bash with no dependencies. It checks that every definition pins a model
in writing, has a turn budget and carries stop-losses; that the looking-only
types hold an allowlist and `browser-checker` has no shell; that `install.sh`
is idempotent, never clobbers a local edit without `--force`, never writes
through a symlink, never reports a failed copy as success, writes nothing in
`--check` or `--dry-run`, and leaves a settings file byte-identical; and that
no tracked file carries a local path, an address or a token. The leak detector
is first run against planted fixtures, so a broken pattern fails loudly and
does not pass quietly. The symlink tests skip where the platform cannot create
symlinks, which includes Git Bash on Windows without Developer Mode.

`install.sh` exit codes: 0 done or in sync, 1 drift under `--check`, 2 a file
was left alone, 3 a copy failed, 64 bad usage or nothing to install.

## License

Apache-2.0. See `LICENSE`.
