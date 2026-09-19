# Field notes: the kit's first real `executor` and `reviewer` run

Written 2026-09-19 by the goldshell session that used them (session X, gbox
0.7.3). For a later session working *on* the kit. Nothing here has been applied
to the kit -- these are findings and proposals, and the decisions are Mark's.

Before this, the kit's own `STATUS.md` said `executor`, `reviewer` and
`browser-checker` were "still never exercised... shape-tested only". After this
run, `executor` and `reviewer` have been used for real on a live project.
`browser-checker` still has not. **That STATUS line and the evolution log both
need updating, and this file is the source for doing it accurately.**

---

## What the run actually was

Repo: `goldshell-box-tools-productguy`, a stdlib-only Python toolkit that runs a
watchdog over a Goldshell SC-BOX miner and can cut its mains power via a smart
plug. Live service on the same machine, real hardware. So: small, well-tested,
and genuinely consequential if a defect ships.

The work was three defect fixes left open by an earlier session. Sequence:

1. Main session diagnosed the hardest defect directly (a probe script against the
   real class), because the kit's own table says diagnosis is not delegable.
2. `executor` (sonnet, `isolation: worktree`) got a written brief for the three
   mechanical fixes.
3. Main session finished what the executor stopped on, and fixed a defect the
   brief had caused.
4. `reviewer` (parent's model, no override) attacked all four commits.
5. Main session verified the reviewer's findings itself, fixed three, and merged.
6. `scanner` (sonnet) separately read 6 MB of telemetry for a hardware check.

Outcome: 0.7.3 merged, 369 Python + 59 JS tests green, pushed and tagged.

---

## Finding 1: the brief's scope list is itself a hazard

**This is the most important finding and the one with no current coverage in the
kit.**

The brief said, in bold, that `SEED_RE` in `watchdog.py` was "the main hazard in
this task" -- change the log wording without widening that regex and historical
log lines silently stop seeding a safety cap. It then listed "Files in scope" and
put `gbox/web/*` explicitly out of scope.

The dashboard's `app.js` mirrors `SEED_RE` with its own copy of the same pattern.
Widening only the Python one would have made the page silently stop classifying
power-cycle events from the first cycle after the change. No error, no test
failure, just a feature quietly gone.

The executor did exactly the right thing: it stayed inside its scope. The defect
survived *because the scope was correct-looking and wrong*. The main session
caught it only by grepping for the literal string afterwards, on a hunch.

The general shape: **naming a hazard in a brief creates a false sense that the
hazard is handled.** A scope list is a claim that the author has already worked
out the blast radius, and the agent reasonably trusts it.

**Proposal for `templates/BRIEF-TEMPLATE.md`**, under "Files in scope":

> Before you write the scope list, take each hazard you named above and search
> the repo for everything that reads or writes the same thing -- the same regex,
> the same string literal, the same JSON key, the same column name. Mirrored
> logic in another language is the common case and the easy miss. Put what you
> find in scope, or say in the brief why it is safe to leave out. A hazard you
> named but scoped out is worse than one you never mentioned, because the agent
> will trust the boundary.

**Proposal for the "After it returns" section:**

> Grep for the literal thing that changed -- the old string, the old pattern --
> across the whole repo, including other languages, before you merge. The agent
> could only look where you told it to.

---

## Finding 2: the stop-loss language worked, measurably

The brief carried, verbatim: *"At 35, stop wherever you are, commit only what is
finished and green, and write up what is not. **An unfinished write-up is a
success.** A silent overrun is a failure"* -- plus the concrete precedent that a
previous agent on this repo ran to 109 tool calls against a 70-call budget and
never reported.

The executor reported at **48 tool calls against a 40-call budget**. It overran
by 20%, but it *stopped and reported*, which is the behaviour that matters. The
prior incident on the same repo, same model tier, with a budget but without the
"unfinished write-up is a success" line, was a 155% overrun with no report and
uncommitted work that had to be recovered by hand.

One data point each, so not proof. But the difference is large and the mechanism
is plausible: an agent with only a budget treats stopping as failure, so it keeps
going; an agent told that stopping is a success has a way to comply.

**Proposal:** promote "an unfinished write-up is a success" from something this
brief happened to say into the template's Budget section as standing text. It is
currently absent. Also worth stating the budget twice -- once as the number, once
as the stop-below number -- which this brief did and which seems to help.

**Also worth recording:** the executor still overran by 8 calls. If the kit wants
budgets honoured exactly, the number in the brief should be the *stop* number,
not the *ceiling*, because agents appear to treat it as a soft target.

---

## Finding 3: the scope-stop was worth more than the code

Task C of the brief was a one-line default change. The executor stopped and
reported that it would break an assertion in `tests/test_config.py`, a file
outside its scope list, and refused to widen.

When the main session picked it up, there were **six failing tests across four
files**, not the one the executor had named. Had it edited its way to green, it
would have touched four test files unreviewed, and the judgement calls were not
mechanical: three of those tests were asserting *the default itself* (right fix:
read the constant), and the fourth was asserting *gap mechanics* whose arithmetic
was built on the old value (right fix: pin the old value explicitly, which is the
opposite change).

That is exactly the boundary the kit's four-question test is drawing, and it held
under load. Worth writing into the kit's narrative as the concrete example,
because "when to delegate" is otherwise abstract.

---

## Finding 4: `reviewer` findings were sound, its severity was not

The reviewer produced three findings. All three reproduced exactly under the main
session's own probes. It also did two things the kit should advertise:

- It **cleared** the riskiest change with evidence rather than assertion -- traced
  a value back through the caller to prove a gate could not restart a healthy
  miner, and named the guard that bounds it.
- It **proved a new test had teeth** by reverting the one-line fix in a scratch
  copy and confirming that test alone failed.

Both are behaviours a human reviewer often skips. Good.

The problem was severity. It opened with "**Hold** `d220ff7`", and described its
top finding as affecting "the overlap that actually happens (a running service's
own lines)". That is false. The method in question has exactly one call site, at
service start, before anything live has happened. All three findings were
**latent** -- real, worth fixing, but unreachable in the shipped configuration.

