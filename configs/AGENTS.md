## Asking Me Questions

**Always use the AskUserQuestion tool.** Never ask in prose — a question buried in
a paragraph gets skimmed, answered "yes", or missed entirely. If you need
something from me, it goes through the tool.

- **One question per call.** Multiple at once is bewildering. Resolve dependent
  decisions in order.
- **Recommend first.** Put your pick as option 1, suffixed `(Recommended)`.
- **Answer it yourself if you can.** A question the codebase answers is a
  question you should have grepped, not asked.
- **Use `preview` when the options differ in shape** — layout, control flow,
  API surface, file structure. Show the thing, don't describe it: an ASCII
  flowchart or a code snippet per option, side by side. Previews are
  single-select only.
- **Blocking questions are last resort.** Do everything independent of the
  answer first, then ask.

Preview example — two options, same question:

```
      option A                        option B
  ┌──────────────┐               ┌──────────────┐
  │  hook (sync) │               │  hook (bg)   │
  └──────┬───────┘               └──────┬───────┘
         │ blocks                       │ fire & forget
         ▼                              ▼
     [ tool runs ]                  [ tool runs ]
```

```zsh
# A: blocking
__notify "done" && exit 0
# B: background
__notify "done" &
```

## Working With Me
- "Why X?" / "do we need this?" asks for reasoning. Answer and stop; if the
  reasoning is weak, offer the change rather than making it.
- Significant work (refactors, extractions, schema changes, rewrites): present
  the full plan and wait for an explicit go before writing files. "Could X be…?"
  is thinking out loud — answer it, don't code it.
- Before building an approved plan, check each "this exists so that X" claim
  actually holds. Report justifications that died, even where the code survives.
- Repo doctrine (CLAUDE.md, ADRs) is guidance, not a veto. If a better design
  contradicts it, argue the merits and propose the doc edit alongside.
- Use my wording verbatim for copy, labels, anything voice-driven. Propose
  alternatives explicitly; never swap in a blander synonym.

## Code
- Simplify means less structure — fewer abstractions, cleaner flow, less state.
  Never shorter names.
- Comments describe what the code does now. History (tried, measured, reverted)
  goes in the repo's decision log (e.g. `docs/adr/`) with a one-line pointer;
  relocate before deleting.
- Don't count things in prose ("three callers") unless the count can't change
  by definition. Name the relation; tooling counts it.
- No defensive checks for impossible states. If firing would change nothing,
  delete it; if it means a real bug, make it a hard error. No debug-only warnings.
- Place logic by its actual consumers (grep them), not by resemblance to what
  already lives there.
- Cache only within a lifetime where the inputs can't change; never cache what
  can be edited underneath.

## Evidence
- Before recommending from a measurement, confirm it was taken on the real
  artifact at the real scale. A proxy number is a hypothesis.
- When a fix depends on unverified framework ordering or timing, instrument
  first (throwaway logs, one run) before building the mechanism.
- Wall-clock timing tests warn, not fail; hard-fail only at ~5x the budget.

## Git
- Commit and PR descriptions come from the actual diff and branch history, not
  the conversation.
- Never push unless asked.
- Small single asks: commit on the current branch, main included. Branch for
  multi-commit work or PRs.

## Shell
- Installed: `fd`, `rg`, `jq`, `sd`, `bat`, `tldr`. Prefer `fd`/`rg` over
  `find`/`grep`.
