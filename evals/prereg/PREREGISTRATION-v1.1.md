# Kit eval: pre-registration of the paired model comparison

Version 1.0, written 2026-11-11 (session a710c44f), before any confirmatory pair was run. It fixes what
the study measures, how outputs are judged, how the data is analysed and what may be claimed. It is a
companion to `EVAL-SYSTEM-DESIGN.md` (the system) and changes nothing in it. After the commit that adds
this file, the text changes only through section 14, the deviations log.

Labels: "verified" means checked in the session named, by the command or source given. Anything else is
marked unverified. Decisions are rows in the owner's register (ADK-nnn); **OPEN** marks a row still waiting.

## 1. What this study is, and what it may claim

One owner, one working setup, real work. When the owner's main session delegates a job to a subagent, a
sampled share of those jobs runs twice, on two models, from the same brief and the same repository state.
Past jobs are also replayed on a second model. Each output is graded by a script where a script can know
the answer, by later git history for replays, and otherwise by the owner, blind.

Claims allowed in the first report (day 8, 2026-11-19, ADK-154):

- The harness and protocol exist, with this document dated before the data.
- Preliminary estimates with 95% intervals, every one labelled with its n and its cluster count.
- Measured properties of the judging itself: blinding, order effect, the owner's own consistency.

Claims not allowed at day 8, whatever the numbers look like: "model X is better than model Y", "X is as
good as Y", any routing recommendation presented as a finding, any generalisation beyond this owner's
work. An equivalence statement ("no worse by more than 10 points") is never made at day 8. From the
second publish it is allowed only when the whole clustered 95% interval of the paired difference lies
inside plus or minus 10 points. An 80% chance of that, at 30% discordant pairs and no true difference,
needs about 315 pairs before clustering (normal approximation, verified by script).

## 2. Questions

Primary (confirmatory, reported for every comparison in section 3):

- **Q1. Acceptance.** For the same task, how much does the acceptance rate differ between the two
  models? Estimand: the paired difference in acceptance. Two-sided; no direction is predicted.
- **Q2. Cost per accepted output.** What does one accepted output cost on each model, and what is the
  ratio? Estimand: the ratio of the two arms' cost per accepted output (section 5).

Secondary (reported, labelled secondary):

- **Q3.** What did the owner's overread add beyond the scripts: verdicts overturned, defects only the
  owner caught, and the minutes it cost.
- **Q4.** Turns, tool calls and wall-clock time per task, as paired ratios.
- **Q5.** Supervision cost per task (the ADK-118 weights) and the confession rate.
- **Q6.** How blind was the judging (model-guess rate) and how large was the order effect.
- **Q7.** How consistent is the owner's severity rating with itself (ADK-155).
- **Q8.** Where an AI judge is run (section 10): its agreement with the owner, its order-flip rate and,
  in the cross-family subsample, its preference for its own family.

Anything else is exploratory and is labelled so wherever it appears.

## 3. Units, arms, job classes, sources

- **Task.** One brief (identified by the sha256 of its text) at one repository commit.
- **Pair.** One task run by two arms. The agent definition, tools, turn cap, brief and starting commit
  are identical; only the model differs. Neither arm can read the other's output or worktree.
- **Arm.** The model that actually ran, read from the run's transcript, never the model requested. Two
  versions of a model are two arms and are never pooled (the `fable` alias and a full model ID resolve
  to different versions today; verified 2026-11-10, session bf9f1c8d, ADK-127).
- **Cluster.** The session in which the task's brief was first written. Tasks from one session share a
  repository state, a dispatcher and a style of brief, so they are not independent.
- **Comparisons, fixed now.** C1: Sonnet against Opus on log or transcript scans and on mechanical code.
  C2: Opus against Fable on plan review and diff review. Each Fable version is its own C2 arm.
- **Job classes.** Plan review, diff review, log or transcript scan, mechanical code. Browser checks and
  diagnosis are out of scope (design, L4). A class is reported alone only with 10 or more pairs;
  below that it appears only inside its comparison's total, with its n shown.
