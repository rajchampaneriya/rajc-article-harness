# ADR 0001: Pi Durable for the article harness

- **Status:** Proposed
- **Date:** 2026-11-19
- **Deciders:** Raj Champaneriya

## Context

The spike chose option B: each worker is a stateless gh-aw run with the Pi engine. GitHub holds
all state (issue, PR branch, `style/voice.md`); the runner keeps nothing between runs. That rule
exists because rajc-mate kept a local clone and worktree, and the local state drifted and lost pushes.

Earendil released [Pi Durable](https://github.com/earendil-works/pi/tree/main/packages/durable)
with Pi 1.0 on 2026-10-01. It is an experimental TypeScript library for agent applications that
survive crashes: it commits conversation entries and execution state to storage as it works, and
can resume an unfinished run when the storage is reopened. It is a library to build an app on,
not a drop-in for the `pi` CLI that gh-aw runs.

An interview is a conversation that spans days. Today each `/interview` or `/spike` rebuilds
context from the issue thread. The question is whether a durable runtime should own that conversation.

## Options

| | A. Stay stateless on gh-aw | B. Move workers to Pi Durable | C. Hybrid |
|---|---|---|---|
| Where state lives | GitHub only | Pi Durable storage, mirrored to GitHub | GitHub is the record; Pi Durable only for a future long-running interviewer |
| Host | GitHub Actions, nothing to run | A persistent host plus storage (SQLite, Postgres or similar) | Actions now, a host later if needed |
| Guards we keep | firewall, safe outputs, integrity filter, role gate | must be rebuilt in app code | all of A for workers that write |
| Crash recovery | rerun the slash command; runs are short and idempotent | resume mid-run | resume only where a run is long |
| Maturity | gh-aw v1.2.x, proven in the spike | experimental; API may change between releases | experimental part is isolated |
| Fits "GitHub holds all state" | yes | no, a second source of truth | yes, if Durable storage is a cache |

## Decision (proposed)

Choose **A for phase 1** and record **C as the path** if a trigger below fires. Runs today are
minutes long and cheap to repeat, so resuming mid-run saves little. Pi Durable would bring back a
second state store and a host to run, which is the failure this harness was built to remove.

## Revisit when

- An interview or draft run regularly exceeds the 15-minute timeout or fails mid-run.
- The writer wants a live back-and-forth (for example voice or chat) instead of issue comments.
- Pi Durable leaves experimental status, or gh-aw adds a durable engine mode.

## Consequences

- Context is rebuilt from the issue on every run. Follow-up prompts rely on the thread being
  readable, which is why the integrity filter must trust every account the writer uses.
- No new infrastructure or secrets. The open risks in `docs/architecture.md` stay as they are.
- A spike for option C would be one worker (the interviewer) on Pi Durable, writing to GitHub
  only through the same narrow outputs, with its storage treated as disposable.
