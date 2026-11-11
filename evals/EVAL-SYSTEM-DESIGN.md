# Kit eval system: design

From a transcript checker to an evaluation of the kit: AI-collected evidence,
human overreads, regression tests on frozen golden examples, and paired
model comparisons that keep the delegation rules current as models change.

Status: draft of 2026-11-08 (session bf9f1c8d), for a builder check and a
blind two-model review before any plan is written. Decisions cited as D-0xx
are rows in the owner's deferred-choices register.

## 1. Intent

The owner's words: build "a 'real Eval' of how the AI is doing, with
AI-collected evidence, human overreads, and objective testing of golden
examples." The first concrete target is this kit: measure it and improve it.
At the end of every session, a retro of how the kit was used and how well it
worked, with definite suggestions on how to make it better, how to test it
better, and what data to collect so rules can be improved semi-automatically.

On model choice, the owner's words: "If we only use a single delegation, we
never see how the other model(s) would have performed on certain work. Need a
control." And: "I want this to be a fluid and adaptable scheme that follows the
technology, rather than a static 'optimize to the last models that just went
obsolete'."

This extends the existing evals (D-072). `check_run.py`, `failures.md` and
`DESIGN.md` (D2/D3) are the base layer, not replaced.

## 2. Goals, non-goals, anti-goals

Goals:

1. Every delegation produces a structured record: who was dispatched, on
   which model, with what brief, at what cost, with what outcome.
2. Every error is logged as it happens, by whoever notices it, and none can be
   hidden (D-074, D-076).
3. Every catch is credited to its catcher (checker, dispatcher rule, agent
   stop-loss, reviewer, owner) and stage (brief, run, verification, merge,
   later). Escapes are counted.
4. A retro at the end of every session that the owner can overread in about
   10 minutes, more for big sessions.
5. Frozen golden examples with known right answers that the checker and the
   rules must keep getting right (regression).
6. Replayed briefs and live shadow pairs that measure cost per good outcome
   per job class and per model, so "delegate up" or "delegate down" is a
   measured decision (D-073, D-075).
7. A loop that turns evidence into proposed rule changes, logged as register
   rows, adopted by the owner, and re-measured.

Non-goals:

- A general LLM benchmark. Tasks come from the owner's real work only.
- Statistical certainty. Volume is about 80 dispatches in 7 weeks; the design
  aims for decisions that are better than anecdote, not publishable.
- Scoring the owner.
- The Mac in the first pass. The Windows PC is first; the Mac follows its own
  notes file.

Anti-goals (a failure even if it works):

- Overreads that take longer than about 10 minutes for an ordinary session.
- An eval that only measures what the AI chose to flag (no spot-check of
  "fine" items, so misses are invisible).
- Rules tuned to one model generation and never re-tested.
- A judge-model score with no ground truth behind it.
- Eval data or session text in the public repository.
- Hooks that text-inject agent-written content into the dispatcher (DESIGN.md
  principle 3, "no pushed text").

## 3. Evidence this rests on

A read-only study of the 32 sessions that dispatched kit agents (session
bf9f1c8d, scanner; two claims re-checked by grep, the rest regex-based and
approximate; 17 sessions read from handbacks only):

- 83 dispatches: 45 reviewer, 24 scanner, 9 executor, 5 browser-checker.
  Reviewing is the main job; execution is rare.
- Catches came from reviewers (about 25 of 45 verdicts said fix or hold),
  the Contradictions section (about 36 of 83 handbacks disagreed with the
  brief's facts), dispatcher re-verification (8722a38f overrode a "merge"
  verdict), and agent stop-losses. The checker caught 0 in real use; it ran
  only in the two sessions that built it (verified by grep).
- Failures: brief budgets ignore agent caps (9fb77a0e briefed about 150
  calls against a 60 cap, verified; and this session's own scanner, 80
  against 30); browser-checker blocked by the environment in 4 of 5 runs;
  fixes to review findings opened new holes 4 times; read-only scanners
  wrote scratch scripts twice.
- Not recorded anywhere: outcome (merged, accepted, rejected, redone), cap
  hits, the model that ran (visible only for 4 Fable runs), whether review
  findings were fixed or dismissed.
- Transcripts were being deleted after 30 days (sessions from 09-18 to 09-25,
  including the Haiku vs Sonnet measurements, are gone). Fixed by D-077:
  365-day retention and a frozen store of the 32 sessions.

What the owner reported matches: most problems were caught by the
dispatching session, and the checker reached him about once.