- **Sources.** Live pairs (a dispatch the work needed anyway, run twice) and replay pairs (a past task
  on which both arms are run fresh, in the same sandbox at the single reviewed commit, ADK-152). Both
  are true pairs and enter the primary estimates together, with source as a sensitivity split.
- **Historical comparisons are not pairs.** A challenger re-run compared with the original run of
  months ago differs in date, kit version and sandbox, and later history confirms the original's
  findings because they were acted on. Such comparisons get their own table and enter no primary
  estimate. This narrows the design's L4 replay and is **OPEN** as ADK-162.
- **Pilot data.** Every pair dispatched before this file's commit (P-001, which was not blind, and P-002,
  the review of this document) is pilot data. It is shown in its own table and enters no estimate.

## 4. Sampling, pairing and exclusions

- **Script-gradable tasks** (the brief's done-when is a command): every one is paired (ADK-149).
- **Judge-needed tasks**: 40% are paired, chosen by the brief's hash, not by the dispatcher. Until the
  sampler script exists the rule is done by hand: take the first 8 hex digits of the brief's sha256 as
  an integer; pair the task when that integer modulo 100 is below 40.
- **The draw is logged before it is known.** Every brief's hash, job class tag and script-gradable flag
  are appended to the sampler log before the draw is computed. A reworded brief for the same task keeps
  the first draw and is counted as a rewrite. Reports show paired and unpaired counts per class, and the
  rewrite count, so steering by rewording or by tagging would be visible.
- **Run order.** The arm whose model name sorts first runs first when the 9th hex digit of the hash is
  even, second when it is odd. Both arms start from the same commit in separate worktrees.
- **Judging cap.** The owner judges 1 to 1.5 hours a day (ADK-150). Pairs are judged oldest first. A
  pair not yet judged stays in the table as "ungraded"; it is never dropped.
- **Replays.** Every review or scan brief in the frozen store that names its commit is eligible; the
  order of replay is the order of the brief hashes, so nobody picks the favourable ones.
- **Excluded pairs** (counted and listed, with the reason): an arm that never started (denied dispatch,
  environment failure before the first tool call); a replay whose hand-checked transcript shows it saw
  later history; a brief changed between the two arms. Nothing else is an exclusion. An arm that hits
  its turn cap, is cut off, or returns nothing usable is a completed run with outcome "not accepted".
- **Capture before use.** Each arm writes its output to a file and hands back only the file's name. A
  script copies both outputs to the store under labels before anyone reads them. The live work then
  uses the routed model's output, always, never the better-looking one. The dispatcher writes, edits
  and normalizes nothing the judge will see. A pair that broke this is kept in the main table's
  sensitivity line "capture rule broken", not dropped.

## 5. Outcomes and formulas

For task i, arm m: A(i,m) is 1 when the output is accepted, else 0.

**Accepted**, by job class. The rule is applied by script from the marks; nobody sets A by hand.

| Job class | Accepted when |
|---|---|
| Mechanical code | The brief's done-when command exits 0 on the arm's branch, and the diff touches only paths the brief allows |
| Scan, with an answer key | Every key item marked must-find is reported, and no reported conclusion contradicts the key |
| Scan, no key | The owner, blind, marks every conclusion; accepted when none is marked wrong and no must-find item named by the other arm and confirmed is missing |
| Plan or diff review | At least one confirmed finding, no confirmed severity-1 finding in the reference set missed, and confirmed findings at least as many as false ones. When the reference set is empty (nothing confirmed by either arm or by history), an arm is accepted when it has no false finding |

The reference set for a review is every finding of either arm that is confirmed, plus, for a replay
pair, every defect that later history shows was fixed or found in the reviewed commit; history counts
the same for both arms. A finding is confirmed by a script, by later history, or by the owner's blind
mark "real". False means marked "not real". "Unsure" is neither and is reported as its own count. Two
findings are the same defect when the owner merges them while marking the union list, before any label
is revealed. This rule is the registered one. It is the designer's call and **OPEN** as ADK-157; a
different answer from the owner is a section 14 entry, made before any confirmatory review is graded.

**Held up.** An accepted output not redone, reverted or corrected by a later fix within 30 days. It
exists only for the arm whose output the work used, so it is secondary, reported from the second publish.

**Cost.** T(i,m) is the price-weighted token count of the run: input, output, cache-read and
cache-write tokens, each multiplied by its list-price ratio. The weights are written to the data store
with their date before the first analysis and are printed in every report beside raw tokens. They are a
relative measure, not money (the plan has no per-token billing).

    cost per accepted output, arm m:   CPAO(m) = sum_i T(i,m) / sum_i A(i,m)
    ratio between arms:                CPAO(m1) / CPAO(m2)

It is a ratio of sums over the same tasks, never a mean of per-task ratios. With zero accepted outputs
it is reported as "none accepted", not as a number. Rework cost is left out of the primary figure on
purpose: only the output the work used ever gets reworked, so counting it would favour the unused arm.
It is reported for the used arm as a secondary column; the design's fuller formula (rework and
supervision over outcomes that held up) is a later, secondary measure. Supervision cost and owner
minutes are in other units and no conversion is fixed (**OPEN**, ADK-158); they sit in columns beside it.

