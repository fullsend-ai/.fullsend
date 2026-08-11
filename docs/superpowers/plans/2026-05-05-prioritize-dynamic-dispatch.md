# Prioritize Dynamic Dispatch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace single-issue cron-based prioritize workflow with event-driven agent + scheduler dispatcher for parallel RICE scoring.

**Architecture:** The prioritize workflow becomes event-driven (workflow_dispatch with issue URL, like triage). A new scheduler workflow runs on cron, finds unscored/stale issues, and dispatches up to WIP_LIMIT parallel prioritize runs via `gh workflow run`.

**Tech Stack:** GitHub Actions YAML, Bash, GitHub GraphQL API, `gh` CLI

**Spec:** `docs/superpowers/specs/2026-05-05-prioritize-dynamic-dispatch-design.md`

> **Deprecation notice:** Local `harness/` and `env/` paths referenced in
> this plan have been removed. Agents are now resolved from `config.yaml`
> entries pointing at `fullsend-ai/agents`.

---

### Task 1: Rewrite pre-prioritize.sh to validate issue URL from env

The pre-script no longer selects issues. It validates `GITHUB_ISSUE_URL` (set by the workflow via harness `runner_env`), matching pre-triage's pattern.

**Files:**
- Rewrite: `scripts/pre-prioritize.sh`

- [ ] **Step 1: Rewrite the script**

Replace the entire file with:

```bash
#!/usr/bin/env bash
# pre-prioritize.sh — Validate the issue URL before the agent runs.
#
# Runs on the host via the harness pre_script mechanism.
#
# Required env vars:
#   GITHUB_ISSUE_URL — HTML URL of the issue to score
#   GH_TOKEN         — GitHub token with project read scope

set -euo pipefail

echo "::notice::🔗 Prioritize target: ${GITHUB_ISSUE_URL}"

if [[ ! "${GITHUB_ISSUE_URL}" =~ ^https://github\.com/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+/issues/[0-9]+$ ]]; then
  echo "ERROR: GITHUB_ISSUE_URL does not match expected pattern: ${GITHUB_ISSUE_URL}"
  exit 1
fi

echo "Issue URL validated."
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n scripts/pre-prioritize.sh`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add scripts/pre-prioritize.sh
git commit -m "refactor(prioritize): simplify pre-script to URL validation only

Issue selection moves to the scheduler workflow. The pre-script now
just validates GITHUB_ISSUE_URL from the workflow input, matching
the pre-triage pattern."
```

---

### Task 2: Update env/prioritize.env and harness/prioritize.yaml

Add `GITHUB_ISSUE_URL` to the sandbox env file (like triage.env) and update the harness to pass the URL via `runner_env`, remove the pre-script output file mount and stale threshold.

**Files:**
- Modify: `env/prioritize.env`
- Modify: `harness/prioritize.yaml`

- [ ] **Step 1: Update env/prioritize.env**

Replace file contents with:

```bash
export GITHUB_ISSUE_URL="${GITHUB_ISSUE_URL}"
export GH_TOKEN=${GH_TOKEN}
```

- [ ] **Step 2: Update harness/prioritize.yaml**

Replace file contents with:

```yaml
agent: agents/prioritize.md
model: opus
image: ghcr.io/fullsend-ai/fullsend-sandbox:latest
policy: policies/prioritize.yaml

host_files:
  - src: env/gcp-vertex.env
    dest: /tmp/workspace/.env.d/gcp-vertex.env
    expand: true
  - src: ${GOOGLE_APPLICATION_CREDENTIALS}
    dest: /tmp/workspace/.gcp-credentials.json
  - src: ${GCP_OIDC_TOKEN_FILE}
    dest: /tmp/workspace/.gcp-oidc-token
    optional: true
  - src: env/prioritize.env
    dest: /tmp/workspace/.env.d/prioritize.env
    expand: true

skills:
  - skills/customer-research

pre_script: scripts/pre-prioritize.sh

validation_loop:
  script: scripts/validate-output-schema.sh
  max_iterations: 2

post_script: scripts/post-prioritize.sh

runner_env:
  GITHUB_ISSUE_URL: ${GITHUB_ISSUE_URL}
  GH_TOKEN: ${GH_TOKEN}
  ORG: ${ORG}
  PROJECT_NUMBER: ${PROJECT_NUMBER}
  FULLSEND_OUTPUT_SCHEMA: ${FULLSEND_DIR}/schemas/prioritize-result.schema.json