Conclusion that shapes the design: the dispatcher and the reviewers are
already the working quality system. Score them first. Retarget the checker at
the brief contract, where recorded failures are, before extending it further.

## 4. Architecture

Six layers. Each feeds the one above it. The public kit repository holds code,
schemas, task definitions and documents. The machine-local data store
(`.claude/evals/` under the working root, never committed) holds every
record, retro, grading key and frozen transcript.

```
L5  Rule loop        proposals -> register rows -> owner decides -> re-measure
L4  Prospective      task bank (replayed briefs) + live shadow pairs + routing table
L3  Regression       frozen golden transcripts with known right answers
L2  Retro            end-of-session retro + overread packet + spot-check
L1  Checks           check_run.py, retargeted; pre-dispatch brief gate
L0  Records          dispatch ledger, error log, findings ledger, outcomes
```

### L0. Records

Four append-only JSONL files in the data store. Every row carries
`session` (8 chars), `ts`, and `schema` (version).

**Dispatch ledger** (`dispatches.jsonl`). Derived by a script from the
transcripts, never typed by an agent, so it cannot be forgotten. One row per
agent ID (resumed segments merged): agent type, model (definition default,
overridden by the call's `model` parameter, overridden by subagent metadata
where present), job class, brief source (inline or file, with its sha256),
budget stated, agent cap (`maxTurns` from the installed definition), tool
calls used per segment, cap hit, cut off, resumed, tokens (input, output,
cache read, cache write, from the usage fields), wall time, Contradictions
count, pair ID if part of a shadow pair.

**Outcome rows** (`outcomes.jsonl`). The only field the transcript cannot
supply. The dispatcher records one per dispatch with a one-line command:
`kit-outcome <agent-id> merged|accepted|partly|rejected|redone|abandoned
[note]`. The retro lists any dispatch without one, and the owner can fill it.

**Error log** (`errors.jsonl`, D-076). Three sources, one schema:

| Field | Values |
|---|---|
| source | `called` (owner), `confessed` (agent), `scan` (backstop) |
| severity | 1 critical, 2 moderate, 3 trivial to annoying (owner's numbering) |
| who_erred | main session or agent ID, plus model |
| caught_by | checker, dispatcher-rule, agent-stop-loss, reviewer, owner, scan |
| stage | brief, run, verification, merge, later |
| text | one line, what went wrong |
| owner_mark | null until the overread: confirmed, not-an-error, severity changed |

**Findings ledger** (`findings.jsonl`). One row per review finding: review
ID, finding text (one line), severity, which reviewer(s) found it, then
`disposition` (fixed, dismissed with reason, deferred) and, later, `held`
(the fix survived re-review). This is what scores reviewers and what made the
owner's Opus-plus-Fable merged list measurable.

### L1. Checks

- Keep `check_run.py` and its D1/D2a checks. Merge D2b (orphan worktree
  4aeb7be: brief parsing and the post-run budget WARN; verified by the
  dispatcher on 2026-10-01, suite 255 passed) after a rebase onto main and a
  fresh suite run. Its open row is D-011.
- New check, pre-dispatch: **brief budget exceeds the agent's cap.** Reads
  the brief's Budget line and the installed definition's `maxTurns`. FAIL
  when budget is above the cap. First golden example (G-01 below).
- New check, pre-dispatch: **browser-checker without a reachable browser.**
  The brief must state the result of `list_connected_browsers` from the
  dispatching session. Four of five runs were blocked by this.
- New check, pre-dispatch: **write asked of a read-only agent** (9ea03052).
- Placement: a PreToolUse hook on the Agent tool runs these three against the
  call's prompt. It denies on FAIL with a fixed message (IDs and counts only,
  DESIGN.md principle 3). Fails open on its own bug, like the other hooks on
  this machine, with an error-log row.
- The rest of D2 (scope, evidence against transcript, report form, mirrored
  logic) stays in its planned order, re-ranked after the first month of L0
  data shows which failure classes actually recur.

### L2. Retro

Runs at the end of every session, including sessions with no delegation.

**Generator.** A script builds the facts (L0 rows for the session, check
results, scan hits); a model writes only the judgement parts (what worked,
what did not, suggestions). Facts are never model-written.

**Content**, in this order, each item short:

1. Delegation summary: dispatches by type and model, cost, cap hits,
   outcomes, missing outcomes.
2. Errors in three groups: called by owner, confessed by agents, flagged by
   the scan and not confessed. Each with severity and catcher.
3. Catch attribution table for the session.
4. Claims to confirm: at most 8 rows the owner marks confirmed, wrong or
   unsure.