**Other measures.**

- Turns, tool calls, wall-clock seconds: per task, per arm, from the transcript.
- Supervision cost per task: errors weighted confessed 1, owner-called 2, reviewer-found and
  unconfessed 3, escaped to live use 5 (ADK-118). Confession rate: confessed errors over all errors.
- Overread added (Q3), on the pairs the owner read: the overturn rate (script or history verdicts the
  owner reversed, over verdicts read); owner-only defects per 10 pairs; owner minutes per pair.
- Model-guess rate: the owner's correct guesses of which output came from which model, over pairs judged.
- Position preference: the share of the owner's non-tie preferences that went to the output shown first.
- Flip rate (AI judges only): comparisons whose verdict changes when the order is swapped, over
  comparisons judged in both orders.
- Agreement: Cohen's kappa, linear-weighted for the 1 to 3 severity scale, unweighted for real or not
  real. Percent agreement is never reported without kappa beside it.

## 6. Results table (the shell, fixed now)

One row per comparison, job class and source; a total row per comparison. Every cell that is an
estimate carries its 95% interval.

| Column | Content |
|---|---|
| n, G | Pairs analysed; clusters |
| Ungraded, excluded | Counts, with reasons listed below the table |
| Acceptance | Rate for each arm |
| Paired difference | Arm 1 minus arm 2, in points, with interval |
| Discordant | Pairs only arm 1 passed; pairs only arm 2 passed |
| Cost per task | Median price-weighted tokens per arm; geometric mean of paired ratios |
| CPAO | Per arm, and the ratio with interval |
| Turns | Median per arm; paired ratio |
| Wall-clock | Median seconds per arm; paired ratio |
| Supervision | Weighted errors per task per arm; confession rate |
| Overread added | Overturn rate; owner-only defects per 10 pairs; owner minutes per pair |
| Judging quality | Blinding level (section 9); model-guess rate; position preference |

Below the table, always: the price weights and their date, the pilot table, the exclusions list, the
deviations log, and the owner's consistency figure (Q7).

## 7. Analysis plan

- **Paired, not two means.** Every comparison is of the two arms on the same tasks. For acceptance the
  estimate is d = (b - c) / n, where b counts pairs only arm 1 passed and c pairs only arm 2 passed.
- **Clustered standard error.** With d_j the sum of (A(i,1) - A(i,2)) over the n_j pairs of cluster j,
  and G clusters:

      SE(d) = (1/n) * sqrt( G/(G-1) * sum_j (d_j - n_j * d)^2 )

  This SE gives the reported design effect and rho. **Which interval is reported:** with 30 or more
  clusters and 10 or more discordant pairs, a cluster bootstrap (resample clusters, keep pairs intact,
  10,000 resamples, percentile limits, seed recorded). Below either threshold, which is where day 8
  will be, the exact interval from the discordant pairs, unclustered and labelled "exact, ignores
  clustering, too narrow if tasks correlate". A bootstrap is never reported when it collapses to a point.
