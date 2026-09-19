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

---

## 2026-09-18, session 3: verification, and Haiku measured

The first session that did not build anything. It ran the verification brief
from the plan, in a fresh context, because the maker does not verify its own
work and could not have anyway: the definitions had only just been installed.

**V1, the question the whole kit rested on.** A `general-purpose` subagent was
dispatched with no `model` argument and no mention of a model in its prompt,
and asked to count the lines in a file. The parent session was running Opus 5.
Every assistant turn in the subagent's transcript says `claude-sonnet-5`. So
the `env` block of the user settings file does deliver
`CLAUDE_CODE_SUBAGENT_MODEL` to subagent model resolution. This had been
listed as not verified since the plan was written, with a fallback ready
(set it as a Windows user environment variable instead). The fallback is not
needed on this machine and has been struck from the status document.

**V2, and a correction to the plan.** The brief wanted a named type dispatched
from the Goldshell project directory, to settle whether a session launched two
levels down finds a user-level definition. A subagent dispatched from the kit's
own session would have inherited the wrong directory and settled nothing, so
V2 ran as a headless session actually launched in the Goldshell directory,
which then dispatched `scanner`. The transcript, filed under the Goldshell
project slug, says `agentType: scanner` and `claude-sonnet-5`, under a parent
on Opus. User-level definitions are found from a project directory two levels
down, with no project-level copy present.

Two things worth recording rather than smoothing over. The plan said the
Goldshell project has no `.claude` directory; it has one now, holding
worktrees and no agent definitions, so the premise held. And the headless
session's scanner was refused the file read, because a session launched in one
project may not read a path outside it. That is a working-directory permission
boundary, not a tiering result, and it is the reason V2 returned no line count.

**V2 proves less than it looks.** `scanner` pins `model: sonnet` in frontmatter
and the environment variable also says `sonnet`. Both layers point at the same
answer, so V2 alone cannot say which decided it. V1 is the clean test of the
variable, because `general-purpose` has no frontmatter to pin. Said here
because a verification that quietly claims more than it showed is worse than
none.

**V3, and level 1 beating level 2.** The same scan was run twice, once as
`scanner` is defined and once with `model: "haiku"` on the call. Haiku ran.
That is the documented precedence order observed on this machine from a
transcript rather than taken from the documentation: a per-call model outranks
the definition. It is also the third known gap in the README, demonstrated. The
kit prevents forgetting. It does not prevent deciding.

**Haiku measured, and the answer was no.** The scan was a 1,371-line browser
file, four questions: two counts, a list of backend endpoints, and how the page
keeps two requests off the miner at once. Mark was not available to name the
file, so the session picked one and flagged the choice for him to overrule; the
6.3 MB CSV that started all this is not in the Goldshell repository.

Both models got the counts and the timers exactly right, and both described the
`busy` flag correctly. On the endpoint list they disagreed, and Haiku was wrong
in both directions: it dropped two real backend endpoints, and it folded eight
miner firmware paths, which sit on a different host behind a different token,
into a list it headed "backend API paths". Sonnet listed the backend endpoints
and then said separately that the miner paths reach the wire through the same
generic sender, which is the distinction the question existed to draw. Sonnet
also found three endpoints built as fields on request objects rather than as
literal fetch arguments, which the dispatching session's own grep had missed.

The cost went the wrong way too. Haiku took 2.5 times the tokens and twice the
wall clock: thirty assistant turns against fifteen, and each turn re-read the
context, which is where a 6.4-fold cache-read figure comes from. Per token
Haiku is far cheaper, so on price the two land near each other; on latency
Haiku is plainly worse, and the token saving the change was meant to buy never
appeared.

**Recommendation, Mark's to accept or refuse:** leave `scanner` on Sonnet. One
task on one file is evidence, not a law, and a purely mechanical counting job
with no classification in it might still go to Haiku. But the case for moving
the type wholesale is not there.

**V4 not run**, as the brief allows: no page check was queued, so
`browser-checker` remains defined and not exercised. `executor` likewise, and
with it `isolation: worktree` from a directory that is not a git repository.
Both are still unexercised and the README still says so. Four dispatches, the
budget the brief set, no error twice.

**A test that the session's own working method broke.** The verification work
was done in a git worktree, and the hygiene check failed at once. In a normal
clone `.git` is a directory and `--exclude-dir=.git` skips it; in a worktree
`.git` is a *file* holding an absolute `gitdir:` path, which is exactly the
shape the leak detector hunts for, and `--exclude-dir` does not skip a file.
The same failure reaches the main checkout, because a worktree created under
`.claude/` puts one of those files inside the tree the main checkout scans. The
fix is `--exclude=.git` alongside `--exclude-dir=.git`, with the reason written
above the function. Proved both ways, per the rule in `AGENTS.md`: a leak
planted in a throwaway file was caught, and a leak planted in `.gitattributes`
was caught too, which is what rules out the new exclusion quietly swallowing
every dotfile whose name starts with `.git`.

**What changed in the repository.** This entry, the README's Status section,
which now records the tiering as demonstrated rather than assumed and keeps the
unexercised types honest, and the hygiene test fix. The raw commands and output
live in the gitignored evidence directory, because they name local paths.
Ninety-six tests pass.

---

## 2026-09-18, session 3, addendum: the trigger file found, and the Haiku advice revised

Mark read the verification, named a file of his own for the scan test, and
asked where the 6.3 MB CSV had gone, suggesting it was local rather than in
git and that earlier session transcripts might say. Both were right, and both
changed the conclusion above.