5. Spot-check: 2 items the AI marked fine, chosen at random by the script,
   for the owner to look at anyway. This measures misses.
6. Proposed rule changes: each with evidence and a register row (L5).
7. Data in hand that nothing uses (the AGENTS.md hard rule).
8. Missed delegation: work the main session did itself that a kit agent
   could have done, with an estimate of the context it cost. Sessions with no
   dispatch get only this item and item 2.

**Storage.** `retros/<date>-<session>.md` plus its rows in the L0 files. The
existing five-line retro in `context/working-with-claude.md` stays and links
to this one.

**Overread.** The owner marks items 2, 4 and 5. His marks are written back to
the rows (`owner_mark`). The marks score the retro writer: claim accuracy,
spot-check miss rate, scan false-positive rate.

**Enforcement.** The existing Stop-hook checkpoint guard also requires a
retro file for the session once the session has done project work.

### Error calling and confession (D-076)

- **Owner's call.** A prompt line starting `ERR:` (severity 2 by default) or
  `ERR1:`, `ERR2:`, `ERR3:` is logged by a UserPromptSubmit hook before the
  model sees the prompt: time, session, the agent's last action, the text.
  The hook then adds one instruction: acknowledge in one line, say what went
  wrong and whether it is fixed. No such hook exists today (verified: zero
  `UserPromptSubmit` entries in either settings file).
- **Agent confession.** One script, `kit-error <severity> <text>`, callable
  by the main session and by any subagent with a shell. Every agent
  definition's handback format gains a required "Errors I made" section,
  "none" allowed; agents without a shell (browser-checker) report there only.
- **Backstop scan.** At retro time, a script reads the main and subagent
  transcripts for correction signals: retraction phrases, an edit that undoes
  an earlier edit, a test that failed and was then fixed, owner pushback.
  Hits with no matching error row are logged as `source: scan` and shown as
  unconfessed. The unconfessed rate per model is a reported metric.

### L3. Regression on golden examples

**Store.** `golden/transcripts/` (frozen 2026-11-08: 32 sessions, 261
files, read-only, `MANIFEST.sha256`). New golden cases are copied in when
chosen; the manifest is regenerated and the previous one kept.

**Cases.** Each case is a small file in the public repo (sanitized, no paths
or names): transcript ID and agent ID, the check or rule it exercises, and
the right answer (expected FAIL/WARN lines, or expected record fields). The
checker's existing census-against-real-transcripts habit (D1, D2a) becomes
this suite.

Initial candidates from the study:

| ID | Session, dispatch | Exercises | Right answer |
|---|---|---|---|
| G-01 | 9fb77a0e executor, round 3 | budget above cap | FAIL budget-cap |
| G-02 | 2dc90da4 executor M1b | cut off, no handback | FAIL no-handback / cap-hit |
| G-03 | 9ea03052 scanner 0 | write asked of read-only agent | FAIL read-only-write |
| G-04 | 6d76022a executor + 2 reviews | a good run | no FAIL; outcome merged |
| G-05 | 8722a38f reviewer 3 | dispatcher overrides "merge" | catch credited to dispatcher-rule at merge |
| G-06 | 1322ef6e Fable reviewer | brief-stage catch | catch credited to reviewer at brief |

G-05 and G-06 test the record and attribution layer, not the checker.

**When it runs.** On every change to `check_run.py`, the hooks or the
record scripts (part of `tests/run-tests.sh`), and on every new model as
dispatcher, since the dispatcher writes outcomes and catches.

### L4. Prospective tests: does the right model get the right job?

**Job classes.** Fixed before measuring, so "Opus is good enough for X" has
X defined in advance. Starting set, from the study: plan review, diff
review, log or transcript scan, browser check, mechanical code, diagnosis.
The dispatch ledger tags each dispatch; the tag is the dispatcher's, checked
in the overread.

**Routing table.** One data file in the kit, `routing.yaml`: job class ->
agent -> model, with the date and the evidence behind each line. The agent
definitions keep their pinned models; the table is what the dispatcher
consults and what a challenger changes. A new model is a one-line edit.

**Task bank (replayed briefs).** About 12 tasks drawn from the golden store,
two per job class, each with a mechanical grader:

- Code tasks: frozen brief and repository snapshot; graded by the suite,
  scope of the diff, and the evidence matching the transcript.
- Review tasks: a plan or diff with planted defects (known count); graded by
  defects found and false findings.
- Scan tasks: a large log with known facts; graded against the facts,
  including confidently wrong statements.
- Browser tasks: a local test page with known content.

