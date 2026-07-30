---
name: wait
description: Wait a set duration or until a wall-clock time, holding the Mac awake, then carry out a queued prompt. Use for "/wait 40m <prompt>", "/wait 1hr", "wait until 3pm then ...", or whenever work has to pause until a usage window resets.
---

# wait

Pause for a duration or until a clock time, keep the Mac awake across that window,
then do whatever was queued behind the wait.

Primary use: the Claude usage window is spent and resets shortly. Arming the wait
costs one cheap turn now; the queued work runs on the fresh window.

## Steps

1. Resolve the deadline.
2. Arm one backgrounded `caffeinate` command.
3. End the turn immediately — do no other work.
4. On the wake notification, execute the queued prompt.

### 1. Resolve the deadline

**Relative**: `40m` `40min` `1h` `1hr` `2h30m` `90s`. A bare number means minutes, so
`/wait 40` is 40 minutes.

**Absolute**: `3pm` `15:30` `3:15pm` — the next occurrence, rolling to tomorrow if
that time has already passed today.

Resolve to an epoch second:

```bash
date +%s           # now
date -v+40M +%s    # 40 minutes out (BSD date)
```

If the result is more than ~6 hours out, stop and confirm with AskUserQuestion
before arming. That is nearly always a typo — `/wait 400m` reads as 400 minutes.

### 2. Arm the wait

A single `Bash` call with `run_in_background: true`, with the epoch deadline
substituted in:

```bash
caffeinate -i sh -c 'until [ $(date +%s) -ge 1785350000 ]; do sleep 20; done'; echo "WAKE: wait elapsed at $(date +%H:%M:%S)"
```

Why this exact shape:

- **`caffeinate -i`** blocks idle system sleep for the window and dies with the
  command it wraps. Nothing to clean up — no PID file, no Stop hook, no re-up.
- **An absolute deadline, not `sleep N`.** If the Mac sleeps anyway (lid closed, or
  on battery where `-i` cannot hold it), a `sleep` timer stalls and overshoots by
  however long the machine was out. The `until` loop wakes at the target time
  regardless of what happened in between.
- **Backgrounded** is what makes any of this possible: the harness re-invokes the
  agent when a background command exits. A foreground wait cannot work — Bash caps
  at 10 minutes and foreground `sleep` is blocked outright.

Do not reach for Monitor here. Its own guidance is explicit that a single
notification on a condition belongs to background Bash, not to a monitor.

The working phase afterwards needs no caffeinate of its own — Claude Code asserts a
rolling `caffeinate -i` while it is actively working, and tears it down on exit.
The gap this skill fills is the *idle* wait, where that assertion lapses.

### 3. End the turn

State the wake time in one line, then stop:

> Waiting until 15:30 (40m). Mac held awake; I'll pick up the refactor then.

Do not begin the queued work and do not investigate ahead of it. The point is to
spend as little of the exhausted window as possible.

### 4. On wake

The completion notification arrives as a fresh turn. Read the queued prompt back
out of the conversation and **just do it** — no confirmation, no check-in. The wait
exists precisely so the work resumes unattended.

If the session was used during the wait, reconcile rather than replay: account for
changes already made instead of re-running the original request from scratch.

If nothing was queued (`/wait 40m` on its own), say the wait is up and stop.

## Limits

- **Already hard-blocked?** This skill cannot help. It runs *as* the agent, so the
  agent has to be able to run. Arm the wait before the window is fully spent. Once
  requests are being rejected, use `denter <minutes>` from the shell instead — it
  sleeps, caffeinates, and presses Enter for you from outside the agent.
- **Lid closed on battery**: `caffeinate -i` will not prevent sleep. The absolute
  deadline downgrades that from a missed wake to a late one.
- **Hitting the limit again** after resuming does not self-recover. Re-arm manually.
- **macOS only.** `caffeinate` does not exist on Linux; `systemd-inhibit --what=idle`
  is the equivalent if this ever needs to work there.
