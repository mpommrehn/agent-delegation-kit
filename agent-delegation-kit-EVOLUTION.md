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