timeout_minutes: 10
```

Changes from current:
- Removed `/tmp/pre-prioritize-output.env` host_file mount (no longer needed)
- Added `GITHUB_ISSUE_URL: ${GITHUB_ISSUE_URL}` to `runner_env`
- Removed `STALE_THRESHOLD` from `runner_env` (scheduler handles this now)

- [ ] **Step 3: Commit**

```bash
git add env/prioritize.env harness/prioritize.yaml
git commit -m "refactor(prioritize): pass issue URL via workflow input

Add GITHUB_ISSUE_URL to prioritize.env and harness runner_env.
Remove pre-script output file mount and stale threshold (both
move to the scheduler workflow)."
```

---

### Task 3: Update post-prioritize.sh to remove file-based env workaround

The post-script currently sources `/tmp/pre-prioritize-output.env` because the pre-script wrote the URL there. Now `GITHUB_ISSUE_URL` comes from `runner_env`, so remove the workaround.

**Files:**
- Modify: `scripts/post-prioritize.sh:16-20`

- [ ] **Step 1: Remove the file-sourcing block**

Remove lines 16-20:

```bash
# Source issue URL from pre-script output (fullsend doesn't propagate
# pre-script env exports to the post-script process).
if [[ -f /tmp/pre-prioritize-output.env ]]; then
  # shellcheck disable=SC1091
  source /tmp/pre-prioritize-output.env
fi
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n scripts/post-prioritize.sh`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add scripts/post-prioritize.sh
git commit -m "refactor(prioritize): remove file-based env workaround from post-script

GITHUB_ISSUE_URL now flows via runner_env from the workflow input,
so the /tmp/pre-prioritize-output.env sourcing is unnecessary."
```

---

### Task 4: Rewrite prioritize.yml to event-driven workflow_dispatch

Switch from cron trigger to workflow_dispatch with inputs matching triage's interface. Add per-issue concurrency. Pass issue URL to the fullsend action.

**Files:**
- Rewrite: `.github/workflows/prioritize.yml`

- [ ] **Step 1: Rewrite the workflow**

Replace the entire file with:

```yaml
# fullsend-stage: prioritize
name: Prioritize

on:
  workflow_dispatch:
    inputs:
      event_type:
        required: true
        type: string
      source_repo:
        required: true
        type: string
      event_payload:
        required: true
        type: string

concurrency:
  group: fullsend-prioritize-${{ fromJSON(inputs.event_payload).issue.number }}
  cancel-in-progress: true

jobs:
  prioritize:
    name: Prioritize
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      actions: write
      contents: read
      id-token: write
      issues: write

    steps:
      - name: Checkout .fullsend repository
        uses: actions/checkout@v6

      - name: Generate app token
        id: app-token
        uses: actions/create-github-app-token@v3
        with:
          # TODO: create a dedicated prioritize app for the final implementation
          client-id: ${{ vars.FULLSEND_TRIAGE_CLIENT_ID }}
          private-key: ${{ secrets.FULLSEND_TRIAGE_APP_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: Authenticate to Google Cloud (WIF)
        if: vars.FULLSEND_GCP_AUTH_MODE == 'wif'
        uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: ${{ secrets.FULLSEND_GCP_WIF_PROVIDER }}
          service_account: ${{ secrets.FULLSEND_GCP_WIF_SA_EMAIL }}

      - name: Authenticate to Google Cloud (SA key)
        if: vars.FULLSEND_GCP_AUTH_MODE != 'wif'
        uses: google-github-actions/auth@v3
        with:
          credentials_json: ${{ secrets.FULLSEND_GCP_SA_KEY_JSON }}

      - name: Set GCP_OIDC_TOKEN_FILE for non-WIF
        if: vars.FULLSEND_GCP_AUTH_MODE != 'wif'
        run: |
          touch "$RUNNER_TEMP/empty-oidc-token"
          echo "GCP_OIDC_TOKEN_FILE=$RUNNER_TEMP/empty-oidc-token" >> "${GITHUB_ENV}"

      - name: Mask GCP credential file paths
        run: |
          for var in GOOGLE_GHA_CREDS_PATH GOOGLE_APPLICATION_CREDENTIALS CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE; do
            val="${!var:-}"
            if [[ -n "${val}" ]]; then
              echo "::add-mask::${val}"
            fi
          done

      - name: Prepare sandbox credentials
        run: bash scripts/prepare-sandbox-credentials.sh

      - name: Setup agent environment
        env:
          AGENT_PREFIX: PRIORITIZE_
          PRIORITIZE_GH_TOKEN: ${{ steps.app-token.outputs.token }}
          PRIORITIZE_ORG: ${{ github.repository_owner }}
          PRIORITIZE_PROJECT_NUMBER: ${{ vars.FULLSEND_PROJECT_NUMBER }}
          PRIORITIZE_ANTHROPIC_VERTEX_PROJECT_ID: ${{ secrets.FULLSEND_GCP_PROJECT_ID }}
          PRIORITIZE_CLOUD_ML_REGION: ${{ vars.FULLSEND_GCP_REGION }}
        run: bash .github/scripts/setup-agent-env.sh

      - name: Create empty target-repo directory
        run: mkdir -p target-repo

      - name: Run prioritize agent
        uses: ./.github/actions/fullsend
        env:
          GITHUB_ISSUE_URL: ${{ fromJSON(inputs.event_payload).issue.html_url }}
        with:
          agent: prioritize
```

