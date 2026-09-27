# Delegation brief

Copy this, fill it in, and pass it as the subagent's prompt. A subagent starts
with none of your context and cannot ask you anything mid-run, so whatever is
not written here does not exist for it.

## Should this be delegated at all?

All four must hold to hand work to a cheaper model. If one fails, keep the work
in the main session or use the `reviewer` type.

1. The spec is fully written, with the files named.
2. Done-when is a command with checkable output.
3. The blast radius is contained: a worktree, no live service.
4. The reads needed are small and named.

Two rules above the table: **if the done-when cannot be written as a command,
do not delegate. If the brief would be longer than the work, do it yourself.**

| Work | Agent type | Model |
|---|---|---|
| Search, read, summarize, log and CSV scans. Conclusions only, no edits. | `scanner` | sonnet |
| Open a page, check a written list, report. | `browser-checker` | sonnet |
| Mechanical, specified, tested work in a worktree. | `executor` | sonnet |
| Judging a diff, a plan, or an evidence file. | `reviewer` | the parent's |
| Diagnosis, design, a person's voice, security review, live systems. | none: keep it in the main session | |

## The brief

**Goal.** The outcome, not the activity. One or two sentences.

**Context.** The files to read first, in order, with paths. Decisions already
made that the agent must not reopen.

**Files in scope.** The files the agent may change. Everything else is out of
scope, and needing one is a reason to stop and report.

**Constraints.** Standards, conventions, things not to touch.

**Done-when.** The exact command, and what its output must show.

```
<command>
```

**Evidence.** Path of the evidence file. Every verification step goes in it as
the raw command beside the raw output. A prose claim of "verified" counts for
nothing. **Write it as you go**, appending each step's command and output when
it runs, not at the end: an agent that hits its turn limit then leaves a usable
record instead of none.

**Git.** Commit on your worktree branch only. Never push, merge, rebase, amend
or tag. The session that dispatched you integrates, after reading the diff
and the evidence.

**Budget.** In turns, below the agent's `maxTurns` (read it from the
definition's frontmatter before writing the brief; `executor` is 60). A brief
that asks for more work than the cap allows is cut off mid-task with no report.
Size from experience, not arithmetic: two small fixes with tests and
fail-then-pass proofs used more than 60 turns (2026-09-26), so plan one or two
fixes per dispatch and split anything larger. **Do not write "stop by turn N"**:
an agent cannot see its own turn count, so it cannot obey it (tried
2026-09-26, the agent ran to the cap). The cap is the hard stop; what makes
hitting it cheap is checkpointing by action (next paragraph). Say that an
unfinished write-up is a success.

**Checkpoints by action.** Tell the agent: commit on your branch after every
finished step and **before every deliberate re-break** (a `git checkout --
<file>` restore also discards any uncommitted edit in that file: this lost a
finished fix on 2026-09-26); append to the evidence file after every test
run. Then a cut-off at the cap loses at most one step.

**Stop-losses.**

- Three strikes: about to edit the same file a third time to fix your own
  previous fix, stop and write up the state.
- The same error blocks you twice: stop and write it up. Do not retry.
- Never weaken a test or skip a check to reach green.

**Return.** What the final report must contain, and its length limit. For a
`scanner`: conclusions and the commands behind the figures, never raw lines.

## After it returns

- Read the diff and the evidence file, not the summary.
- Verification runs in a fresh session or a `reviewer`, never in the session
  or agent that made the change.
- To confirm which model a subagent ran on, count the `"model"` values in its
  transcript. See the README, "Prove which model ran".
