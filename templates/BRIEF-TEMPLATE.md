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
nothing.

**Git.** Commit on your worktree branch only. Never push, merge, rebase, amend
or tag. The session that dispatched you integrates, after reading the diff
and the evidence.

**Budget.** Turns or minutes. What to do when it runs out: stop, commit nothing
half-done, report what is finished and what is not.

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
