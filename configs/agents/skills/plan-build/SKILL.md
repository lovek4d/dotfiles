---
name: plan-build
description: Take a written plan MD and drive it to a finished, committed implementation — harden the plan through adversarial subagent review rounds, build each phase with a fresh subagent, verify the result against the plan, then grill the user on every assumption made along the way. Use for "/plan-build <plan.md>", "build out this plan", "implement the plan in <file>", or whenever a plan MD exists and the work should now happen.
---

# plan-build

A plan MD already exists. This skill turns it into merged work without the user
babysitting each step.

Four stages, in order. Do not skip ahead — stage 2 depends on a plan whose phase
boundaries survived stage 1.

1. **Harden** the plan through review rounds until reviews stop changing it, then commit it.
2. **Build** each phase with a fresh subagent that self-reviews and commits its own phase.
3. **Verify** the whole implementation against the plan.
4. **Grill** the user on the assumptions accumulated along the way.

## Role split

The agent running this skill is the **conductor**. Opus-class context, held across
the whole run. It reads, triages, decides, and rewrites the plan.

It does **not** write implementation code. Every phase goes to a fresh Sonnet
subagent. The moment the conductor starts editing source files itself, the
per-phase context isolation that makes this work is gone — the conductor's context
fills with phase-1 detail and phase-6 gets built by an agent that is 80% distracted.
Conductor edits are limited to the plan MD, the assumptions ledger, and small
triage fixes in stage 3.

## Setup

Before stage 1:

- Resolve the plan path. If the argument is missing, look for the most recently
  modified `*.md` under `docs/plans/`, `plans/`, or the repo root, and confirm with
  AskUserQuestion rather than guessing.
- Confirm a clean working tree and a non-default branch. If on `main`/`master`,
  create a branch off it — this skill produces many commits.
