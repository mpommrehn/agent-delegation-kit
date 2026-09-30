# Failure catalog

Every check in `check_run.py` exists because a delegated run once failed in
that way. This file records those failures, groups them into classes, ranks
the classes, and names the check that covers each one, or says that none can.

Source: a scan on 2026-09-28 of the kit's status docs, field notes and
evolution log, and of every subagent transcript on the dispatching machine,
95 at the time. It found 15 incidents. Rebuilt from that scan on 2026-09-29.

Transcripts are not in this repository, so fixtures under `fixtures/` are
synthetic. Where a real transcript exists it is named by agent ID only, to be
found locally under `~/.claude/projects/<root>/<session>/subagents/`.

## How to read the ranking

Severity:

- **High**: lost work, a false acceptance, harm to a live system, or a
  near-miss of one of those.
- **Med**: wasted cost, a good change nearly blocked, or a dispatcher misled.
- **Low**: cleanup, no harm to the result.

Priority is incidents recorded times severity weight (High 3, Med 2, Low 1).
The counts are a floor: an incident counts only if someone wrote it down.

## Classes, highest priority first

| ID | Class | Incidents | Sev | Priority | Covered by | Status |
|---|---|---|---|---|---|---|
| F1 | Stopped without a report | 3 | High | 9 | `no-handback`; `cap-hit` | Built (D1), misses resumed runs; fix and backstop in D2a |
| F2 | Budget far over the brief's size | 3 | Med | 6 | budget check | Planned (D2b) |
| F3 | Scope list hid mirrored logic | 1 | High | 3 | mirrored-logic search | Planned (D2f) |
| F4 | Verification claimed, not shown | 1 | High | 3 | evidence-vs-transcript | Planned (D2d), no real positive |
| F5 | Finished work discarded by a restore | 1 | High | 3 | `discarded-work` (WARN) | Built (D1) |
| F6 | Destructive or outward command | 1 | High | 3 | `forbidden-command`; hooks | Built (D1), no real positive; gates D3 |
| F7 | Wrong model tier | 1 | Med | 2 | `model-tier` | Built (D1), no real positive |
| F8 | Reviewer severity out of proportion | 1 | Med | 2 | reviewer-report form | Planned (D2e), proxy only |
| F9 | Correction restated as a false claim | 1 | Med | 2 | none | Audit only |
| F10 | Prose overstated the numbers | 1 | Med | 2 | none | Audit only |
| F11 | Evidence file committed to the target repo | 1 | Low | 1 | scope check; merge gate | Planned (D2c, D3c) |
| F12 | Dispatch refused, stray worktrees left | 1 | Low | 1 | none yet | Environment fix |

"No real positive" means the check has never fired on a real incident
transcript: the originals are gone or never existed, so only synthetic
fixtures prove it. `discarded-work` has one: it warns on the 09-26 round-4
transcript (`ac41fee7`), which holds the restore that lost a finished fix.
It also warns on round 3; whether that restore lost anything is unverified.

Two main-session incidents from the scan are kept at the end, since they are
not delegation failures but a checker or gate could still catch them.

## Incidents by class

### F1. Stopped without a report

- 2026-09-15/16, session V: a Sonnet executor wrote a poller and never
  reported. 109 tool calls against a budget of 70, about 230k tokens, work
  left uncommitted. Transcript not found.
- 2026-09-26: a brief sized to about 150 calls ran into `maxTurns` 60 twice.
  Both runs were cut off with no report. Transcripts `ab10ad272a16d3e68`
  (round 3) and `ac41fee7b60ec7113` (round 4); both were resumed later, so
  the cut-off is mid-file.

Check: `no-handback` FAILs for any segment of a run (a resumed run has
several) that has tool calls and does not end with a `SubagentHandback`. Fixtures: `no-handback`,
`resumed-no-handback`, `attachment-first-cutoff`, `era-cutoff-tool-use`; must
pass: `clean-executor`, `resumed-ok`, `era-text-ending`.

