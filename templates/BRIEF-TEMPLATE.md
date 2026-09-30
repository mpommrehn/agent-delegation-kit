# Delegation brief

Copy this, fill it in, and pass it as the subagent's prompt. A subagent starts
with none of your context and cannot ask you anything mid-run, so whatever is
not written here does not exist for it.

Save the filled-in brief as a file and pass its path, with one line telling
the agent to read it first, rather than pasting the brief into the prompt.
The dispatch call stays small, and the brief stays editable for a revised
re-dispatch.

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
made that the agent must not reopen. Keep facts and decisions apart: the agent
keeps to your decisions, but a fact you state may be wrong, and an agent that
finds evidence against it should say so.

**Files in scope.** The files the agent may change. Everything else is out of
scope, and needing one is a reason to stop and report.

Before you write this list, take each hazard you named and search the repo for
everything that reads or writes the same thing: the same regex, string
literal, JSON key or column name. Mirrored logic in another language is the
common case and the easy miss. Put what you find in scope, or say in the brief
why it is safe to leave out. A hazard you named but scoped out is worse than
one you never mentioned, because the agent will trust the boundary.

**Constraints.** Standards, conventions, things not to touch.

**Done-when.** The exact command, and what its output must show.

```
<command>
```

**Evidence.** Path of the evidence file. Every verification step goes in it as
the raw command beside the raw output. A prose claim of "verified" counts for
nothing. **Write it as you go**, appending each step's command and output when
it runs, not at the end: an agent that hits its turn limit then leaves a usable
record instead of none. Put the file outside the target repo, in your session
scratchpad, unless the repo already keeps evidence files; if it does, name
that directory. An evidence file inside a repo that does not expect one gets
swept into a commit by the next `git add -A`.

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
hitting it cheap is checkpointing by action (next paragraph).

Tell the agent, in so many words: **stopping with a report of what is finished
and what is not is the correct behavior, and a silent overrun is the
failure.** An agent given only a budget treats stopping as failure and keeps
going (a 155% overrun with no report, before this line existed); one told that
stopping is correct has a way to comply. That is about the agent's behavior, not the task: the task
is still incomplete, and the dispatcher handles it (see "After it returns").

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
Every report ends with a **Contradictions** section: each fact in the brief
the agent found evidence against, with the evidence, or "none".

For a `reviewer`, ask for each finding's **reachability** separately from its
severity: reachable in the shipped configuration today, and by what path, or
latent, with what would have to change to reach it. A verdict of "do not
merge" requires a reachable defect.

## After it returns

- Read the diff and the evidence file, not the summary.
- Verify every item in the Contradictions section before acting on it. The
  agent may be right, and briefs do contain errors, but a contradiction is a
  claim like any other.
- Grep for the literal thing that changed, the old string or the old pattern,
  across the whole repo and every language in it, before you merge. The agent
  could only look where you told it to.
- Re-verify a reviewer's severity and reachability claims, not only its
  findings. The findings are usually right; the framing is what misleads. Find
  the call sites yourself and count them.
- An agent that stopped and reported behaved correctly, and the task is still
  incomplete. Before any re-dispatch, ask why it stopped, and keep asking why
  until you reach a cause you control: the brief's size, a wrong fact, a
  missing file in scope. Change the brief to address it. Never re-dispatch an
  unchanged brief.
- Verification runs in a fresh session or a `reviewer`, never in the session
  or agent that made the change.
- To confirm which model a subagent ran on, count the `"model"` values in its
  transcript. See the README, "Prove which model ran".