Each cell (task x model x rule variant) runs 3 times. The September Haiku
measurement reversed between two files, which is why single runs decide
nothing. A smoke subset of 4 tasks runs when a model ships; the full bank
runs only if the smoke result says the model is a contender. Runs are
sessions the owner starts; there is no API (no Anthropic API keys on this
plan), so cost is measured in tokens and plan quota.

**Shadow pairs (live control, D-075).** About 15 to 20 percent of eligible
live dispatches run twice: the routed model and a challenger one tier up or
down. A sampler script decides, so the dispatcher cannot choose favourable
cases. Read-only roles run side by side; a paired executor works in its own
worktree and the losing diff is discarded. Grading is blind (A and B, the
mapping kept in the data store until grading is done). For reviews, the
union of findings is confirmed or rejected one by one and each side is
scored on real findings and false ones. Fable pairs are counted against a
weekly cap.

**Control on delegating at all.** Occasionally the dispatching session also
does the delegated job itself, so the kit's premise (delegation saves the
main window at little quality cost) is measured rather than assumed.

**Metrics** per job class and model:

1. Quality: pass rate, planted defects found, false findings, escapes.
2. Tokens, and for scarce models (Fable) plan quota as its own column.
3. Wall time.
4. Supervision cost: errors visible to the owner, owner calls (`ERR`),
   nudges, unconfessed rate. A model that reaches the right answer through
   many confessed errors scores worse than one that is quietly right. (The
   owner's Opus 5 session, about 20 confessed and fixed errors, is the case
   this metric exists for.)
5. Cost per accepted outcome: tokens plus rework plus supervision, divided by
   outcomes that held up.

**Value of a check** (a review, a stop-loss, a hook): catches times the
severity-weighted cost of the escape it prevented, minus the check's own
cost. Severity weights come from the owner's marks.

**Promotion rule.** A challenger replaces the routed model for a job class
when it wins on the bank and at least 8 live pairs in that class do not
contradict it. The routing table records the change and its evidence.

### L5. Rule loop

- Each retro's proposed changes become register rows with evidence links.
- The owner decides by ID. Adopted changes are edits to agent definitions,
  the brief template, the routing table or the hooks, each with the metric it
  is expected to move.
- A monthly roll-up reads the L0 files: recurring failure classes, catch
  attribution trend (catches should move earlier and to cheaper catchers),
  escape rate, per-model supervision cost, and whether adopted changes moved
  their metric. A change that moved nothing is proposed for removal.
- Each month's real incidents add one or two fresh golden cases and bank
  tasks, so the bank does not go stale or get overfitted.

## 5. Decisions already made

| ID | Decision |
|---|---|
| D-072 | Extend the existing evals, do not build beside them |
| D-074 | Log errors as they occur, no hiding; show the owner to confirm or add; an explicit way to call an error |
| D-075 | 15 to 20 percent of delegated work run as blind double-model pairs, Fable cost tracked |
| D-076 | `ERR:` prefix with a prompt hook; ERR1 critical, ERR2 moderate, ERR3 trivial; confession script; "Errors I made" section; unconfessed scan |
| D-077 | 365-day transcript retention and a frozen golden store (done) |
| process | Design here; builder check; Fable and Opus review it blind as the first shadow pair; a fresh Opus session writes the plan; Sonnet executors per gate, fresh reviewer per gate |

## 6. Constraints

- Claude Pro plan, no Anthropic API keys: no programmatic runs outside
  Claude Code sessions. Fable quota is scarce.
- About 10 minutes of owner overread per ordinary session.
- Public repository: no paths, addresses, names or session text in tracked
  files (`tests/run-tests.sh` floor plus the leak guard).
- Hooks run the installed copy, outside an executor's reach (DESIGN.md
  principle 4).
- Windows PC first. Line endings LF in the repo.
- Agent caps: executor 60, reviewer 40, scanner 30, browser-checker 25 turns.
  A brief's budget must fit under them.

## 7. Suggested gates (the plan decides)

1. L0 records and the error call: dispatch-ledger script over the golden
   store, outcome command, `ERR` hook, `kit-error`, handback section.
2. L1 pre-dispatch gate (three checks) and D2b merge; G-01 to G-03 as tests.
3. L2 retro generator and overread format; first real retros.
4. L3 regression suite over G-01 to G-06.
5. L4 routing table, sampler and blind grading for review pairs (the most
   common job), then the task bank.
6. L5 monthly roll-up.

## 8. Left to the builder

File layout inside the data store, exact JSON field names beyond those
above, the correction-signal patterns for the scan (tuned later by owner
marks), how the retro generator splits script and model work, and the order
of D2c to D2f after the first month of data.

