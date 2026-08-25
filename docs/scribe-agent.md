# Scribe Agent

The scribe agent reads meeting notes from Google Drive, extracts actionable discussion topics using an LLM (Claude on Vertex AI), and updates the GitHub issue backlog — posting comments on existing issues or creating new ones.

It runs as a scheduled GitHub Actions workflow (Mon–Thu after typical morning syncs) and can also be triggered manually.

## How it works

```
┌────────────┐     ┌─────────────┐     ┌──────────────┐     ┌────────────────┐
│  pre-script │────▶│  LLM sandbox │────▶│  post-script  │────▶│ GitHub Issues  │
│  (host)     │     │  (isolated)  │     │  (host)       │     │ + Slack notify │
└────────────┘     └─────────────┘     └──────────────┘     └────────────────┘
      │                   │                    │
 Fetch Drive notes   Extract topics     Security gates
 Scrub PII           Match to issues    Write comments
 Fetch backlog       Propose new issues Create new issues
```

**Pipeline stages:**

1. **Pre-script** (`scripts/pre-scribe.sh`) — Runs on the GitHub Actions runner. Fetches meeting notes from Google Drive, scrubs PII and structural content (names, Details section), fetches the repo's open/closed issues, PRs, and doc index. Outputs cleaned files to a workspace directory.

2. **LLM sandbox** — The agent runs inside an OpenShell sandbox with network restricted to `*.googleapis.com` only (Vertex AI inference). It reads the pre-processed files, extracts topics, matches them to issues, and writes structured JSON output. It has **no access** to GitHub, Slack, or any other external service.

3. **Post-script** (`scripts/post-scribe.sh`) — Runs on the host after the sandbox exits. Applies deterministic security gates (public safety, sensitive content, Unicode, length, confidence threshold). Only topics that pass all gates are written to GitHub.

## Configuration reference

### Repository variables (Settings → Secrets and variables → Actions → Variables)

These are set on the `.fullsend` repository (or at the org level) and control behavior without requiring workflow file changes.

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SCRIBE_GDRIVE_SEARCH_QUERY` | **Yes** | — | Drive search term for meeting note documents (e.g., `fullsend team sync`). Matched against document names via `name contains '...'`. |
| `SCRIBE_GDRIVE_NAME_FILTER` | No | *(empty)* | Additional substring filter on document names. Useful to narrow results when the search query is broad. |
| `SCRIBE_TARGET_REPO` | No | Current repo (`owner/name`) | Which GitHub repository to read issues from and write to. Set this if the `.fullsend` repo is separate from the target project. Accepts `owner/repo` or just `repo` (owner is inferred). |
| `SCRIBE_DRY_RUN` | No | `true` | Set to `false` to enable live GitHub writes on **scheduled** runs. Manual dispatch has its own dropdown. |
| `SCRIBE_LOOKBACK_HOURS` | No | `3` | How far back (in hours) to search for meeting notes on **scheduled** runs. Manual dispatch has its own input field. |
| `SCRIBE_MIN_CONFIDENCE` | No | `0.6` | Minimum confidence score (0.0–1.0) for topics to pass the security gate. Topics below this threshold are silently rejected. |
| `SCRIBE_MODE` | No | `all` | Agent mode: `all` (comments + new issues), `comments_only`, or `new_issues_only`. |
| `FULLSEND_GCP_REGION` | No | — | GCP region for Vertex AI inference (e.g., `us-east5`). Shared with other agents. |

### Repository secrets (Settings → Secrets and variables → Actions → Secrets)

| Secret | Required | Description |
|--------|----------|-------------|
| `FULLSEND_GCP_SA_KEY_JSON` | **Yes** | GCP Service Account key (JSON) with Vertex AI access. Shared with other agents. |
| `SCRIBE_GCP_SA_KEY_JSON` | **Yes** | GCP Service Account key (JSON) with `drive.readonly` scope. This SA must be invited to the Google Calendar meeting so it has access to the auto-generated notes. **Separate from the Vertex AI SA.** |
| `FULLSEND_SCRIBE_APP_PRIVATE_KEY` | **Yes** | Private key for the `fullsend-ai-scribe` GitHub App (issues:write). |
| `FULLSEND_CODER_APP_PRIVATE_KEY` | **Yes** | Private key for the `fullsend-ai-coder` GitHub App (contents:read). Shared with the coder agent. |
| `SCRIBE_SLACK_WEBHOOK_URL` | No | Slack incoming webhook URL. If set, a summary is posted after each run. |
| `FULLSEND_GCP_PROJECT_ID` | **Yes** | GCP project ID for Vertex AI. Shared with other agents. |

### GitHub App variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FULLSEND_SCRIBE_CLIENT_ID` | **Yes** | Client ID for the scribe GitHub App. |
| `FULLSEND_CODER_CLIENT_ID` | **Yes** | Client ID for the coder GitHub App. Shared. |

