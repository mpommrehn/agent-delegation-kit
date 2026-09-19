# agent-delegation-kit: construction and evolution log

How this project was defined, built and extended, with the reasoning. One entry
per working session, newest at the bottom. Not a changelog (git has that) and
not a status document. Public, and written that way from the first line.

---

## 2026-09-17 and 2026-09-18, sessions 0 and 1: the finding, then a plan

*Reconstructed on 2026-09-18 from the plan file and the memory note those
sessions left. No transcript was re-read.*

**What happened.** During unrelated work on a Windows machine, the agent
delegated the reading of a 6.3 MB CSV to a `general-purpose` subagent with no
model named. It ran on the parent's top-tier model: 74,381 tokens, 15 tool
calls, 306 seconds, to count rows and grep an event log. The delegation was
correct, since the file never entered the main window. The tiering was not.

**The finding.** Mark's working instructions said "Sonnet is the default
executor." A check of the disk showed nothing behind the sentence: no agents
directory at user or project level, no default subagent model, and a settings
file that named a model for the main session only. The same instructions had
screenshot rules backed by a `PreToolUse` hook. Model tiering had only ever had
the prose. The session named three layers (prose, harness configuration, agent
definitions) and the question that follows from them: which other prose-only
rules cost enough when forgotten to deserve a mechanism?

**Decision, Mark's.** Do not fix it at the end of a long session. The agent
wrote a plan with three proposals (a per-call override, named agent
definitions, a default subagent model) and four open questions, and applied
nothing. The instructions in force say a durable-configuration change is
proposed, never applied unasked.

---

## 2026-09-18, session 2: decisions, and the kit is built

**Goal, in Mark's words.** "I want to examine the plan with you and improve it,
then copy the improved and implemented plan to the D drive to go to the Mac,
and likely commit it to GH." Narrowed later the same session: "make it cheaper
as well as well-judged on completing some work on the Goldshell project that's
already queued ... make it 'pretty good here' and put in the small repo," with
the larger delegation and management design to follow on another machine.

**What the agent found wrong with its predecessor's plan.**

- It did not know about a delegation ladder Mark had already agreed four days
  earlier, which answered two of its four open questions (which types; whether
  the smallest model has a place) and named a brief template as a thing to
  build.
- It claimed that a named type "cannot" land on the expensive model. False: a
  per-call model outranks the definition's.
- It left the settings key for a default subagent model unverified, correctly,
  and said so.
- It placed everything at project level. The project that needed the fix first
  is launched from directories two levels below the one holding the
  configuration, and nothing verified that definitions would be found from
  there.

**Facts that changed the design.** A Sonnet subagent read the vendor
documentation and returned each answer marked verified or not documented.

- The default is an environment variable, `CLAUDE_CODE_SUBAGENT_MODEL`. There
  is no settings key for it.
- Precedence: per-call model, then definition, then the variable, then the
  parent. A companion `_FORCE` variable overrides the whole order.
- Definitions accept `maxTurns`, `isolation` and `omitClaudeMd`. Two parts of
  the agreed ladder, the turn budget and the worktree, could therefore be
  mechanism and not sentences in a brief.
- The built-in `Explore` type ignores the default. A fork always inherits.
- A brand-new agents directory is noticed only at session start.

One fact was found by looking, not reading: a subagent's transcript records
the model on every turn. The lookup subagent itself, dispatched with a per-call
Sonnet override, showed the Sonnet model ID on all 19 turns while the main
transcript showed the top-tier one. That became the verification method. The
output file the harness advertises for a subagent was empty. The transcript
sits under the session's `subagents` directory.

**Decisions.**