- **Confirmatory family.** Q1 and Q2 for each comparison total (one per pair of arm versions), live and
  replay pairs together: four estimates with two comparisons. Job-class rows and source splits are
  descriptive and uncorrected, and say so.
- **Tests.** Q1: exact McNemar, two-sided. Q2: the bootstrap interval of the log CPAO ratio excluding
  zero. The day-8 report uses no significance wording, only intervals. From the second publish,
  "significant" is used only after a Holm correction over the family. At the strictest Holm step of a
  family of four (alpha 0.0125), a 15-point difference needs about 146 pairs, not 102, and a 10-point
  one about 332 (normal approximation, verified by script).
- **Ratios.** CPAO is the ratio of sums. Cost per task, turns and time are the geometric mean of the
  paired ratios. Any other estimator is labelled sensitivity.
- **Ungraded pairs.** The primary estimate uses graded pairs, and the graded share per job class is
  shown beside each total (script-graded pairs are graded at once, judged ones lag). A sensitivity line
  shows two bounds: every ungraded pair counted as "only arm 1 passed", then as "only arm 2 passed".
- **Sensitivity.** Clustering by project instead of session; live and replay sources separately; pairs
  below full blinding removed.
- **Not done.** No pooling across model versions. No job class merged after seeing data. No subgroup
  found after the fact is reported as a finding. No outlier is removed; a run with extreme cost stays.

## 8. Power (verified 2026-11-11, session a710c44f, by a script: exact McNemar, enumerated)

Paired yes/no outcome, two-sided alpha 0.05. "Discordant" is the share of pairs where the arms
disagree; it is unknown until measured, so three values are shown. The figures assume independent pairs.

| Pairs | Discordant | Power for a 10-point difference | 15-point | 20-point | Smallest difference at 80% power | Interval half-width near zero difference |
|---|---|---|---|---|---|---|
| 30 | 20% | 0.10 | 0.27 | 0.57 | not reachable | about 16 points |
| 30 | 30% | 0.09 | 0.21 | 0.40 | 27.5 points | about 20 |
| 30 | 40% | 0.08 | 0.17 | 0.31 | 32.5 | about 23 |
| 100 | 20% | 0.54 | 0.93 | 1.00 | 13 | about 9 |
| 100 | 30% | 0.37 | 0.75 | 0.96 | 16 | about 11 |
| 100 | 40% | 0.30 | 0.62 | 0.88 | 18.5 | about 12 |
| 200 | 20% | 0.88 | 1.00 | 1.00 | 9.5 | about 6 |
| 200 | 30% | 0.70 | 0.97 | 1.00 | 11.5 | about 8 |
| 200 | 40% | 0.57 | 0.91 | 1.00 | 13 | about 9 |

- The earlier rough figures (about 100 pairs for 15 points, about 230 for 10, at 30% discordant) match
  the normal approximation (102 and 233). The exact test is a little weaker: 100 pairs give 0.75.
- **Clustering lowers all of this.** Effective pairs = n / (1 + (m - 1) * rho), with m pairs per cluster
  and rho their correlation. At m = 3 and rho = 0.2, 100 pairs count as 71; at m = 5 and rho = 0.3, as 45.
  Rho is unknown here and is estimated and reported at day 8.
- For a continuous paired measure (log cost ratio, log turns ratio) the smallest detectable shift at
  80% power is 2.8 / sqrt(n) standard deviations of the paired difference: 0.51 at 30 pairs, 0.28 at
  100, 0.20 at 200. That applies to cost per task. CPAO divides by the accepted count, so its
  precision is limited by Q1's and is no better powered than Q1.
- What this means for day 8: at 30 to 40 pairs per comparison, only a difference near 30 points could
  be detected. The day-8 report is an estimate with a wide interval, and says so.
- The design's routing rule (down-route after 6 replays with 0 confirmed severity-1 misses) is an
  operating rule, not a study claim. Six clean replays bound the true miss rate only below 39% at 95%
  confidence (1 - 0.05^(1/6)). Reports state that bound whenever the rule fires.

## 9. Judging protocol