### Manual dispatch inputs

When triggering the workflow manually via **Actions → Scribe → Run workflow**, these inputs are available:

| Input | Default | Options | Description |
|-------|---------|---------|-------------|
| `dry_run` | `true` | `true`, `false` | Preview mode — no GitHub writes when `true`. **Always use `true` during development.** |
| `lookback_hours` | `3` | Any number | How far back to search for meeting notes (hours). Falls back to `SCRIBE_LOOKBACK_HOURS` repo variable, then `3`. |
| `min_confidence` | `0.6` | 0.0–1.0 | Minimum confidence threshold. Overrides the repo variable for this run. |
| `mode` | `all` | `all`, `comments_only`, `new_issues_only` | Which output types to produce. |

### Override precedence

For each parameter, the value is resolved in this order (first non-empty wins):

**Scheduled runs:**
```
repo variable  →  hardcoded default
```

**Manual dispatch:**
```
dispatch input  →  repo variable  →  hardcoded default
```

Full table:

| Parameter | Scheduled | Manual | Hardcoded default |
|-----------|-----------|--------|-------------------|
| `dry_run` | `vars.SCRIBE_DRY_RUN` | `inputs.dry_run` | `true` |
| `lookback_hours` | `vars.SCRIBE_LOOKBACK_HOURS` | `inputs.lookback_hours` → `vars.SCRIBE_LOOKBACK_HOURS` | `3` |
| `min_confidence` | `vars.SCRIBE_MIN_CONFIDENCE` | `inputs.min_confidence` → `vars.SCRIBE_MIN_CONFIDENCE` | `0.6` |
| `mode` | `vars.SCRIBE_MODE` | `inputs.mode` → `vars.SCRIBE_MODE` | `all` |

## Schedule

The workflow runs on a cron schedule defined in `.github/workflows/scribe.yml`:

```
cron: '10 16 * * 1-4'
```

This is **Mon–Thu at 16:10 UTC** (12:10 PM ET). Adjust to match your team's meeting schedule. The lookback window (default 3 hours) should cover the gap between meeting end and workflow execution.

## Security model

The scribe agent uses a 6-layer defense-in-depth security model:

### Layer 1: Input scrubbing (pre-script)

Before meeting notes enter the sandbox:
- **Structural scrubbing** — The Gemini notes "Details" section (near-verbatim transcript with per-person attributions) is stripped entirely. Only the Summary and Next Steps sections are kept.
- **Name removal** — `[Person Name]` patterns in remaining sections are replaced with `[attendee]`.
- **PII patterns** — Email addresses, phone numbers, SSNs, IP addresses, AWS keys, GitHub PATs, Slack webhooks, JWTs, private keys, and generic `key=value` secrets are all replaced with `[REDACTED]`.
- **Unicode sanitization** — Tag characters (U+E0000–E007F), zero-width characters, BOM, and bidirectional overrides are stripped (prompt injection defense).

### Layer 2: Semantic public-safety gate (LLM)

The agent evaluates each topic for public appropriateness and sets `public_safe: true/false` with a category from a fixed enum (`names`, `interpersonal`, `hr`, `strategy`, `security`, `legal`, `confidential`). Topics marked `public_safe: false` are rejected by the post-script before any GitHub write.

