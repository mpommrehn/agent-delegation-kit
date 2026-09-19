<!--
The real brief dispatched to `executor` on 2026-09-18 for goldshell gbox 0.7.3.
Preserved verbatim, including its defect: it names SEED_RE as "the main hazard"
and puts `gbox/web/*` out of scope, while the dashboard holds a mirror of that
same regex. The executor stayed in scope, correctly, and the miss survived to
the merge. See FIELD-NOTES-2026-09-19-goldshell.md, Finding 1.

Worth reading for what it got right too: the done-when is a command, the known
flaky test is called out so the agent does not chase it, the budget states a
stop below the ceiling, and "an unfinished write-up is a success" is spelled
out. The executor reported at 48 calls against 40, where the same repo had
previously seen 109 against 70 with no report.
-->

# Brief: gbox 0.7.2 defect fixes (executor)

## Goal

Fix three defects found in session W of `goldshell-box-tools-productguy`, each
with tests that fail before the change and pass after. Three commits, one per
task, on your worktree branch. You do not push, merge or rebase.

## Context — read these first, in this order

1. `AGENTS.md` (repo root) — the rules that bound every change.
2. `gbox/watchdog.py` — the whole file. It is 390 lines. Tasks A and B live here.
3. `tests/test_watchdog.py` — classes `PowerCycleTest` (line ~188) and
   `SeedFromEventsTest` (line ~449). Reuse the existing `FakeClock`, `Recorder`,
   `FakePlugObject` and the `setUp`/`make`/`feed` helpers. Do not invent a new
   test harness.

Decisions already made by the owner. Do not reopen them, do not propose
alternatives, do not improve on them:

- The cycle counter stays a **rolling 24-hour window**. Only the human-readable
  wording is wrong. A calendar-day counter was considered and rejected.
- The `settle_minutes` code default follows the live value: 20 becomes 6.
- The `cycles_today` JSON key in `gbox/server.py` and the `cycles_today()`
  method name **stay exactly as they are**. Renaming either is an HTTP API
  change, needs a version bump, and breaks the page JS. Out of scope.

## Files in scope

- `gbox/watchdog.py`
- `gbox/cli.py` (one string, task B1)
- `gbox/config.py` (one line plus its comment, task C)
- `tests/test_watchdog.py`

Everything else is out of scope. Needing to change another file is a reason to
**stop and report**, not to widen the change. In particular do not touch
`gbox/web/*`, `gbox/server.py`, `gbox/poller.py`, or anything under `docs/`.

---

## Task A — the boot check must survive an HTTP-only answer

**The defect is already diagnosed and reproduced. Do not re-diagnose it.**

`observe()` in `gbox/watchdog.py` (around lines 104-108) does this:

    if ok:
        self.episode_start = None
        self.episode_failed_restarts = 0
        self._power_logged = False
        self._boot_check = None         # it answered: it booted

The first successful HTTP sample after a power cycle disarms the boot check.
But the failure the boot check exists to catch is exactly "the control board
boots and answers HTTP normally while the hashboard never comes up". So in that
failure the check is always cancelled before it is due, and nothing is logged.
Confirmed against the real `Watchdog`: a dark box writes the boot event line; an
HTTP-answering box with a dead hashboard leaves `_boot_check` at `None` and
writes nothing.

**The change.** `observe()` already takes a `hashing` argument, and
`gbox/poller.py:219` passes a real boolean for it. Clear the boot check only
when the miner is actually hashing:

    if hashing is None or hashing:
        self._boot_check = None

`hashing is None` means "older caller, same as ok" and must keep today's
behaviour; that contract is documented in the `observe()` docstring. Replace the
trailing comment, because the existing one ("it answered: it booted") states the
belief that caused the defect.

**Tests.** Add to `PowerCycleTest`, or a new class beside it if that reads
better. Three tests:

- A1. Box fully dark after a cycle (`ok=False`), wall draw under `boot_watts`:
  the boot event line is written and a repeat cycle fires. This **passes today**
  and is a regression guard for behaviour you must not break.
- A2. Cold start (`ok=True`, `hashing=False`), wall draw 3 W, `boot_watts` 20:
  the boot event line **is** written and the repeat cycle fires. This **fails
  today** and is the point of task A.
- A3. Healthy boot (`ok=True`, `hashing=True`), normal wall draw: the boot check
  is cleared and **no** repeat cycle fires. This guards against turning the fix
  into a restart loop on a healthy box. Say in a comment why it exists.

Commit A on its own.

---

## Task B — the "today" label, and the double seed

### B1. Wording

`cycles_today()` is a rolling 24-hour window, but two messages call it "today".
At 16:2x on 2026-09-17 the log said "cycled #3 today" while the counter later
read 1, because the earlier cycles had aged out of the window. Reproduced.

- `gbox/watchdog.py`, in `_cycle`: `"power: cycled #%d today: ..."` becomes
  `"power: cycled #%d in 24 h: ..."`.