## 8a. Calls made after the builder check (designer's calls, owner may override)

A fresh builder read this document on 2026-11-08 and asked seven questions.
These five were settled by the designer; two went to the owner (section 8b).

1. **Job class.** The dispatcher writes `Job: <class>` as a line of the
   Agent call's prompt. Classes are defined in `routing.yaml`; the owner
   approves additions. For the golden store, a script infers the class from
   agent type and the call's description, and the first overreads spot-check
   the inference. `kit-outcome` stays `<agent-id> <outcome> [note]`.
2. **Retro mechanism.** The script writes the facts. The main session writes
   the judgement parts itself at checkpoint time: it holds the context, and a
   subagent would cost extra quota for less knowledge. The existing
   checkpoint guard already decides "this session did project work"; the
   retro requirement reuses that test, so there is no new Stop-hook loop.
3. **Shadow-pair sampling.** A PreToolUse hook on the Agent tool runs the
   sampler. When it selects a dispatch, it denies the first call with fixed
   wording: pair ID, the two models, "dispatch this brief twice". That is a
   refusal holding IDs and fixed text, which DESIGN.md principle 3 allows.
   A selected dispatch whose twin never appears is flagged in the retro as a
   rule break. Reviewers are the only eligible role in the first pass (the
   most common job, read-only, easy to grade by findings).
4. **Pre-dispatch gate behaviour.** The Budget format is the brief
   template's `Tool calls: N` (as D2b parses it). A brief given as a file path
   is read from the file. No parseable budget is a WARN, never a deny (fail
   open). Only a parsed budget above the cap, a write asked of a read-only
   agent, or a browser-checker brief with no browser check is a FAIL. The
   escape hatch is in 8b.
5. **Golden cases on a machine without the store.** `tests/run-tests.sh`
   reports them as SKIPPED with a count, never as passed (a skipped test is
   not proof). Expected rows for G-05 and G-06 live in an annotation file per
   case, written by the designer and confirmed by the owner in an overread.
6. **Attributing an agent's confession.** No subagent ID variable is known
   to exist (unverified). So `kit-error` writes its row without an agent ID,
   and the ledger script attributes it afterwards by finding the `kit-error`
   call in the main or subagent transcript where it was made. Gate 1 checks
   live whether the harness exposes a session or agent ID to a shell, per the
   rule to verify a hook's input contract live (D-060).
7. **Hook installation.** The `ERR` prompt hook and the Agent-tool gate are
   machine-level hooks in the working root's `.claude/hooks/`, where the
   other hooks on this machine live, registered by the owner's settings like
   them. `install.sh` still never edits a settings file; the kit documents the
   snippet.
8. **Routing table use.** The dispatcher consults `routing.yaml` by
   instruction. The ledger records routed model against actual model, and
   the retro flags a mismatch. No hook pushes routing text.
9. **D2b.** The worktree exists (verified with `git worktree list`). Its
   branch base is the pushed main of 2026-10-01, so gate 2 starts with a
   rebase and a fresh suite run.

## 8b. Owner's questions from the builder check

- D-078 (decided): at most 2 Fable pairs a week, reviews only, revisited
  after the first monthly roll-up.
- D-079 (decided): the dispatcher may add `Override: <check> <reason>` to the
  brief; the gate then allows the dispatch, logs an override row, and the
  retro shows every override for the owner to judge.

## 9. Risks

- The task bank is mostly code and log work; it may not predict design or
  writing quality.
- Blind grading of pairs costs owner time. At most one pair per ordinary
  overread; others are graded by a fresh reviewer and spot-checked.
- Job-class tags are the dispatcher's judgement and may drift.
- The scan will flag planned refactors as reversals; its false-positive rate
  is reported so it can be tuned.
- Eight pairs per class is a weak sample. Treat promotions as reversible.

## 10. Data in hand that nothing uses

- Token usage fields in every transcript: never summed per dispatch. Decides
  cost per job class immediately, from the golden store.
- Contradictions sections in about 59 of 83 handbacks: never tallied. A
  per-brief count measures brief quality.
- Subagent metadata files beside each subagent transcript: they hold agent
  type, worktree, description, spawn depth and background flag (verified on
  1322ef6e), but no model. Agent type and worktree give the ledger two fields
  for free; the model must still come from the definition plus the call's
  override, or from the model name on assistant records if present.
- Background test results that landed after a reviewer's report (33a688bc,
  c2477b50) and corrected it: a signal that reviewers report before their
  evidence is complete.