### Layer 3: Deterministic security gates (post-script)

Every topic and new issue passes through these host-side checks:
- **Public safety gate** — `public_safe: false` → rejected (content never logged)
- **Confidence threshold** — Below `min_confidence` → rejected
- **Sensitive content patterns** — GitHub PATs, AWS keys, email addresses, SSNs, Slack webhooks, JWTs, generic secrets → rejected
- **Suspicious Unicode** — Tag characters, zero-width, bidi overrides → rejected
- **Length limits** — Comments > 2000 chars, issue titles > 200 chars, issue bodies > 15000 chars → rejected
- **Code blocks** — Comments containing triple-backtick code fences → rejected (unexpected in meeting summaries)

### Layer 4: Sandbox isolation

The LLM runs in an OpenShell sandbox with:
- **Network**: Only `*.googleapis.com:443` (Vertex AI inference). No GitHub, no Slack, no other internet.
- **Filesystem**: Read-only except `/sandbox`, `/tmp`, `/dev/null`.
- **No write tokens**: `GH_TOKEN` and `SCRIBE_SLACK_WEBHOOK_URL` are **not** passed into the sandbox. The LLM cannot access any credential that writes to GitHub.

### Layer 5: Credential isolation

Two separate GitHub App tokens with minimal scopes:

| Token | App | Scope | Used by |
|-------|-----|-------|---------|
| `GH_TOKEN` | fullsend-ai-triage | `issues:write` | Post-script only (comments, new issues) |
| `CONTENTS_TOKEN` | fullsend-ai-coder | `contents:read`, `pull_requests:write` | Pre-script only (checkout, doc tree, PR list) |

Write tokens never enter the sandbox. The Drive SA key has `drive.readonly` only.

### Layer 6: Dry-run by default

Scheduled runs default to `dry_run=true`. The post-script **refuses to execute** if `SCRIBE_DRY_RUN` is not explicitly set. This prevents accidental writes during development or misconfiguration.

## Output schema

The agent produces a JSON file validated against `schemas/scribe-result.schema.json` before the post-script runs. The schema enforces:

```json
{
  "topics": [
    {
      "topic": "Short topic title (max 200 chars)",
      "summary": "Full markdown comment body (max 2000 chars)",
      "existing_issue": 42,
      "confidence": 0.85,
      "public_safe": true,
      "public_safe_category": null
    }
  ],
  "new_issues": [
    {
      "title": "Problem-focused title (max 200 chars)",
      "summary": "Brief description",
      "body": "Full markdown issue body (max 15000 chars)",
      "confidence": 0.85,
      "public_safe": true,
      "public_safe_category": null,
      "labels": ["meeting-notes"]
    }
  ],
  "stats": {
    "notes_processed": 1,
    "topics_extracted": 5,
    "existing_matched": 3,
    "new_proposed": 2,
    "omitted": 1
  }
}
```

The `public_safe_category` enum is enforced by the schema: `null`, `names`, `interpersonal`, `hr`, `strategy`, `security`, `legal`, `confidential`.

## New issue format

Auto-created issues include:

1. A banner noting the issue was auto-generated
2. Sections: **Problem**, **Options considered**, **Acceptance criteria** (checkboxes), **Related** (linked issues, PRs, docs)
3. Labels (defaults to `meeting-notes`; falls back to no labels if they don't exist in the target repo)

## Idempotency

- **Comments**: Before posting, the post-script checks if a comment with the same `[Meeting notes](URL)` already exists on the issue. Duplicates are skipped.
- **New issues**: No built-in dedup for new issues. The dry-run gate and confidence threshold are the primary guards against duplicate creation.
- **Topic dedup**: If the LLM produces multiple entries for the same existing issue, they are merged before gate checks (summaries concatenated, highest confidence kept, `public_safe=false` wins).

## Slack notifications

If `SCRIBE_SLACK_WEBHOOK_URL` is set, a summary is posted after each run with:
- Run mode (DRY RUN vs LIVE) and agent mode
- Topic/comment/new issue counts
- Gate rejection counts
- Links to affected issues
- Link to the Actions run

## File inventory

| File | Purpose |
|------|---------|
| `.github/workflows/scribe.yml` | Workflow: schedule, dispatch inputs, token generation, env setup |
| `agents/scribe.md` | LLM agent prompt: topic extraction, matching rules, output format |
| `env/scribe.env` | Sandbox environment variables (no tokens — safe vars only) |
| `harness/scribe.yaml` | Sandbox configuration: host file mounts, runner_env, validation loop |
| `policies/scribe.yaml` | Network/filesystem isolation policy |
| `schemas/scribe-result.schema.json` | JSON Schema for output validation |
| `scripts/pre-scribe.sh` | Pre-script: Drive fetch, PII scrub, backlog/PR/doc context |
| `scripts/post-scribe.sh` | Post-script: security gates, GitHub writes, Slack notify, step summary |
| `config.yaml` | Agent registration (role + name + slug) |

## Setup checklist

1. **Google Drive SA**: Create a GCP Service Account with `drive.readonly`. Invite it to the Google Calendar meeting so Gemini's auto-generated notes are accessible. Export the key as JSON and store as `SCRIBE_GCP_SA_KEY_JSON` secret.

2. **Vertex AI SA**: Ensure `FULLSEND_GCP_SA_KEY_JSON` (shared) has `aiplatform.endpoints.predict` permission.

3. **GitHub Apps**: Ensure the scribe app (`FULLSEND_SCRIBE_CLIENT_ID` / `FULLSEND_SCRIBE_APP_PRIVATE_KEY`) is installed on the target repo with `issues:write`, and the coder app (`FULLSEND_CODER_CLIENT_ID` / `FULLSEND_CODER_APP_PRIVATE_KEY`) with `contents:read`.

4. **Repo variable**: Set `SCRIBE_GDRIVE_SEARCH_QUERY` to match your meeting note names (e.g., `fullsend team sync`).

5. **Test with dry run**: Trigger the workflow manually with `dry_run=true`. Check the Actions job summary for the report.

6. **Go live**: Set `SCRIBE_DRY_RUN` repo variable to `false` (or leave unset and manually dispatch with `dry_run=false` to test first).

## Tuning guide

**Too many low-quality comments?**
→ Raise `SCRIBE_MIN_CONFIDENCE` to `0.7` or `0.8`.

**Missing topics from meetings that ended recently?**
→ Increase `SCRIBE_LOOKBACK_HOURS`. The default 3 hours assumes the cron runs ~3 hours after meetings.

**Only want comments on existing issues, no new issue creation?**
→ Set `SCRIBE_MODE` to `comments_only`.

**Only want new issue proposals?**
→ Set `SCRIBE_MODE` to `new_issues_only`.

**Gate rejecting too many topics as unsafe?**
→ Check the pre-script scrubbing. If meeting notes have a non-standard format (not Gemini), the structural scrub may need adjustment. The `Details` section cutoff assumes Gemini's output structure.

**Meetings on different days or times?**
→ Edit the cron in `.github/workflows/scribe.yml`. Current: `'10 16 * * 1-4'` (Mon–Thu 16:10 UTC).

## Known limitations

- **Default branch**: The doc index API call hardcodes `main`. Repos using `master` or another default branch will get an empty doc index (graceful fallback, no error).
- **Drive query**: Only supports Google Docs (`application/vnd.google-apps.document`). Other note formats (Sheets, Slides, uploaded PDFs) are not fetched.
- **WIF**: Currently uses SA key JSON only. Workload Identity Federation is not yet wired (the prioritize agent has a WIF path; scribe will follow when the org migrates).
- **New issue dedup**: No idempotency check for new issues. If two runs process the same notes with `dry_run=false`, duplicate issues may be created.
- **Page size**: Drive search is capped at 20 documents per run. Issue backlog fetch is capped at 500 open issues.