| Question | Decision | By | Why |
|---|---|---|---|
| Home for the files | A new small public repository | Mark | Same pattern as his style-guide skill. Portable to the other machine. The alternative, a folder in an existing undo-tooling repository, mixed two concerns |
| Default subagent model | Sonnet, without FORCE | Mark, on the agent's recommendation | Catches the forgotten model. FORCE would also demote deliberate review work |
| Scope | Default, four types, brief template, measured trial of the smallest model, transcript demonstration | Mark | A three-strikes edit hook and a sweep for other prose-only rules were split off as the next gate. The agent argued they were a second gate, and Mark agreed |
| `Explore` gap | Document it, use `scanner` | Mark, after asking for the options to be explained again | Shadowing a built-in means owning a vendor's prompt |
| Install location | User level | Agent, stated before building | Removes the launch-directory question and makes the install identical on every machine |
| Stop-losses copied into prompts | Yes, short form, in the two types that skip `CLAUDE.md` | Agent | A row-counting agent should not load a long governance file. The cost is a second copy that can drift, and the README says so |
| Smallest model for `scanner` | Measure first | Agent | Same scan on both models, compare tokens and conclusions, then Mark decides |

**Accepted risk, named at the time.** With a cheap default, the failure flips.
A forgotten override used to cost tokens, which shows up on a bill. Now it
costs quality, which does not show up anywhere. The `reviewer` type exists so
that judgment work is a named thing to reach for, not a flag to remember.

**Pushback, in both directions.** The agent put its four questions into a
multiple-choice dialog. Mark had asked for a conversation and said the dialog's
free-text paths "REALLY aren't working." The questions were re-asked as
numbered plain text, and the dialog tool was denied in his user settings: the
project's own thesis, applied to its author within the hour. In the other
direction, the agent declined to edit the shared working instructions on this
machine, because Mark had decided days earlier that their restructure happens
elsewhere. The pointer line travels as a proposed patch.

**Built.** Four definitions, a brief template, `install.sh` (idempotent, never
clobbers a local edit without `--force`, never touches a settings file), and a
bash test suite. The suite was itself tested by mutation: a throwaway copy with
a model field deleted and a tool restriction loosened was caught. A planted
Windows path was **not**. The hygiene regex demanded a doubled backslash. It was
fixed, and six leak payloads were then each caught. A test that has never been
seen to fail has not been shown to work.

**Left out, on purpose.** The three-strikes edit hook. A `PreToolUse` hook on
the dispatch tool that would refuse an unpinned dispatch: what such a hook can
see is undocumented, and it needs a probe first. Any rewrite of the delegation
rules themselves, which came from real incidents and are sound.

**Not yet verified.** Whether the settings `env` block delivers the variable.
Whether user-level types are found from a nested project directory. `executor`
and `reviewer` on real work. `isolation: worktree` from a directory that is not
a git repository. Verification is deliberately a fresh session's job. The
maker's session cannot do it in any case, because a new agents directory needs
a restart.

---

## 2026-09-18, session 2, continued: the security review, and what it changed

**Policy applied.** The working instructions call for one security pass at
feature-complete, not one per edit. It ran once, before the first push, in a
fresh-context subagent pinned explicitly to the top-tier model: the agreed
ladder keeps security review off the cheap tier, and the maker of a thing does
not review it. Cost: 68,000 tokens, 11 tool calls, two and a half minutes.

**What it found that the maker had missed.**

- **A failed copy exited 0.** The reviewer shimmed `cp` to fail for one file of
  four. The installer printed three "added" lines and its next-steps banner and
  reported success. A full disk or a locked file would have left a user
  believing a type existed that did not. The script ran under `set -u` with no
  check on `cp`.
- **Two "read-only" types were not.** `browser-checker` and `reviewer` used a
  denylist of the editing tools. They still inherited the shell, the Agent
  tool (so they could spawn an unrestricted subagent that does have Write) and
  every MCP tool. `browser-checker` is the type that reads untrusted web pages,
  and it held a shell. The README admitted the weakness for `scanner` only.