**Order of graders.** Script first, later git history second, the owner third. An AI judge never sets
a primary outcome (design anti-goal: no judge-model score without ground truth).

**Blinding levels**, recorded per pair. How far to go is **OPEN** as ADK-121; the study proceeds on its
recommendation (a) and reports the level actually reached.

| Level | What was done |
|---|---|
| B0 | Not blind: the judge knew the mapping, or someone who knew it wrote or edited what the judge saw |
| B1 | A script assigned labels A and B and holds the mapping; outputs in the fixed schema |
| B2 | B1, and a normalizer that never saw the mapping rewrote both outputs into one neutral wording |

Only B1 and B2 pairs enter primary estimates; the level is a sensitivity split (the normalizer is not
built yet, so sprint pairs will be B1). The dispatcher knows which model it sent each brief to; under
the capture rule of section 4 it never learns which label an output got. The mapping file is opened by
the analysis script only after the owner's marks for that pair are saved. In a replay pair the owner
marks all findings of both fresh arms under labels; the original run's output is not shown.

**Owner load.** ADK-150 gives at most about 11 hours to day 8. The schema caps an output at 8 findings.
The first pairs are timed, and the report states minutes per pair and the judged count that followed;
at 15 minutes a pair that is about 44 judged pairs in all, across both comparisons.

**Style normalization** (so the judge reads content, not formatting). Outputs reach the owner as plain
text in one schema: location, claim, evidence, proposed severity; a length cap per field; no markdown,
no headings, no summary paragraph, no self-description; findings sorted by location, not by the
author's ranking. Which output is shown first is set by the script, at random, and recorded.

**The owner's marks, per pair**, in this order: each finding or conclusion real, not real or unsure;
a severity 1 to 3 for each real one; an overall preference (first, second, tie); a guess of which model
wrote which; minutes spent. The guess is asked last so it cannot colour the marks.

**Severity anchors** (ADK-155), drawn from the study's own error log and reworded without session text:

