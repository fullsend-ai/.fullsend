# GitHub Issue Classify Agent (gh-classify)

The gh-classify agent automatically categorizes GitHub issues on your project board. When someone opens a new issue in an enrolled repo, the agent reads the issue, compares it against your organization's categories document, and sets the appropriate category on your GitHub Project board — no human intervention required.

You can also run it manually to classify a backlog of existing issues in batch.

> **GitHub-only.** This agent classifies GitHub Issues using the GitHub API. It does not support Jira, Linear, or other issue trackers.

> **Custom agent.** This agent is added directly to the `.fullsend` repo as a PR, not managed by the fullsend scaffold/installer. It serves as a reference for how organizations add custom agents alongside the built-in ones (triage, code, review, fix).

---

## What happens automatically

Once installed, the classify agent runs **every time a new issue is opened** in any enrolled repo. Here is the exact sequence:

1. Someone creates a new issue in `your-org/your-repo`.
2. The **shim workflow** (installed in `your-repo`) fires on the `issues.opened` event.
3. The shim's `dispatch-gh-classify` job builds a minimal JSON payload (issue number, URL, author) and dispatches `gh-classify.yml` in `your-org/.fullsend` with `classify_mode=single`.
4. The **gh-classify workflow** starts in `.fullsend`:
   - Validates the source repo is enrolled in `config.yaml`.
   - Generates a GitHub App token (triage app by default).
   - Authenticates to Google Cloud for Vertex AI.
   - Runs the **pre-script** on the host (fetches issue list, discovers project field metadata).
   - Launches the **agent** in a sandboxed container:
     - Loads the categories document.
     - Fetches the single issue (title, body, comments).
     - Classifies it against category descriptions.
     - Writes `agent-result.json` with the category, reasoning, and confidence score.
   - Validates the output against the JSON Schema.
   - Runs the **post-script** on the host:
     - Reads the agent's decision.
     - If confidence >= threshold (default 70%): adds the issue to the GitHub Project (if not already there) and sets the category field.
     - Writes a summary to the GitHub Actions step summary.
5. The issue now has a `Workstream Category` (or your field name) set on the project board.

**Time:** 30–60 seconds from issue creation to classification.

**What the agent never does:**
- Modify issue content, labels, or state
- Invent category names not in the categories document
- Read or access repos other than the specified source repo
- Print tokens, credentials, or issue body text in logs

---

## Prerequisites

Before using gh-classify, you need three things:

### 1. A GitHub Project (V2) with a category field