- **Two tests could not fail.** The check that the installer never writes a
  settings file was a text match for a redirect on the same line as the
  filename. The reviewer appended a real write through a variable, and it
  passed. The leak detector missed forward-slash Windows paths, home
  directories with capitals or digits, Linux home directories, most email
  domains, hardware addresses and tokens, and it flagged a four-part version
  number. The maker had mutation-tested that detector an hour earlier and
  declared it fixed. It had tested the payloads it thought of.
- Smaller: two forced installs inside one second lost the first backup. An
  empty `agents` directory reported "in sync". A symlinked installed copy
  would be written through. A destination beginning with a dash was parsed by
  `cp` as options.

**What changed.** Every copy is checked, and a failure exits 3, names the file
and suppresses the next-steps text. `scanner` and `reviewer` hold tool
allowlists with no Agent tool. `browser-checker` cannot use an allowlist,
because it needs MCP tools whose names vary, so its denylist now also removes
the shell and the Agent tool, and its prompt says what to do when a page gives
it orders. `executor` gained the line saying content is data, and the fact that
a worktree does not confine a shell. The settings check became behavioral: run
the default install against a fake home directory and compare the settings
file byte for byte. The leak detector is now run against ten planted fixtures
before it is run against the repository, so a broken pattern fails loudly.
Backups get a counter, symlinks are refused, an empty source exits 64.

The suite went from 63 checks to 94. Run against the pre-review code, 12 of
the new checks fail. Run against the fixed code, none do.

**What was decided against.** Claiming any of these types is a sandbox. The
README gained a section, "What the tool limits do not do", that says what each
limit is worth. The honest position is that these definitions reduce what an
agent reaches for by accident, and that a permission prompt remains the real
control.

**The lesson worth keeping.** The maker's mutation test and the reviewer's
found different holes in the same regex, because the maker tested the inputs it
had imagined while writing the pattern. Fresh context is not a formality. It
is also an argument for the `reviewer` type staying on the expensive model:
this pass cost about as much as the original 74,000-token mistake that started
the project, and it was worth it.

**Left open by the review.** `omitClaudeMd` was taken from the vendor
documentation by a subagent and not confirmed by a second source. The symlink
tests cannot run on the Windows machine this was built on and need a run on
macOS or Linux.

---

## 2026-09-18, session 2, addendum: commits, and a live reload

**Question from Mark.** An earlier session had remarked that letting a
delegated agent commit was fine for his own projects but not for most
commercial settings, where the upper tier checks and commits. How did the
kit handle it? Answer: by omission. `executor` said "commit nothing
half-done", which implies it may commit, and nothing mentioned push or merge.

**Decision, Mark's: fix it now.** The rule is separation of duties, as for a
human developer: the executor commits on its own worktree branch only, with a
`Made-by` trailer, and never pushes, merges, rebases, amends, tags or
releases. Integration belongs to the dispatching session or a human who has
read the diff and the evidence. The alternative considered, leaving the work
uncommitted for the reviewer to commit, was rejected: an uncommitted diff in
an auto-cleaned worktree can be lost. The README says the rule is prompt, not
enforcement, and that a commercial setup needs a protected default branch,
required review, and an executor with no push credential.

**Observed, not claimed.** After the definitions were installed, this same
session's harness listed the four types as available, without a restart.
The vendor documentation says a brand-new agents directory is noticed only
at session start. One observation; the README's warning stands until a
second machine confirms either way.

**Also done.** The Goldshell project's own `AGENTS.md` now names `scanner`
and forbids `Explore`, so sessions launched there get the rule without the
user-level memory, which is keyed to a different directory. An audit of that
project's six earlier subagent transcripts found five on the top-tier model
and one on Sonnet: the pattern this kit exists to end.

**Session close.** Both repositories pushed (kit `552c9a0`, Goldshell
`997c302`), D: refreshed, status document updated. Closed at Mark's word at
the context checkpoint. Verification (V1 to V3) is the first thing the next
session does, from `STATUS.md`, before any Goldshell work relies on the
tiering.