- Create the assumptions ledger at `<scratchpad>/assumptions.md` and note the
  absolute path. Every subagent gets handed this path. Seed it with the header
  from [Assumptions ledger](#assumptions-ledger).

Announce the plan path, branch, and phase count in one line, then start.

## 1. Harden the plan

A round is: fan out reviewers → triage findings → rewrite the plan. Repeat until a
round is noise, then commit.

### Fan out

Four subagents per round, **in parallel in one message**,
`subagent_type: "general-purpose"`. Each is read-only: it reports findings, it does
not touch the plan.

Give each a different lens. Identical prompts produce identical findings and the
round teaches you nothing:

- **Completeness A** — `model: "haiku"`. What does the plan not say *about its own
  steps*? Missing error paths, migrations, config, backfills, ordering it never
  states. Are the phase boundaries real — does each phase leave the tree green and
  shippable, or does phase 3 only make sense once phase 4 lands?
- **Completeness B** — `model: "haiku"`. What does the plan not say *about
  everything around the change*? Tests, docs, observability, rollout, feature flags,
  the people or systems downstream of it.
- **Feasibility** — `model: "sonnet"`. Read the plan against the actual codebase.
  Which steps assume functions, files, schemas, or behavior that do not exist or do
  not work as described? Which are more invasive than the plan implies?
- **Risk** — `model: "sonnet"`. Blast radius, backwards compatibility, data loss,
  concurrency, the rollback story. What is the worst thing that happens if this ships
  as written?

**Why the models are split this way.** Completeness is a recall problem — read the
plan, notice what a complete plan would have that this one lacks. What makes it work
is the empty context, not the depth, so Haiku gets most of the value and two cheap
readers beat one expensive one. Feasibility and risk are the opposite: the useful
finding is "step 3 is more invasive than it looks" or "this loses data under
concurrent writes," which needs the codebase held in mind and reasoned about. A cheap
agent there mostly confirms superficially or invents problems.

That asymmetry is the reason not to push cheaper still. False positives do not
disappear — they move onto the conductor's triage, and the conductor is the one
component that cannot be handed fresh context. Findings that are cheap to generate
and expensive to dismiss are a bad trade for the piece of this design that degrades.

Every reviewer prompt must carry:

- The plan path, and the instruction to read the surrounding codebase, not just the MD.
- **The rejected-findings list** (see below) verbatim, with: "these were raised and
  deliberately rejected for the reasons given — do not raise them again."
- An output contract: each finding as *what is wrong* → *why it matters* → *what the
  plan should say instead*. Severity-ranked. No prose preamble.
- "If the plan is sound on your axis, say so and return nothing. Do not manufacture
  findings to look useful."

That last line matters. Reviewers asked for a critique will always produce one; you
need them able to return empty, or the loop never converges.

### Triage

The conductor decides, not the reviewers. For each finding: **adopt**, **reject**,
or **defer**.

Reject freely. Reviewers see one lens and no history — a good fraction of findings
argue for scope the user deliberately excluded. Every rejection goes into the
**rejected-findings list**, one line: the finding plus the one-sentence reason. That
list is what makes round 3 cheaper than round 1 instead of a rerun of it. Keep it in
the scratchpad; it does not get committed.

Deferrals are for real concerns outside this plan's scope — they go into the
assumptions ledger flagged `follow-up`, and surface during the grill.

Then rewrite the plan. Adopted findings change the text; if nothing changed, the
round was noise.

### Stop

Stop when a round produces **no finding that changes the plan** — all rejected, all
already covered, or all four reviewers returned empty. One clean round is enough;
do not run a confirmation round.

Weight a silent round by who was silent. Both Haiku readers coming back empty means
the obvious gaps are closed, which is worth something but is not the same as the
plan being sound — they are the shallow end by design. A round where feasibility and
risk also return nothing is the one to trust.

Hard cap at **four rounds**. Hitting the cap means reviewers keep finding real
problems, which is a signal about the plan, not about the loop: stop, and put the
open disagreement to the user with AskUserQuestion instead of grinding.

Typical is two to three rounds. A first round with zero findings usually means the
prompts were too vague, not that the plan is perfect — check the reviewers actually
read the codebase.

### Commit the plan

Once hardened, verify the plan states, per phase: scope, files touched, acceptance
criteria, and how to tell it worked. Stage 2 hands each phase to an agent that sees
nothing else — a phase that reads clearly to you now, with full context, may be
unbuildable cold. Fix any that are.

Commit the plan MD alone. This is the reference point every later stage diffs
against; it must exist in history before implementation starts.

## 2. Build the phases

One phase at a time, sequentially. Each phase is a **new `Agent` call** —
`model: "sonnet"`, `subagent_type: "general-purpose"`. Never `SendMessage` to a
previous phase's agent: carrying context forward is precisely what this stage exists
to prevent.

Each phase brief contains:

- The plan path and **which phase** — "implement phase 3, and only phase 3".
- What previous phases already landed: one or two lines plus the commit SHAs. Enough
  to orient, not enough to re-litigate.
- The assumptions ledger path, with the append rules.
- **Self-review before commit**: re-read your own diff against the phase's acceptance
  criteria, run the tests, fix what you find, and only then commit. Report what the
  self-review caught.
- **Commit your phase yourself** — one commit, message naming the phase.
- **Stay in scope.** If the phase cannot be completed as written, stop and report
  back. Do not improvise a redesign and do not implement the next phase.
- **Escalate expensive forks** — see below.

### Escalating a fork

A phase agent that hits a decision the plan does not make has two options: pick and
log it, or stop and escalate. Escalate only when **both** hold:

- **Ambiguous** — two defensible options and nothing in the plan, the codebase, or
  the surrounding conventions picks between them. Not "I had to name a helper."
- **Expensive to reverse** — a later phase, or the user, would pay real rework to
  undo it. Schema shapes, wire formats, public interfaces, anything a migration
  freezes, anything that decides how the remaining phases are structured.

Everything else gets picked and logged. The bar is deliberately high: a phase agent
that stops twice per phase has just turned an unattended run into a conversation.

On escalation the subagent stops, describes the fork and both options, and commits
nothing. The conductor puts it to the user with AskUserQuestion, then re-runs the
phase as a fresh agent with the answer written into the brief. Record the resolution
in the ledger marked `resolved during phase N` so the grill skips it.

Why this and not "log everything, ask at the end": an assumption marked expensive is
exactly the one that must not be built on for four more phases. The end-of-run grill
is the right instrument for cheap and moderate calls, and the wrong one for a schema
choice that phases 4 through 6 have already been written against.

When the subagent returns, the conductor verifies before starting the next phase:

- The commit exists and the tree is clean.
- Tests and lint pass — run them, do not trust the report.
- `git show --stat` matches the phase's declared file scope. Files outside it are a
  scope leak: read them.
- New ledger entries are real assumptions, not narration.
- **Nothing marked `expensive` was logged instead of escalated.** If one was, treat
  it as an escalation now, before phase N+1 builds on it.

Watch the running assumption count. A phase logging five or six real forks is
evidence stage 1 under-specified that phase — the hardening loop converged on a plan
that reads well but does not decide enough. Amend the plan for the remaining phases
rather than letting the ledger absorb the shortfall.

If a phase fails or comes back out of scope: fix it now, before phase N+1. Deciding
between a corrective phase, a re-run with a sharper brief, or amending the plan is a
conductor call — but a broken phase never gets built on. If the failure means the
plan was wrong, amend the plan MD and commit that amendment before continuing, so
stage 3 diffs against what was actually intended.

## 3. Verify against the plan

All phases done. Two subagents, parallel, `model: "sonnet"`, read-only:

- **Conformance** — diff the full branch (`git diff <plan-commit>..HEAD`) against the
  plan. What was planned and not built, built and not planned, or built differently
  than described? Ignore code quality entirely.
- **Quality** — review the same diff as code, ignoring the plan. Bugs, missed error
  paths, thin test coverage, dead code, inconsistency with surrounding conventions.

Both get the plan path, the base commit, and an explicit "report, do not edit".

Triage as in stage 1. Real defects get fixed — small ones by the conductor directly,
anything phase-sized by a fresh subagent. Intentional divergences from the plan are
not defects, but each one is an assumption: add it to the ledger if it is not there
already. That is usually where the most interesting grill questions come from.

## 4. Grill the user

Only now, with the work finished and verifiable.

Read the ledger. Drop entries already settled — anything marked
`resolved during phase N` (you asked mid-flight, it is decided) and anything a later
phase proved correct on its own. What is left should be mostly cheap and moderate
calls, since the expensive ones were escalated when they came up. Rank the remainder
by cost to reverse anyway; a `moderate` that quietly spread across four phases can
outrank the label it was given.

Then walk them one at a time with **AskUserQuestion — one assumption per call**. For
each: state what was assumed and why, and offer the real alternative as a selectable
option, not as prose. The user should be able to answer by picking, without
reconstructing the decision from scratch.

Do not batch these into a summary document and ask "does this all look right?" —
that reliably gets a "yes" and defeats the point. The friction of one question at a
time is the feature.

For each answer:

- **Confirmed** → tick it off, move on.
- **Wrong** → note it. Keep grilling; do not start fixing mid-grill.

After the last one, implement the corrections as one focused pass, then report:
phases built, commits, assumptions confirmed, assumptions reversed and what changed,
and deferred follow-ups.

## Assumptions ledger

Lives in the scratchpad, never committed. Append-only — subagents add, nobody edits
or deletes.

```markdown
# Assumptions — <plan name>

## <phase> — <one-line assumption>
- **Assumed:** what was taken to be true or chosen
- **Why:** what made it the default — plan silence, existing convention, no data
- **Alternative:** the other real option, and what would change if we took it
- **Reversal cost:** cheap | moderate
- **Status:** open | resolved during phase N — <what the user chose>
```

`expensive` never appears as a reversal cost on an open entry — those get escalated
mid-phase and come back written as `resolved during phase N`.

Rules given to every subagent:

- Log it when you **chose between real options and the plan did not decide for you**.
- Log it when you **relied on something unverified** — an API's behavior, a data
  shape, a user intent read between the lines.
- If the entry would be **`expensive`**, do not log it and keep going — stop and
  escalate. The ledger is for calls worth reviewing after the fact, not for
  decisions the rest of the build will be written against.
- Do **not** log what you did. That is the commit message's job. A ledger full of
  "used the existing logger" is a ledger nobody reads at grill time.

Ten sharp entries beat sixty. The conductor prunes at stage 4 anyway, but a noisy
ledger makes that pruning unreliable.

## Notes

- **Model split is deliberate.** Opus conducts, because triage is the one job that
  needs the whole arc in view. Sonnet builds and does the deep review lenses, where a
  miss is expensive. Haiku reads for completeness, where breadth matters more than
  depth and the empty context is the whole point. Spend where being wrong costs the
  most.
- **Interrupted mid-run?** Everything durable is in git and the ledger. `git log`
  against the plan's phase list says where you are. Resume at the next unbuilt phase.
- **Plan with one phase** — run stage 1, skip the fan-out in stage 2 (one subagent,
  same brief), keep stages 3 and 4. The grill is the part users skip and regret.