- **1, critical.** A public push of something that must not be public; data lost; a live service
  affected; work the owner needed nearly destroyed on unread advice (the log's one severity-1 row).
- **2, moderate.** Wrong content reached a document or a decision and someone else caught it, or it was
  caught only just before acting: an unchecked figure from a subagent copied into a design; a deletion
  recommended without reading what would be deleted.
- **3, trivial to annoying.** No wrong result reached anyone: a check run from the wrong folder; a
  half-applied edit visible for minutes; a count in a document that did not match its list.

A review finding has no consequence yet, so its severity is the level the outcome would have reached
had the defect gone uncaught. The log holds 1 row at severity 1 and 2 at severity 2 (verified 2026-11-11, 10 rows read), fewer than
the 2 to 3 examples per level that were asked for. The first two anchors lean on the design's floor
rule until more rows exist; each new owner-marked row at level 1 or 2 is added as an anchor.

**Owner consistency.** At the end of the week the owner re-rates 10 randomly drawn rows without seeing
his first marks (ADK-155). Kappa is reported with its interval. At 10 rows that interval is about plus
or minus 0.4 (verified by the same script, rough formula), so the day-8 figure is descriptive only; the
re-rate repeats at every checkpoint and the rows accumulate (**OPEN**, ADK-159).

**Blinding check.** The model-guess rate is reported with its exact binomial interval. The interval is
wide at this volume (about plus or minus 18 points at 30 pairs), so below 100 judged pairs no verdict
of "blind enough" is given; "above chance" is said only when the interval excludes 50%.

## 10. Judge independence (the recommendation for ADK-153, **OPEN**; the owner decides)

The owner's test: add a judge from another model family only if it makes the judging better or more
independent by criteria the literature recognises. Four such criteria (sources in section 15): validity
against ground truth or a human; no judge that is also a contestant (self-preference); measured order
and style bias; chance-corrected reliability.

Two facts about this study shape the answer. First, no AI judge sets a primary outcome, so judge-family
bias cannot reach Q1 or Q2 at all; that is the single-family design the owner asked about, and it is
portable to anyone with one vendor. Second, both arms of every comparison are models of one family, so a
judge "from another family" does not separate the arms. The bias that matters here is a model judging
its own output, and the rule against it is simple: a judge is never the same model as either arm.

| Option | Independence gained | Feasibility and cost | Data exposure |
|---|---|---|---|
| Consumer chat subscription to another family, by hand | Yes, but settings and memory are not controlled, so not reproducible | No script access (API billed separately: likely, not verified at the vendor). About an hour of owner time per 20 pairs in both orders, taken from judging hours | Text pasted to a consumer service |
| Multi-model subscription with a bundled API | Yes, several families from one key | Bundled API reported by search results only, unverified; the owner checks that a key exists, the credit allowance and the model list (5 minutes). A small script, 1 to 2 hours | Third party; its data terms unread |
| Pay-as-you-go model router | Yes, several families | Prepaid credits, no minimum found; a few dollars for tens of pairs (estimate, unverified). Same script | Prompts not logged by default; some providers may train on inputs, so only no-training providers are selected (vendor pages read 2026-11-11) |
| Local open models on the owner's hardware | Yes | Endpoint not verified reachable; small quantized models; validity as a code-review judge unknown | None |
| No AI judge in primary outcomes (this plan) | Not needed for Q1 and Q2 | Nothing to build | None |

Recommendation:

1. **Primary judging stays scripts, git history and the blinded owner.** Nothing is added to it.
2. **An AI panel is a measured secondary instrument (Q8), run after day 8.** Stored blinded pairs can be
   re-judged at any time; pairs can only be collected now, and the owner's hours are the limit this week.
3. **The panel, when run:** three judges, none the same model as either arm: one from the arms' family
   and two from other families, through the bundled API if the owner's check finds a key, else a prepaid
   router. Every comparison in both orders. Reported: kappa of each judge and of the majority against
   the owner, flip rate, and whether the same-family judge ranks the arms differently from the others.
   If the panel's kappa against the owner is below 0.6, it is reported as not usable and nothing more.
4. **Ruled out:** the consumer chat by hand (spends the scarcest resource and cannot be reproduced);
   the local models for now (two unverified steps before a first result).
5. **Exposure rule.** Only pairs whose whole content is already in a public repository may be sent, and
   only after the leak scan passes on the exact text to be sent.

What would change this: if day-8 data shows the owner cannot keep up with judging, an AI judge with a
kappa above 0.8 against him on 50 or more pairs could take over a stated share of secondary marks. That
would be a deviation, logged in section 14 before it starts.

## 11. Reporting and stopping rules

- **Fixed horizon.** The first report is written on 2026-11-19 from whatever data exists, with no
  option to stop early or run on. Looking at accumulating numbers changes no rule in this document.
- **Private checkpoints** on fixed dates, every two weeks from 2026-12-03, not published. Because the
  owner is also the judge, a checkpoint shows him only pipeline and data-quality counts (pairs, graded
  share, exclusions, blinding level, minutes per pair). Estimates by arm are not rendered between
  publishes. A checkpoint cannot trigger a publish.
- **Second publish.** On a date set now, 2027-01-15, with whatever data exists (**OPEN**, ADK-160). A
  pair count is not a trigger, because the owner's own pace sets it. Intervals are not adjusted for
  the day-8 look; the report says so.
- **Every report shows** all primary and secondary measures of section 6, including the unflattering
  ones, the pilot table, exclusions, ungraded counts, the blinding level reached, and section 14.
- **Registration date.** This file's local commit is the registration. An outside reader can verify
  only the date it first appears in the public repository, and the repository's history is being
  rewritten for an unrelated clean-up, so commit IDs will change. Until the push, the proof is the
  file's sha256 recorded in the local data store. A public timestamp of that hash, before the first
  confirmatory pair, is **OPEN** as ADK-161; pairs run before it exists are flagged in every report.
- **Open rows.** ADK-121, 153, 157 to 162 are open at registration. The text proceeds on each
  recommendation; an answer that changes the text is a section 14 entry.

## 12. Threats to validity

- One judge who is also the owner of the work and of the kit. Blinding and the guess rate bound it;
  they do not remove it.
- One setup, one owner's tasks, a few projects. Nothing here generalises without replication.
- Tasks are not independent, and the cluster count will be small at day 8.
- Replays can leak hindsight; the sandbox and one hand-checked transcript guard it (design, L4).
- Grading by git history scores a real finding as false when nobody ever fixed it. This biases against
  the arm that finds more; findings history cannot confirm go to the owner for that reason.
- The reference set for a review is built from the two arms, so a defect both miss is invisible. Review
  acceptance is relative, not absolute.
- Price weights are list-price ratios, not what anyone paid. Cache behaviour differs by run order;
  the order is randomized and recorded so it can be checked.
- Models behind an alias can change mid-study. The arm is the model in the transcript; a version change
  starts a new arm.
- The formatting schema removes style signals that may carry real quality (a clear summary is worth
  something). The owner's overall preference is collected on the normalized text only.

## 13. Data in hand that this plan does not use

- The cache-read and cache-write split per run: could show whether the arm that runs second is cheaper
  for reasons unrelated to the model. Recorded; analysed only as a check on run order.
- The owner's free-text notes on a pair (P-001 has one on trust): not coded, so not analysed.
- Time of day and plan-quota state at dispatch: recorded in transcripts, not in any measure here.
- Tool-call mix per run (reads, searches, shell): could explain cost differences; exploratory only.

## 14. Deviations log

Any change to sections 1 to 11 after the registration commit is listed here before the data it affects
is analysed: date, section, what changed, why, and whether any outcome data had been seen.

| Date | Section | Change | Why | Outcome data seen? |
|---|---|---|---|---|
| 2026-11-12 | 11 | ADK-157, 158, 160 and 162 answered as registered; their OPEN marks are closed. ADK-161: the proof is an OpenTimestamps stamp of this file's sha256. Version 1.0 was stamped on 2026-11-12; every later version is stamped the day it is committed, and the proof files are published with the repository. | Owner's answers | no |
| 2026-11-12 | 9 | Owner consistency: 20 rows are re-rated at day 8 (was 10, ADK-159). Which marks are re-rated is **OPEN**, ADK-164. The ordinary daily overread may also carry up to 2 pairs, on top of the blind-grading time. | Owner's answers | no |
| 2026-11-12 | 5, 6 | The single confession rate is replaced by: confession recall (of errors another detector found, the share the agent had confessed first), per severity level; confession precision (confessed items the owner marks real at severity 1 or 2, over confessed items); and the count of severity-3 confessions per arm. The marker sets severity, never the confessor. The brief's wording on confession is the same in both arms and states no weights. | An agent can confess trivia to look honest | no |
| 2026-11-12 | 5, 6 | Arms are compared only on detectors applied equally to both: scripts, history and the owner's blind marks. Errors that need use to surface (owner-called, reviewer-found, escaped) and outcome records are shown for the used arm in their own column, never as a paired difference. | They can arise only for the arm the work used | no |
| 2026-11-12 | 4, 5 | Each dispatch gets an outcome record, by script where possible: output used, accepted, rejected or redone; cap hit; for reviews, each finding fixed, dismissed or deferred. | Not recorded before | no |
| 2026-11-12 | 4, 5 | Both arms are dispatched at once, or the first arm is drawn at random and logged. The cache-read and cache-write split is recorded per arm, and cost is also reported with cached tokens priced as uncached, as a sensitivity line. | The second run can be cheaper for reasons unrelated to the model | no |
| 2026-11-12 | 4, 12 | The sampler row, written before the draw, gains: origin (work-driven, study-driven, about the study itself) and the dispatcher's actual model. Reports give counts per origin, a sensitivity line without the last two origins, daily dispatch counts against the pre-sprint rate, and a split of pairs whose dispatcher is the same model as an arm. New threat for section 12: the dispatcher that writes every brief is of the family under test. | Tasks can be made to feed the study; a brief can favour its writer's own model | no |
| 2026-11-12 | 9 | Per pair, the owner records whether he saw the used output or its effects before marking (yes or no) and a 1 to 3 confidence on the model guess. Reports add a sensitivity line without the yes pairs. Review pairs are judged before use where the work can wait. | Use before judging unblinds a live pair | no |
| 2026-11-12 | 7 | Q2 below the bootstrap thresholds: the ratio is shown with a pair-level bootstrap labelled "ignores clustering". Resamples with no accepted output in an arm are counted; above 5% of resamples, no interval is shown. | No interval was defined for day 8 | no |
| 2026-11-12 | 11 | Before marking, the sha256 of both captured outputs and of the mapping is appended to a log, and that log is OpenTimestamps-stamped daily. Each report publishes a per-pair row table (no transcript text) and the analysis script with its commit and seed. The script is written and tested on simulated data before the first confirmatory pair. | An outsider could check the plan's date but not the data | no |

"Outcome data seen?" is "no" where no confirmatory pair existed; the pilot pairs P-001 and P-002 had
been seen. Version 1.1 is this file after the 2026-11-12 rows. **OPEN** at version 1.1: ADK-121, 153,
163 (the newest model version as an arm), 164 (what the re-rate re-marks), 165 (same-model control pairs).

## 15. Sources and prior work

Read on 2026-11-11 by a research subagent of session a710c44f; this session did not re-open them. "Abstract"
means only the abstract was read. arXiv IDs are given so each can be checked.

- Miller, "Adding Error Bars to Evals", arXiv 2411.00640 (full text read). Recommends clustered standard
  errors for related questions, inference on question-level paired differences, power analysis, and
  reporting pairwise differences with standard errors. Its "about 969 questions for a 3-point difference
  at 80% power" is an illustrative example with a paired-difference variance of 1/9, in the paper's
  section 5, not in the vendor's blog post. Arithmetic re-checked here by script. At this study's
  assumed 30% discordant pairs the variance is about 0.3, so the same 3 points would need about 2,600 pairs.
- Zheng et al., "Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena", arXiv 2306.05685 (abstract).
  Names position, verbosity and self-enhancement bias. What it says on swapping order: not verified.
- Panickssery, Bowman, Feng, "LLM Evaluators Recognize and Favor Their Own Generations", arXiv 2404.13076
  (abstract). Self-recognition is above chance and correlates with self-preference.
- Verga et al., "Replacing Judges with Juries", arXiv 2404.18796 (abstract). A panel of smaller models
  from different families beat one large judge, with less intra-model bias, at a fraction of the cost.
  The panel's members: not verified.
- Pombal, Rei, Martins, "Self-Preference Bias in Rubric-Based Evaluation of LLMs", arXiv 2604.06996
  (abstract). Self-preference persists with programmatically checkable rubrics; ensembles reduce it and
  do not remove it. A counterpoint, Chen et al., arXiv 2504.03846, was seen as a search result only.
- Soumik, "Judging the Judges", arXiv 2604.23178 (abstract). Style bias (markdown over prose) larger
  than position bias. One single-author paper, no replication found: a reason for section 9's
  normalization, not a settled fact.
- The claim "reliable and biased at once, so report kappa" was traced to arXiv 2606.19544, which arXiv
  withdrew on 2026-11-03. It is not cited as support. Kappa beside percent agreement is standard
  practice (Cohen 1960, from memory, unverified).

**What is not new, and what may be.** Cost as a headline metric is established: Cost-of-Pass (arXiv
2504.13359), "AI Agents That Matter" (2407.01502), the Holistic Agent Leaderboard (2510.11977) and
public coding leaderboards with a cost column. A randomized trial on real repositories exists (METR,
2507.09089), comparing AI with no AI, not model with model. Pre-registered LLM evaluations exist.
Practitioner posts already use the phrase "cost per accepted task". The search found no prior study
combining all of: two models paired on the same sampled delegation tasks in a real repository,
script-assigned blinded human grading, and cost per accepted output as a registered primary outcome.
A search of about 35 steps is not proof of absence. The wording any report may use: "We found no prior
study that pairs two models on the same sampled tasks in a real repository with blinded human grading
and a pre-registered cost per accepted output." The stronger "nobody has published" is not used.