Real frequency: the 2026-09-28 sweep over 105 transcripts reported one true
`maxTurns` cutoff. That was an undercount. On 2026-09-29 both 09-26
transcripts were found to pass the checker with no FAIL, although each was
cut off at exactly 60 tool calls (`ab10ad27` twice). A resume sent with
`SendMessage` is a user line marked `isMeta` with an `origin` of kind
`coordinator`, and the checker's segment split skips every `isMeta` line. So
a cut-off that was later resumed and finished looks like one clean segment.
Fixing the split is the first item of D2a.

Root cause, recorded 2026-09-26: an agent cannot see its turn count, so a
"stop by turn N" rule cannot work. The template now sizes briefs at one or
two fixes and asks for a commit after every finished step.

### F2. Budget far over the brief's size

- 2026-09-15/16, session V: 109 calls against 70 (the same run as F1).
- 2026-09-19: the gbox 0.7.3 executor made 48 calls against 40, but reported.
- 2026-09-26: the brief itself needed about 150 calls against a cap of 60.

Planned check (D2b): count tool calls per segment and compare with the
brief's stated budget. The finding is about the brief's sizing, not the
agent's conduct, since the agent cannot count. WARN, not FAIL.

### F3. Scope list hid mirrored logic

- 2026-09-18/19, gbox 0.7.3: the brief named the `SEED_RE` regex as the
  hazard and scoped out the web directory that held a copy of it in another
  language. The executor kept to scope, correctly, and a silent defect nearly
  shipped. Transcript `af39624dd850407b9`; brief in
  `examples/executor-brief-gbox-0.7.3.md`.

Not visible in a transcript. Planned check (D2f): for each literal the diff
changes, search the whole repo for the same literal outside the files in
scope. Validate against the real 0.7.3 case before briefing it. Since
2026-09-29 the brief template also asks the dispatcher for this search before
dispatch.

Passing case from the same run: the executor stopped at the scope boundary on
`test_config.py` instead of editing it. Any scope check must not flag that.

### F4. Verification claimed, not shown

- 2026-08-21, G2: an executor reported a verification it had not run. Since
  then a prose "verified" counts for nothing without the raw command and its
  output. Predates the kit; no transcript.

Planned check (D2d): every command quoted in the evidence file must appear as
a Bash tool call in the transcript, and the quoted output must match the
tool result.

### F5. Finished work discarded by a restore

- 2026-09-26, round 4: restoring a file with `git checkout --` after a
  deliberate re-break wiped a second, finished, uncommitted fix in the same
  file. The executor noticed and redid it.

Check: `discarded-work` WARNs when a restore touches a path edited since the
last commit. It is a WARN because a sanctioned re-break proof looks the same
in a transcript; intent is not recorded. A restore of a directory is also
a WARN. A restore of the whole tree (`.`, `*`, the root) and
`git checkout -f` FAIL under `forbidden-command`. Fixtures: `discard-*`,
`forbidden-checkout-*`, `forbidden-restore-*`.

### F6. Destructive or outward command

- 2026-09-19, main session: stopping a process matched by command-line text
  stopped the live gbox watchdog for about 20 seconds, because a scratch copy
  and the live service were byte-identical. A `PreToolUse` hook now denies the
  pattern.

No subagent has pushed, merged or tagged in real data, so every positive
fixture here is synthetic. Check: `forbidden-command` FAILs on push, merge,
tag creation, `reset --hard`, `clean -f`, broad restores and pattern kills
(`pkill -f`, `taskkill /IM`, `CommandLine -like`). Fixtures: `forbidden-*`,
`gopt-*`, `ps-*`; must pass: `allowed-*`.

D3 moves this from detection to prevention: hooks keyed on `agent_type`, and
enforcement files write-protected from executors.

### F7. Wrong model tier

- 2026-09-17/18: `general-purpose` with no `model` ran on the parent's Opus
  and spent 74,381 tokens on a CSV scan. This incident started the kit.

Check: `model-tier` FAILs when an `executor`, `scanner` or
`browser-checker` runs on anything but Sonnet or the model pinned in its meta
file. It WARNs when an unpinned `general-purpose` or `Explore` run uses a
frontier model, which is this incident. A `reviewer` is not checked; it
inherits the parent's model by design. Fixtures: `model-*`.

### F8. Reviewer severity out of proportion

- 2026-09-19, gbox 0.7.3: a reviewer opened with "hold this merge" over three
  real but latent findings, one call site, unreachable in the shipped
  configuration. Transcript `a1ee39a1ef55f9087`.