**The file.** It is the gbox service's own `log.csv`, in a dot-directory under
the home directory, which is why no repository holds it. A `scanner` found it
by grepping session transcripts for the comma-formatted token figure and
reading the surrounding sentence, then matching the path against disk; it
noted, unprompted, that a filesystem sweep alone would have missed it because
that directory was not in the list it had been given. Two properties matter
more than the path. The log is **live**, 6.3 MB when it caused the incident and
7.55 MB now, so the careless delegation gets dearer every day. And its schema
changed partway through: the later columns are empty for the first third of the
file, which is what the sibling `log.csv.pre-0.6.0` is a relic of. An average
over one of those columns, taken naively, is wrong.

**A hazard the session walked into while checking.** Ground truth was taken
twice, minutes apart, and the row count had moved, because the log is appended
every poll. Both agents' counts were right when they ran; the *checker's*
number was the stale one. Verifying a scan of a live file means timestamping
the ground truth, or the verification invents a discrepancy.

**The comparison, re-run on the real thing.** Both models got every checkable
number right on a 7.5 MB, 37,500-row file: rows, span, error count, error
rate, mean and maximum of the partly-populated column, and the exact row where
the schema changes. Both grouped ten distinct error strings sensibly and
differently, Haiku by symptom and Sonnet by subsystem, Sonnet's split pulling
authentication failures out as their own mode. Haiku volunteered a correct
clustering result that Sonnet had explicitly listed as not checked.

**The cost argument reversed.** On the file this session had picked, Haiku cost
2.5 times as much. On the two files Mark named it cost **less**: 19% fewer
tokens on the telemetry log, 17% fewer on the curl transcript. The earlier
claim that Haiku is dearer was true of one file and is not a general result.
Recorded as a correction rather than quietly smoothed.

**What survives is calibration.** In two of three tasks Haiku's prose claimed
more than its own correct numbers supported: an endpoint that "appears stable"
after a race test that could not have detected a race, and a miner that
"continues functioning even when monitoring can't reach it", which a timeout
does not establish. Sonnet hedged where the evidence was thin and ended its
report with a list of what it had not checked. For a type that exists so the
dispatching session can act on a conclusion **without reading the data**, an
overconfident conclusion is the expensive failure. A few thousand tokens is
not.

**Recommendation, revised and still Mark's to settle:** keep `scanner` on
Sonnet, on calibration grounds alone. Drop the cost argument, which the
evidence no longer supports. If the cheaper tier is wanted anyway, the fix
belongs in the prompt rather than the model: require a "what I did not check"
section and forbid verdicts the columns cannot carry.

**The number worth remembering.** The incident that started this repository
spent 74,381 tokens on that file. The same class of question, on a file now 20%
larger, cost 17,400 tokens on Sonnet and 14,131 on Haiku. Four to five times
cheaper, and it comes from the type's "find the shape, then query it"
discipline rather than from the tier. That is the kit working, measured on the
file that prompted it.

---

## 2026-09-18, session 3, close: reviewed, merged, and what is still untested

**Mark's word, after a light review:** merge the verification branch. This
entry is written on that branch, so it is part of what `main` becomes. The two
commits are the verification itself and the correction that followed; the
history is deliberately left as two, because the second one overturns a claim
the first one made and collapsing them would hide that.

**Where the kit stands.** The default is demonstrated, not assumed: an
unpinned subagent dispatched from an Opus session runs Sonnet, and a transcript
says so. A user-level type resolves from a project directory two levels down.
A per-call model outranks the definition. `scanner` has now been exercised on
three real files, one of them the 7.5 MB telemetry log that caused the incident
this repository exists to answer.

**What is still untested, said plainly because the README says it too.**
`executor` has never run. `reviewer` has never run. `browser-checker` has never
run. `isolation: worktree` from a directory that is not a git repository is
still a guess. Three of the four types are shape-tested and nothing more, and
one verification session does not change that. The next session that needs any
of them should treat its first dispatch as an experiment with a witness, not as
production.

**A small irony worth keeping.** The session that verified the kit broke the
kit's own test suite by using a git worktree, because `.git` is a file there
and the hygiene check only excluded a directory of that name. The bug was real
beyond the worktree: a worktree created under the configuration directory sits
inside the tree the main checkout scans, so the main checkout would have begun
failing too. It was found by running the tests rather than by reasoning about
them, which is the argument the repository makes about prose and mechanism,
turned on the repository.

**Three method notes the next session should not have to rediscover.**

- A subagent's transcript is filed under the slug of the *working directory*.
  Move into a worktree and the transcripts move with you. Anyone applying the
  README's "prove which model ran" recipe after a worktree switch has to look
  under the worktree's slug.
- The telemetry log is appended every poll. Ground truth taken to check a scan
  of it can go stale between two commands, and did: both agents' row counts
  were right and the checker's was the stale one. Timestamp the ground truth
  or the verification invents a discrepancy.
- The file that caused the incident was found from session transcripts, not
  from the filesystem. It sits in a service's dot-directory that no sweep of
  the obvious places would reach. When something is missing, the transcripts
  are evidence.

**Next.** Mark asked for a public write-up of the problem and the kit, to be
drafted now and read later. Beyond that the queue is unchanged: the Goldshell
tranche, which is the work all of this was meant to make cheaper and better
judged, and then the Mac gate, the three-strikes edit hook, the dispatch hook
and the restructure of the shared instructions.