- `gbox/cli.py` line ~377: `"service: %d cycles today%s"` becomes
  `"service: %d cycles in 24 h%s"`.

Leave alone the messages that already say "in 24 h" (in `_consider_power` and
`_check_boot`). They were right all along.

**CRITICAL, and the main hazard in this task.** `SEED_RE` at
`gbox/watchdog.py:49` matches the literal text `power: cycled #\d+ today`. If
you change the written wording without widening that regex, **every historical
event-log line silently stops seeding the daily cap** — the exact failure the
seeding was built to prevent (a restart onto a hung miner ran past the cap on
2026-09-12). The regex must match **both** the old "today" form and the new
"in 24 h" form. Write a test that feeds one line of each form and asserts both
are counted.

### B2. The double seed

`seed_from_events` calls `self._cycle_times.extend(...)` and
`self._restart_times.extend(...)` unconditionally, so calling it twice counts
everything twice. Measured: seeding the same two-cycle tail twice gives
`cycles_today() == 4`. There is one call site today (`gbox/cli.py:510`), so it
is latent rather than live, but it is real.

Make a second call not double-count. Prefer the smallest change that is
obviously correct and keeps the return value honest; a guard that makes a second
call a no-op is acceptable, as is de-duplicating by timestamp. Whichever you
choose, say in the docstring why it is there. Add a test to `SeedFromEventsTest`:
seed the same tail twice, assert the counts after the second call equal the
counts after the first.

Note: the event line `seed_from_events` writes ("watchdog picked up N restarts
and M cycles ...") must not be written a second time either, if the second call
is a no-op.

Commit B on its own.

---

## Task C — the `settle_minutes` default

`gbox/config.py` line ~40 reads:

    "settle_minutes": 20,        # nothing judged this long after a cycle

The value becomes 6. 20 was an un-revisited default that came from
`docs/power-cycle-proposal.md`; across 25 measured boots the miner was hashing at
5-25 seconds of uptime, and the owner has already set 6 in the live
`~/.gbox/config.json`.

**Match the existing comment style.** Read the `after_minutes` and
`min_gap_minutes` lines in the same dict first. Both were tuned on 2026-09-12 and
carry a dated comment. Write the new comment the same way, citing 2026-09-17 and
the 25 measured boots. Do not add a validation bound for `settle_minutes`; that
is a separate decision the owner has not made.

Commit C on its own.

---

## Done-when

From the repo root of your worktree:

    python -m unittest -q

Output must show **at least 361 tests** (361 is the count on `main` before your
change) plus the tests you added, and either `OK`, or a single
`ConnectionResetError` in a socket test.

**Read this before you chase a failure.** That `ConnectionResetError` is a known
flaky socket test on this machine, not a regression: on the same clean commit it
appeared on one run and not on the next. If you see it, re-run once. If it
clears, it was the flake. If it does not clear, or if any other test fails, that
one is yours — stop and report rather than working around it.

The suite takes about 165 seconds. Budget for that; do not assume it has hung.

## Evidence

Write `evidence/0.7.2-fixes-2026-09-18.md` in your worktree. For every
verification step, the **raw command beside its raw output**, pasted, not
summarized. It must contain at minimum:

- the full `python -m unittest -q` tail before your first change (the baseline)
- proof that test A2 fails before the task A change and passes after: run that
  single test both ways and paste both outputs
- proof that the B1 regex test passes for both the old and the new wording
- the final full-suite run
- `git log --oneline` of your three commits, and `git diff --numstat main`

A sentence saying something was verified counts for nothing. If you did not
paste the command and its output, it did not happen.

## Git

Commit on your own worktree branch only, three commits. **Never** push, merge,
rebase, amend, tag, or touch `main` or the branch `gate2-pga`. The dispatching
session integrates after reading your diff and your evidence file.

Check `git diff --numstat` before each commit. If a file you edited shows
wholesale deletions and re-insertions, you have flipped its line endings: stop,
do not commit it, and report. This repo has a `.gitattributes` and a history of
exactly that going wrong.

## Budget

40 tool calls. At 35, stop wherever you are, commit only what is finished and
green, and write up what is not. **An unfinished write-up is a success.** A
silent overrun is a failure; a previous agent on this repo ran to 109 tool calls
against a 70-call budget and never reported at all.

## Stop-losses

- About to edit the same file a third time to fix your own previous fix: stop
  and write up the state.
- The same error blocks you twice: stop and write it up. Do not retry a third time.
- Never weaken a test, loosen an assertion, or skip a check to reach green.
- A task needs a file outside "Files in scope": stop and report.

## Return

At most 400 words. State, per task: what you changed, the test names you added,
and whether it is committed. Then the final suite line verbatim, the path to the
evidence file, and anything you did not finish. Do not paste diffs into the
report; they are in git. Do not claim anything you did not run.