Your org must have a [GitHub Project (V2)](https://docs.github.com/en/issues/planning-and-tracking-with-projects) with a **single-select custom field** for categories. The field option names must exactly match the category names in your categories document.

Example: If your categories document defines "Bug fixes", "New features", and "Documentation", your project field must have options named exactly `Bug fixes`, `New features`, and `Documentation`.

### 2. A categories document

A Markdown file that tells the agent what your categories are and how to distinguish between them. This is the single most important input — a well-written categories doc produces accurate classifications; a vague one produces garbage.

Create the file in your `.fullsend` repo (e.g., `docs/categories.md`) or in the target repo. Each category is a Markdown heading with descriptive content:

```markdown
# Workstream Categories

## Bug fixes
Issues reporting broken functionality in existing features.

**What belongs here:**
- Crashes, regressions, error messages
- Broken workflows that used to work
- Incorrect output from existing features

**What does NOT belong:**
- Feature requests or enhancement proposals
- Documentation typos (see Documentation)

**Signal keywords:** crash, regression, error, broken, fix, doesn't work

## New features
Proposals for entirely new capabilities not yet in the product.

**What belongs here:**
- RFCs, proposals, new agent types
- Support for new platforms or integrations

**What does NOT belong:**
- Improvements to existing features (see Enhancements)

**Signal keywords:** proposal, RFC, new, add support for, implement
```

The more detail you provide — especially "what does NOT belong" exclusions and tiebreaker rules — the better the agent performs.

### 3. Configuration on your `.fullsend` repo

At minimum, set one variable:

```bash
gh variable set FULLSEND_GH_CLASSIFY_CATEGORIES_PATH \
  --repo YOUR-ORG/.fullsend \
  --body "docs/categories.md"
```

Everything else has working defaults. See [Configuration reference](#configuration-reference) for the full list.

---

## How to use it

### Automatic: new issues (no action needed)

After installation, every new issue in enrolled repos is classified automatically. You will see:

- A GitHub Actions workflow run in your `.fullsend` repo named "Classify Issues".
- The issue's category field set on the project board within ~60 seconds.
- A step summary in the workflow run showing what was classified and at what confidence.

If the agent is not confident enough (below the threshold), the issue is left unclassified. You can re-run manually with a lower threshold or classify it by hand.

### Manual: classify a single issue

From the GitHub Actions UI:

1. Go to **Actions** > **Classify GitHub Issues** > **Run workflow**.
2. Set `classify_mode` to `single`.
3. Enter the issue number in `issue_number`.
4. Click **Run workflow**.

From the CLI:

```bash
gh workflow run gh-classify.yml --repo YOUR-ORG/.fullsend \
  -f source_repo="your-org/your-repo" \
  -f classify_mode="single" \
  -f issue_number="42"
```

### Manual: classify all unclassified issues (batch)

This finds every open issue that doesn't already have a category on the project board and classifies them.

```bash
# Dry run first (recommended) — see what would happen without writing anything
gh workflow run gh-classify.yml --repo YOUR-ORG/.fullsend \
  -f source_repo="your-org/your-repo" \
  -f classify_mode="unclassified" \
  -f dry_run="true"

# Live run — actually set the categories
gh workflow run gh-classify.yml --repo YOUR-ORG/.fullsend \
  -f source_repo="your-org/your-repo" \
  -f classify_mode="unclassified" \
  -f dry_run="false"
```

**Expected time:** 5–15 minutes depending on issue count (~170 issues takes ~8 minutes with screening on).

### Manual: classify into one specific category

Useful for workstream leads who want to find issues belonging to their category.

```bash
gh workflow run gh-classify.yml --repo YOUR-ORG/.fullsend \
  -f source_repo="your-org/your-repo" \
  -f classify_mode="unclassified" \
  -f filter_category="New agent capability" \
  -f dry_run="true"
```

The agent may only assign the specified category. Issues that don't match get `null`. The value must exactly match a category name from your categories document.

### Manual: re-classify everything

Re-evaluates all open issues, **overwriting existing classifications**. Use after changing your categories document or project field options.

```bash
gh workflow run gh-classify.yml --repo YOUR-ORG/.fullsend \
  -f source_repo="your-org/your-repo" \
  -f classify_mode="all" \
  -f dry_run="false"
```

**Use with caution** — this overwrites any manual corrections you've made on the project board.

### Local execution

Run from your machine using the `fullsend` CLI:

```bash
# Set up environment (token, repo, etc.)
export GH_TOKEN="ghp_your_token"
export CLASSIFY_SOURCE_REPO="your-org/your-repo"
export CLASSIFY_MODE=single
export CLASSIFY_ISSUE_NUMBER=42

fullsend run gh-classify --fullsend-dir /path/to/.fullsend --target-repo .
```

---

## Dry run

All modes support `dry_run=true`. In dry-run mode:

- The agent runs identically (same API reads, same LLM evaluation).
- **No project fields are written.** Nothing changes on GitHub.
- The post-script produces a full report showing what *would* have been done.
- The report and agent transcript are saved as GitHub Actions artifacts.

**Always dry-run first** when running batch classification or after changing your categories document.

---

## Tuning classification quality

### Confidence threshold (`min_confidence`)

The agent assigns a confidence score (0.0–1.0) to each classification. Issues scoring below the threshold are skipped.

| Value | Effect |
|-------|--------|
| `0.7` | Default. Good balance — most clear-cut issues get classified, ambiguous ones are left for humans. |
| `0.5` | More permissive. Classifies more issues but with more borderline calls. |
| `0.9` | Very strict. Only classifies when the agent is highly certain. |

### Issue screening (`screen_issues`)

In batch modes, the agent can pre-filter issues by title and labels before fetching full details (body + comments). This is faster but may miss edge cases where the title is misleading.

| Value | Behavior | Speed |
|-------|----------|-------|
| `true` (default) | Screen by title/labels first, fetch details only for plausible candidates. | ~5–8 min for ~170 issues |
| `false` | Fetch full details for every candidate. More thorough. | ~9–12 min for ~170 issues |

### Categories document quality

The biggest lever. Tips:

- **Be specific about boundaries.** "What does NOT belong" sections prevent the most common misclassifications.
- **Include tiebreaker rules.** When an issue could fit multiple categories, the agent needs explicit guidance on which one wins.
- **Use real issue examples** (by description, not by quoting) to illustrate edge cases.
- **Review and iterate.** Run a dry-run batch, review the results, and improve the categories doc based on mistakes.

---

## Workflow input fields reference

When you click **Actions > Classify GitHub Issues > Run workflow**, you see these fields:

| # | Field | Description | Default |
|---|-------|-------------|---------|
| 1 | `event_type` | How the workflow was triggered. **Always leave as `manual` for manual runs.** The shim sets this to `issues` automatically. | `manual` |
| 2 | `source_repo` | The `owner/repo` whose issues to classify. Leave empty to use the first enabled repo from `config.yaml`. | *(empty)* |
| 3 | `event_payload` | JSON from the shim dispatch. **Always leave empty for manual runs.** | *(empty)* |
| 4 | `classify_mode` | `unclassified` (batch, skip already-classified), `single` (one issue), or `all` (everything, overwrites). | `unclassified` |
| 5 | `issue_number` | Issue number for `single` mode. Leave empty for batch modes. | *(empty)* |
| 6 | `dry_run` | `true` = no writes, just report. `false` = actually set project fields. | `false` |
| 7 | `min_confidence` | Minimum confidence to apply a classification (0.0–1.0). | `0.7` |
| 8 | `filter_category` | Restrict to one category. Must match categories doc exactly. Leave empty for all. | *(empty)* |
| 9 | `screen_issues` | `true` = pre-filter by title/labels (faster). `false` = fetch all details (thorough). | `true` |

---

## Configuration reference

### Variables (set on `.fullsend` repo)

| Variable | Required | Default / Fallback | Description |
|----------|----------|-------------------|-------------|
| `FULLSEND_GH_CLASSIFY_CATEGORIES_PATH` | **Yes** | `categories.md` | Path to your categories document, relative to the `.fullsend` repo root. If the file doesn't exist locally, the agent attempts to fetch it from the target repo via the GitHub API. |
| `FULLSEND_GH_CLASSIFY_FIELD_NAME` | No | `Workstream Category` | Name of the single-select field on your GitHub Project board. |
| `FULLSEND_GH_CLASSIFY_PROJECT_NUMBER` | No | `FULLSEND_PROJECT_NUMBER`, then `1` | GitHub Project V2 number. Falls back to the shared project number used by other agents (e.g., prioritize). |
| `FULLSEND_GH_CLASSIFY_CLIENT_ID` | No | `FULLSEND_TRIAGE_CLIENT_ID` | Client ID for a dedicated classify GitHub App. If not set, the triage app is used — this works because the triage app already has `organization_projects: write` permission. |

### Secrets (set on `.fullsend` repo)

| Secret | Required | Default / Fallback | Description |
|--------|----------|-------------------|-------------|
| `FULLSEND_GH_CLASSIFY_APP_PRIVATE_KEY` | No | `FULLSEND_TRIAGE_APP_PRIVATE_KEY` | Private key for a dedicated classify app. Falls back to the triage app's key. |
| `FULLSEND_GH_CLASSIFY_PROJECT_PAT` | Cross-org only | Disabled | A PAT with `Organization projects: Read/Write` access. Only needed if the `.fullsend` repo is in a different GitHub org than the target repo's project board. |

### Shared infrastructure (already configured)

These are set up by the fullsend installer and shared by all agents. You should not need to change them for classify.

| Variable/Secret | Purpose |
|-----------------|---------|
| `FULLSEND_GCP_AUTH_MODE` | `wif` or SA key — how to authenticate to Google Cloud |
| `FULLSEND_GCP_REGION` | Vertex AI region |
| `FULLSEND_GCP_PROJECT_ID` | GCP project for Vertex AI inference |
| `FULLSEND_GCP_WIF_PROVIDER` / `FULLSEND_GCP_WIF_SA_EMAIL` | Workload Identity Federation credentials (if using WIF) |
| `FULLSEND_GCP_SA_KEY_JSON` | Service account key (if not using WIF) |
| `FULLSEND_TRIAGE_CLIENT_ID` / `FULLSEND_TRIAGE_APP_PRIVATE_KEY` | Triage GitHub App credentials (used as fallback for classify) |
| `FULLSEND_PROJECT_NUMBER` | Shared project board number (used as fallback) |

### Shim secret (set on enrolled repos, not `.fullsend`)

| Secret | Purpose |
|--------|---------|
| `FULLSEND_DISPATCH_TOKEN` | Token the shim workflow uses to trigger workflows in `.fullsend`. Already configured for triage/code/review dispatch — no additional setup needed for classify. |

---

## Architecture

```
Enrolled repo (your-org/your-repo)
  │
  ├─ issues.opened event fires
  │
  └─ shim-workflow.yaml
      └─ dispatch-gh-classify job
          ├─ Builds minimal JSON payload {issue.number, issue.html_url, author, repository}
          └─ gh workflow run gh-classify.yml --repo your-org/.fullsend
              with classify_mode=single, issue_number=N

.fullsend repo (your-org/.fullsend)
  │
  └─ gh-classify.yml workflow
      │
      ├─ 1. Determine parameters (parse inputs, resolve source repo)
      ├─ 2. Validate enrollment (check config.yaml for shim triggers)
      ├─ 3. Generate app token (triage app or dedicated classify app)
      ├─ 4. GCP auth (Vertex AI for LLM inference)
      │
      ├─ 5. pre-gh-classify.sh (runs on host)
      │     ├─ Fetch open issues list from source repo
      │     ├─ Determine candidate set (single / unclassified / all)
      │     └─ Query project board for field metadata (option IDs)
      │
      ├─ 6. fullsend action (runs agent in sandboxed container)
      │     ├─ Load categories document
      │     ├─ Build candidate list (exclude already-classified)
      │     ├─ Screen candidates by title/labels (batch modes, if enabled)
      │     ├─ Fetch candidate bodies + comments via gh API
      │     ├─ Classify each issue against category descriptions
      │     ├─ Write agent-result.json
      │     └─ Validate output against gh-classify-result.schema.json
      │
      └─ 7. post-gh-classify.sh (runs on host)
            ├─ Read agent-result.json
            ├─ Filter by confidence threshold
            ├─ Add issues to project board (idempotent)
            ├─ Set category field value via GraphQL
            ├─ Write classify-report.json artifact
            └─ Write GitHub Actions step summary
```

The classify agent dispatches **directly** to `gh-classify.yml` — it does not go through `dispatch.yml` like the built-in triage/code/review/fix agents. This is the expected pattern for custom agents.

---

## Agent output format

The agent writes `agent-result.json` with this structure:

```json
{
  "classifications": [
    {
      "issue_number": 42,
      "workstream_category": "Bug fixes",
      "reasoning": "Issue reports a crash in the login flow when using SSO.",
      "confidence": 0.92
    },
    {
      "issue_number": 99,
      "workstream_category": null,
      "reasoning": "Issue is ambiguous — could be a feature request or a bug report depending on interpretation.",
      "confidence": 0.4
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `issue_number` | integer | The issue number in the source repo |
| `workstream_category` | string or null | Exact category name from the categories doc, or `null` if the agent cannot confidently classify |
| `reasoning` | string (1–2000 chars) | Brief explanation of the classification decision. Never quotes issue text verbatim. |
| `confidence` | float 0.0–1.0 | How confident the agent is in this classification |

---

## Viewing results

### GitHub Actions step summary

Every workflow run produces a markdown summary table in the GitHub Actions UI showing:
- How many issues were classified, skipped, or errored
- Per-issue breakdown with category, confidence, and action taken
- Whether it was a dry run

### classify-report.json artifact

A structured JSON artifact is saved with every run. Download it from the workflow run's **Artifacts** section. Contains the full per-issue report with status, category, confidence, and reasoning.

### Project board

After a live run, check your GitHub Project board — classified issues will have their category field set.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Workflow fails at "Generate app token" | Missing app credentials | Verify `FULLSEND_TRIAGE_CLIENT_ID` exists as a variable on `.fullsend` repo |
| Agent classifies nothing | Categories doc not found | Check `FULLSEND_GH_CLASSIFY_CATEGORIES_PATH` points to a real file |
| All issues get `null` | Categories too vague or threshold too high | Improve categories doc detail; try `min_confidence=0.5` |
| Project field not set | Field name mismatch | Ensure `FULLSEND_GH_CLASSIFY_FIELD_NAME` exactly matches the project field name, including spaces and capitalization |
| "repo is not enabled" error | Source repo not enrolled | Add the repo to `config.yaml` under `repos:` with `enabled: true` |
| Cross-org project writes fail | App token lacks cross-org project access | Set `FULLSEND_GH_CLASSIFY_PROJECT_PAT` secret with a PAT that has org project write access |
| Screening misses issues | Title doesn't reflect content | Run with `screen_issues=false` for thorough evaluation |

---

## Open items

- [ ] The `issues.edited` event is not currently a trigger. If an issue's title or body changes significantly after creation, it won't be re-classified automatically.
- [ ] Consider increasing the harness timeout for `all` mode to handle repos with 500+ issues.
- [ ] Create a dedicated `gh-classify` GitHub App when this agent is promoted to first-class (currently reuses the triage app).
