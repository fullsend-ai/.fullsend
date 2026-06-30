# Dynamic Child Pipeline Prioritization

**Date:** 2026-05-05
**Status:** Approved

## Problem

The prioritize workflow runs on a cron schedule and scores one issue at a time. With a 10-minute interval and ~10-minute agent runtime, throughput is at most 1 issue per 10 minutes. This is too slow for boards with many unscored issues.

## Solution

Replace the single-issue cron workflow with a dynamic child pipeline pattern:

1. **`prioritize.yml`** becomes an event-driven agent workflow (like triage), scoring one issue per run.
2. **`prioritize-scheduler.yml`** is a new cron-triggered dispatcher that finds unscored/stale issues and launches up to `PRIORITIZE_WIP_LIMIT` (default 5) parallel prioritize runs.

This also enables `/prioritize` as a slash command on issues, routed through the existing shim/dispatch infrastructure.

## Architecture

### Prioritize Workflow (`prioritize.yml`)

Changes from cron-triggered to `workflow_dispatch` with inputs matching triage's interface:

```yaml
on:
  workflow_dispatch:
    inputs:
      event_type:
        description: 'Original GitHub event type'
        required: true
      source_repo:
        description: 'Repository (owner/repo)'
        required: true
      event_payload:
        description: 'GitHub event payload as JSON'
        required: true
```

- Cron `schedule` trigger removed entirely.
- Concurrency changes from global `fullsend-prioritize` to per-issue: `fullsend-prioritize-<issue-number>` with `cancel-in-progress: true`.
- Remains org-scoped: creates empty `target-repo` directory, no repo checkout.
- Issue URL extracted from `event_payload` by the pre-script.

### Prioritize Scheduler (`prioritize-scheduler.yml`)

New workflow. Cron-triggered (every 10 minutes) + manual `workflow_dispatch`.

Single job that:

1. Generates a GitHub App token (same app as prioritize).
2. Queries the project board for items where RICE Score field is null (unscored).
3. If all scored, finds items with stale scores (oldest update > `STALE_THRESHOLD`).
4. Takes the first N issues, where N = `PRIORITIZE_WIP_LIMIT` repository variable (default 5).
5. For each issue, calls `gh workflow run prioritize.yml` with a synthesized event payload matching the format a repo shim would send for a `/prioritize` command.

Concurrency: `fullsend-prioritize-scheduler`, `cancel-in-progress: true`.

This is a plain GitHub Actions job with `gh` CLI calls. No agent invocation, no sandbox, no pre/post scripts.

### Shim & Dispatch Integration

- Repo shims in enrolled repos dispatch `/prioritize` commands through the existing shim pattern, firing `workflow_dispatch` on `.fullsend`.
- `dispatch.yml` routes by `# fullsend-stage: prioritize` marker on the workflow. The refactored `prioritize.yml` keeps this marker.
- `config.yaml` already registers the prioritize role.
- Prioritize is org-scoped, so `source_repo` is informational (concurrency grouping, logging). The pre-script does not validate repo enrollment.

## File Changes

### `.fullsend` repo

| File | Change |
|------|--------|
| `.github/workflows/prioritize.yml` | Rewrite: cron → workflow_dispatch, per-issue concurrency |
| `.github/workflows/prioritize-scheduler.yml` | New: cron dispatcher, issue selection, `gh workflow run` loop |
| `scripts/pre-prioritize.sh` | Rewrite: extract `GITHUB_ISSUE_URL` from event payload, validate format |
| `env/prioritize.env` | Add `GITHUB_ISSUE_URL` export |
| `harness/prioritize.yaml` | Minor: adjust env mount (URL from workflow input, not discovery) |

### `fullsend-ai/fullsend` PR #603

Mirror all changes under `internal/scaffold/fullsend-repo/`:

| File | Change |
|------|--------|
| `internal/scaffold/fullsend-repo/.github/workflows/prioritize.yml` | Same as `.fullsend` |
| `internal/scaffold/fullsend-repo/.github/workflows/prioritize-scheduler.yml` | New: same as `.fullsend` |
| `internal/scaffold/fullsend-repo/scripts/pre-prioritize.sh` | Same as `.fullsend` |
| `internal/scaffold/fullsend-repo/env/prioritize.env` | Same as `.fullsend` |
| `internal/scaffold/fullsend-repo/harness/prioritize.yaml` | Same as `.fullsend` |
| `internal/scaffold/scaffold_test.go` | Update for new scheduler workflow file |

### Files unchanged

- `agents/prioritize.md` — agent definition unchanged, already expects `GITHUB_ISSUE_URL`
- `scripts/post-prioritize.sh` — writes RICE scores to board, unchanged
- `schemas/prioritize-result.schema.json` — output schema unchanged
- `policies/prioritize.yaml` — sandbox policy unchanged
- `config.yaml` — already registers prioritize role

## Error Handling

- **Zero issues found:** Scheduler exits successfully with a log message. No dispatches.
- **Dispatch failure:** Scheduler logs the error and continues dispatching remaining issues. Does not fail the whole run.
- **Duplicate dispatches:** Per-issue concurrency group with `cancel-in-progress: true` handles races between scheduler and manual `/prioritize` commands.
- **Exit code 78 (nothing to do):** Moves from pre-script to scheduler. Pre-script no longer needs this — if it receives an issue URL, it always proceeds.

## Configuration

| Variable | Location | Default | Purpose |
|----------|----------|---------|---------|
| `PRIORITIZE_WIP_LIMIT` | Repository variable | `5` | Max parallel prioritize runs per scheduler tick |
| `PRIORITIZE_STALE_THRESHOLD` | Repository variable | `7d` | Re-score threshold for already-scored issues |
| `FULLSEND_PROJECT_NUMBER` | Repository variable | — | GitHub Projects V2 board number |