The main session established that in two commands (`grep -rn` for the call site).
Had it taken the verdict at face value it would have held a good merge.

This is the same calibration failure the kit's own STATUS already records for
`scanner` on Haiku: *"Haiku's prose twice overstated what its numbers
supported."* Here it is the parent's own frontier model doing it. **So the
pattern is not a cheap-model problem, it is a reviewer-role problem** -- the role
rewards finding things, and nothing in the brief asked it to price them.

**Proposal for `agents/reviewer.md` and the template's Return section:**

> For every finding, state its **reachability** separately from its severity: is
> it reachable in the shipped configuration today, and by what path? If it needs
> a caller or a state that does not currently exist, say "latent" and name what
> would have to change to reach it. A verdict of "do not merge" requires a
> reachable defect. Do not infer reachability from the code's shape -- find the
> call sites and say how many there are.

**Proposal for "After it returns":**

> Re-verify a reviewer's *severity and reachability claims*, not only its
> findings. The findings are usually right; the framing is what misleads.

---

## Finding 5: `scanner` flagged a contradiction instead of smoothing it

Minor but worth keeping. The scanner's brief described normal hashrate as "~700
GH/s". The raw column reads ~650,000-695,000. Rather than quietly reconciling
these or asserting a unit, it reported the figures and added that it had **not**
verified whether the column is GH/s or MH/s, and that its reasoning held either
way.

That is the correct behaviour and the opposite of the calibration problem above.
It suggests the "say so and say why, do not estimate and present it as measured"
line in the brief is doing real work and should stay in the template.

It also caught a factual error in the brief itself -- the brief asserted a schema
change at a certain date changed the column count, and the scanner found the count
constant, with empty trailing fields instead. **Briefs contain errors; a scanner
that contradicts its brief is working correctly.** Worth saying explicitly in the
template, because the natural pull is to defer to the brief.

---

## Finding 6: mechanics that worked, and one that did not

Worked, no friction:

- `isolation: worktree` dispatched from inside a git repo. Created
  `.claude/worktrees/agent-<id>`, branch `worktree-agent-<id>`, cleaned up with
  `git worktree remove --force` + `git branch -D` afterwards. The kit's open
  question was `isolation: worktree` from a *non-repo* directory; that is still
  untried, and this run does not answer it.
- `reviewer` with no `model` override correctly ran on the parent's model.
- Passing the brief as a file path and having the agent read it, rather than
  inlining ~200 lines into the prompt. Kept the dispatch call small and the brief
  editable. **Suggest the kit recommend this explicitly.**

Did not work as expected:

- The executor wrote its evidence file to `evidence/` inside the worktree, per the
  brief. That directory is not a convention in the target repo, and a later
  `git add -A` swept it into a commit that had to be amended. The kit's own repo
  commits `evidence/`; a target repo may not want to. **Suggest the template's
  Evidence section say to put the evidence file outside the repo (the session
  scratchpad) unless the target repo already has an `evidence/` convention, and
  say which.** In this case Mark chose to discard it.

---

## Suggested changes, collected

In rough priority order. None applied.

1. `templates/BRIEF-TEMPLATE.md`, "Files in scope": add the mirrored-logic search
   step (Finding 1). Highest value -- this one nearly shipped a defect.
2. `templates/BRIEF-TEMPLATE.md`, "After it returns": grep for the changed
   literal across the whole repo before merging (Finding 1).
3. `agents/reviewer.md` + template Return section: require reachability separate
   from severity; "do not merge" needs a reachable defect (Finding 4).
4. `templates/BRIEF-TEMPLATE.md`, "Budget": make "an unfinished write-up is a
   success" standing text; state the stop number as the budget (Finding 2).
5. `templates/BRIEF-TEMPLATE.md`, "Evidence": evidence goes to the scratchpad
   unless the target repo has an `evidence/` convention (Finding 6).
6. `templates/BRIEF-TEMPLATE.md`: recommend passing the brief as a file path
   (Finding 6).
7. Add a line that a scanner contradicting its own brief is correct behaviour
   (Finding 5).

## Facts for the kit's STATUS and evolution log

- Date: 2026-09-18 into 2026-09-19. Target: `goldshell-box-tools-productguy`,
  release 0.7.3. Parent session on Opus 5.
- `executor`: 1 dispatch, sonnet, `isolation: worktree`. 48 tool calls, 139,662
  tokens, ~864 s. Two of three tasks committed with tests; third stopped at the
  scope boundary and reported, correctly.
- `reviewer`: 1 dispatch, parent's model, no override. 32 tool calls, 74,917
  tokens, ~452 s. Three findings, all reproduced; verdict overstated (see
  Finding 4). Cleared the riskiest change with evidence and proved a test had
  teeth by reverting the fix.
- `scanner`: 1 dispatch, sonnet. 17 tool calls, 30,899 tokens, ~152 s. Read a
  7.5 MB telemetry CSV and a 225-line event log; returned conclusions only, no
  raw rows into the parent context. Flagged an error in its own brief.
- `browser-checker`: not used. Still shape-tested only.
- Net: three of four types now exercised for real. No agent damaged anything, no
  agent pushed, merged or rebased, and no agent touched the live service.