Changes from current:
- `on:` block: `schedule` + bare `workflow_dispatch` → `workflow_dispatch` with `event_type`/`source_repo`/`event_payload` inputs
- `concurrency.group`: `fullsend-prioritize` → `fullsend-prioritize-${{ fromJSON(inputs.event_payload).issue.number }}`
- Removed `PRIORITIZE_STALE_THRESHOLD` from setup env step
- Removed `touch /tmp/pre-prioritize-output.env` from target-repo step
- Added `env.GITHUB_ISSUE_URL` on the fullsend action step (like triage)

- [ ] **Step 2: Validate YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/prioritize.yml'))"`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/prioritize.yml
git commit -m "refactor(prioritize): switch to event-driven workflow_dispatch

Replace cron schedule with workflow_dispatch inputs matching triage's
interface (event_type, source_repo, event_payload). Per-issue
concurrency group enables parallel runs for different issues."
```

---

### Task 5: Create prioritize-scheduler.yml

New cron-triggered workflow that finds unscored/stale issues and dispatches parallel prioritize runs.

**Files:**
- Create: `.github/workflows/prioritize-scheduler.yml`

- [ ] **Step 1: Create the scheduler workflow**

```yaml
name: Prioritize Scheduler

on:
  schedule:
    - cron: '*/10 * * * *'
  workflow_dispatch:

concurrency:
  group: fullsend-prioritize-scheduler
  cancel-in-progress: true