Reachability needs judgment, so no check can decide this. Planned proxy
(D2e): a hold or do-not-merge verdict must cite a failing command or a
`file:line`. Since 2026-09-29 the reviewer definition asks for reachability
separately from severity and reserves "hold" for a reachable defect; the
check would make that visible in the report, not judge it.

### F9. Correction restated as a false claim

- 2026-09-15/16: a docs agent was given a correction and restated it as a
  false claim. Caught by checking the fixture.

Semantic. Audit only: the dispatcher reads the report against the brief. The
Contradictions section added 2026-09-29 makes a disagreement with the brief
visible, but not a silent inversion.

### F10. Prose overstated the numbers

- 2026-09-18: a scanner on Haiku got every checkable number right but twice
  overstated in prose what the numbers supported, and misfiled endpoints.
  Transcripts in session `df6b1c19`; `evidence/verify-2026-09-18.md`.

Audit only. Mitigation: `scanner` stays pinned to Sonnet on calibration
grounds. F8 is the same shape on a frontier model, so this is a role problem
as much as a model one.

### F11. Evidence file committed to the target repo

- 2026-09-19, gbox 0.7.3: the evidence file was written to `evidence/` in the
  target repo and swept into a commit by `git add -A`.

Planned check (D2c): a Write outside the brief's files in scope, with the
evidence path as the only allowed exception, and that path outside the
repo's tracked tree. D3 adds a gate on the evidence path.

### F12. Dispatch refused, stray worktrees left

- 2026-09-26: `executor` refused twice because the session's working
  directory was spelled in lowercase, and left locked worktrees. Session
  `81c064cf`; no executor transcript on disk.

Environment, not agent behavior; fixed by starting sessions in the correctly
cased directory. A check could flag the harness refusal as an error result,
but it would only restate what the dispatcher already saw.

## Main-session incidents

Found by the same scan. Neither is a delegation failure.

- 2026-09-17: a small insert became a whole-file line-ending rewrite (33
  lines in, 95 insertions and 62 deletions). Med. A merge gate could reject a
  diff whose `git diff --numstat` shows deletions close to insertions on a
  small change. Candidate for D3's merge gate.
- 2026-09-19: a status checkpoint written before the session's last actions
  was wrong in four places. Med. Not checkable; the rule in the root
  `AGENTS.md` (write the checkpoint last, mark each claim verified or not)
  covers it.

## Known checker limits

Gaps in the D1 checker, both missed failures and false alarms, found during
its review rounds and after:

- A round resumed with `SendMessage` is not a new segment (see F1), so
  `no-handback` misses a cut-off that was later resumed. Found 2026-09-29;
  the worst of these, since it hides the top-ranked class.

- Quoted text inside a `python -c` or `printf` argument is matched as a
  command, a false FAIL. Two real cases known: a reviewer's test string, and
  the D1 executor's own note mentioning `pkill -f`.
- Edits made from Bash (`sed -i`, redirects) are invisible to
  `discarded-work`.
- Heredocs fed to `bash` are skipped.
- `bash -c "git push"` is not caught.

## Adding a failure

When a delegated run fails in a new way:

1. Add the incident under its class here, or start a new class.
2. Find the real transcripts of **the incident that motivated the check**,
   and one clean transcript that must still pass. Write down, before any run,
   the finding each must produce. Every real defect in D1 came from real
   transcripts; none came from hand-written fixtures.
3. Write the check, add a synthetic fixture for each, and add both to
   `tests/run-tests.sh`.
4. Run the checker on the motivating transcripts and compare with what you
   wrote down. A motivating incident that does not produce its finding means
   the check does not work, whatever else the sweep shows.
5. Rerun the checker over all recent real transcripts and read every new
   finding before merging.

If no real transcript of the incident exists, say so, and mark the check
"no real positive" in the table above: it is proven only on synthetic
fixtures, which test the rule as written, not whether the rule matches what
really happens.

Step 4 exists because D1 skipped it. D1 was validated by sweeping 105 real
transcripts and reading the FAILs that came out. The two 09-26 cut-offs that
motivated `no-handback` produced no finding, and nothing had said they
must, so their absence went unnoticed until 2026-09-29.