jobs:
  dispatch:
    name: Find and dispatch issues for RICE scoring
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      actions: write
      contents: read

    steps:
      - name: Checkout .fullsend repository
        uses: actions/checkout@v6

      - name: Generate app token
        id: app-token
        uses: actions/create-github-app-token@v3
        with:
          client-id: ${{ vars.FULLSEND_TRIAGE_CLIENT_ID }}
          private-key: ${{ secrets.FULLSEND_TRIAGE_APP_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: Find issues and dispatch prioritize runs
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
          ORG: ${{ github.repository_owner }}
          PROJECT_NUMBER: ${{ vars.FULLSEND_PROJECT_NUMBER }}
          WIP_LIMIT: ${{ vars.PRIORITIZE_WIP_LIMIT || '5' }}
          STALE_THRESHOLD: ${{ vars.PRIORITIZE_STALE_THRESHOLD || '7d' }}
        run: |
          set -euo pipefail

          # --- Parse stale threshold into seconds ---
          parse_threshold() {
            local val="${1%[dh]}"
            local unit="${1: -1}"
            case "${unit}" in
              d) echo $(( val * 86400 )) ;;
              h) echo $(( val * 3600 )) ;;
              *) echo "ERROR: unsupported threshold unit '${unit}' (use Nd or Nh)" >&2; exit 1 ;;
            esac
          }
          THRESHOLD_SECONDS=$(parse_threshold "${STALE_THRESHOLD}")

          # --- Fetch project metadata ---
          PROJECT_ID=$(gh project view "${PROJECT_NUMBER}" --owner "${ORG}" --format json | jq -r '.id')

          SCORE_FIELD_ID=$(gh project field-list "${PROJECT_NUMBER}" --owner "${ORG}" --format json \
            | jq -r '.fields[] | select(.name == "RICE Score") | .id')

          if [[ -z "${SCORE_FIELD_ID}" ]]; then
            echo "ERROR: 'RICE Score' field not found on project ${PROJECT_NUMBER}."
            echo "Run scripts/setup-prioritize.sh first."
            exit 1
          fi

          # --- Paginate through all project items ---
          ITEMS_JSON='{"data":{"node":{"items":{"nodes":[]}}}}'
          HAS_NEXT_PAGE=true
          CURSOR=""

          while [[ "${HAS_NEXT_PAGE}" == "true" ]]; do
            if [[ -z "${CURSOR}" ]]; then
              AFTER_ARG=""
            else
              AFTER_ARG=", after: \$cursor"
            fi

            PAGE_JSON=$(gh api graphql -f query="
              query(\$projectId: ID!$([ -n "${CURSOR}" ] && echo ', $cursor: String!')) {
                node(id: \$projectId) {
                  ... on ProjectV2 {
                    items(first: 100${AFTER_ARG}) {
                      pageInfo {
                        hasNextPage
                        endCursor
                      }
                      nodes {
                        id
                        fieldValues(first: 20) {
                          nodes {
                            ... on ProjectV2ItemFieldNumberValue {
                              field { ... on ProjectV2Field { id name } }
                              number
                              updatedAt
                            }
                          }
                        }
                        content {
                          ... on Issue {
                            url
                            number
                            state
                          }
                        }
                      }
                    }
                  }
                }
              }
            " -f projectId="${PROJECT_ID}" ${CURSOR:+-f cursor="${CURSOR}"})

            ITEMS_JSON=$(jq -s '
              .[0].data.node.items.nodes += .[1].data.node.items.nodes
              | .[0]
            ' <(echo "${ITEMS_JSON}") <(echo "${PAGE_JSON}"))

            HAS_NEXT_PAGE=$(echo "${PAGE_JSON}" | jq -r '.data.node.items.pageInfo.hasNextPage')
            CURSOR=$(echo "${PAGE_JSON}" | jq -r '.data.node.items.pageInfo.endCursor')
          done

          TOTAL=$(echo "${ITEMS_JSON}" | jq '.data.node.items.nodes | length')
          echo "Fetched ${TOTAL} project items."

          # --- Find unscored open issues (up to WIP_LIMIT) ---
          UNSCORED_ISSUES=$(echo "${ITEMS_JSON}" | jq -r --arg fid "${SCORE_FIELD_ID}" --argjson limit "${WIP_LIMIT}" '
            [.data.node.items.nodes[]
             | select(.content.state == "OPEN")
             | select(.content.url != null)
             | select(
                 [.fieldValues.nodes[]
                  | select(.field.id == $fid)
                 ] | length == 0
               )
             | {url: .content.url, number: .content.number}
            ] | .[:$limit]
          ')

          UNSCORED_COUNT=$(echo "${UNSCORED_ISSUES}" | jq 'length')

          if [[ "${UNSCORED_COUNT}" -gt 0 ]]; then
            echo "Found ${UNSCORED_COUNT} unscored issue(s) to dispatch."
          else
            echo "All issues scored. Checking for stale scores..."

            NOW_EPOCH=$(date +%s)

            UNSCORED_ISSUES=$(echo "${ITEMS_JSON}" | jq -r --arg fid "${SCORE_FIELD_ID}" --argjson limit "${WIP_LIMIT}" --argjson threshold "${THRESHOLD_SECONDS}" --argjson now "${NOW_EPOCH}" '
              [.data.node.items.nodes[]
               | select(.content.state == "OPEN")
               | select(.content.url != null)
               | {
                   url: .content.url,
                   number: .content.number,
                   updatedAt: ([.fieldValues.nodes[] | select(.field.id == $fid) | .updatedAt] | first)
                 }
               | select(.updatedAt != null)
               | select(($now - (.updatedAt | fromdateiso8601)) > $threshold)
              ]
              | sort_by(.updatedAt)
              | .[:$limit]
            ')

            STALE_COUNT=$(echo "${UNSCORED_ISSUES}" | jq 'length')

            if [[ "${STALE_COUNT}" -eq 0 ]]; then
              echo "No stale scores found. Nothing to do."
              exit 0
            fi

            echo "Found ${STALE_COUNT} stale issue(s) to re-score."
          fi

          # --- Dispatch prioritize runs ---
          DISPATCHED=0
          FAILED=0

          for row in $(echo "${UNSCORED_ISSUES}" | jq -c '.[]'); do
            ISSUE_URL=$(echo "${row}" | jq -r '.url')
            ISSUE_NUMBER=$(echo "${row}" | jq -r '.number')
            SOURCE_REPO=$(echo "${ISSUE_URL}" | sed 's|https://github.com/||; s|/issues/.*||')

            EVENT_PAYLOAD=$(jq -n \
              --arg url "${ISSUE_URL}" \
              --argjson number "${ISSUE_NUMBER}" \
              '{issue: {html_url: $url, number: $number}}')

            echo "Dispatching prioritize for ${SOURCE_REPO}#${ISSUE_NUMBER}..."

            if gh workflow run prioritize.yml \
              --repo "${GITHUB_REPOSITORY}" \
              -f event_type="schedule" \
              -f source_repo="${SOURCE_REPO}" \
              -f event_payload="${EVENT_PAYLOAD}"; then
              DISPATCHED=$((DISPATCHED + 1))
            else
              echo "::warning::Failed to dispatch for ${ISSUE_URL}"
              FAILED=$((FAILED + 1))
            fi
          done

          echo "Dispatched ${DISPATCHED} prioritize run(s), ${FAILED} failed."
```

- [ ] **Step 2: Validate YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/prioritize-scheduler.yml'))"`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/prioritize-scheduler.yml
git commit -m "feat(prioritize): add scheduler workflow for parallel dispatch

Cron-triggered workflow that finds unscored/stale issues on the
project board and dispatches up to WIP_LIMIT (default 5) parallel
prioritize runs via gh workflow run."
```

---

### Task 6: Update scaffold files in fullsend-ai/fullsend PR #603

Apply the same changes to the scaffold copies. This task is done on the `agent-329-rice-scoring-prioritize-agent` branch of the `fullsend-ai/fullsend` repo.

**Files:**
- Rewrite: `internal/scaffold/fullsend-repo/scripts/pre-prioritize.sh` (same as Task 1)
- Modify: `internal/scaffold/fullsend-repo/env/prioritize.env` (same as Task 2)
- Modify: `internal/scaffold/fullsend-repo/harness/prioritize.yaml` (same as Task 2)
- Rewrite: `internal/scaffold/fullsend-repo/.github/workflows/prioritize.yml` (same as Task 4)
- Create: `internal/scaffold/fullsend-repo/.github/workflows/prioritize-scheduler.yml` (same as Task 5)

- [ ] **Step 1: Clone and checkout the PR branch**

```bash
cd /tmp
gh repo clone fullsend-ai/fullsend fullsend-scaffold-update
cd fullsend-scaffold-update
git checkout agent-329-rice-scoring-prioritize-agent
```

- [ ] **Step 2: Copy each changed file from .fullsend to the scaffold path**

The scaffold files are identical to the `.fullsend` versions. Copy each file:

```bash
SCAFFOLD="internal/scaffold/fullsend-repo"
FULLSEND="/home/rbean/code/fullsend-ai-fullsend"

cp "${FULLSEND}/scripts/pre-prioritize.sh" "${SCAFFOLD}/scripts/pre-prioritize.sh"
cp "${FULLSEND}/env/prioritize.env" "${SCAFFOLD}/env/prioritize.env"
cp "${FULLSEND}/harness/prioritize.yaml" "${SCAFFOLD}/harness/prioritize.yaml"
cp "${FULLSEND}/.github/workflows/prioritize.yml" "${SCAFFOLD}/.github/workflows/prioritize.yml"
cp "${FULLSEND}/.github/workflows/prioritize-scheduler.yml" "${SCAFFOLD}/.github/workflows/prioritize-scheduler.yml"
```

- [ ] **Step 3: Update post-prioritize.sh scaffold copy**

Remove the `/tmp/pre-prioritize-output.env` sourcing block (lines 16-20) from:
`internal/scaffold/fullsend-repo/scripts/post-prioritize.sh`

(Same change as Task 3)

- [ ] **Step 4: Check if scaffold_test.go needs updating**

Read `internal/scaffold/scaffold_test.go` and check if it validates the list of generated files. If so, add `prioritize-scheduler.yml` to the expected files list.

- [ ] **Step 5: Run tests**

```bash
go test ./internal/scaffold/ -v -run TestScaffold
```

- [ ] **Step 6: Commit and push**

```bash
git add "${SCAFFOLD}/" internal/scaffold/scaffold_test.go
git commit -m "refactor(scaffold): update prioritize to dynamic dispatch pattern

Mirror changes from .fullsend: event-driven prioritize workflow,
new scheduler workflow, simplified pre-script."
git push
```
