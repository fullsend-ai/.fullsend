# Prioritize Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a scheduled, org-scoped RICE scoring agent that picks unscored (or stale) issues from the GitHub Project board, produces RICE scores via LLM, and writes the scores back as project fields.

**Architecture:** Platform-agnostic agent core (agent definition, schema, skill) with platform-specific pre/post/setup scripts. The agent runs directly from `org/.fullsend` on a cron schedule — no per-repo shim involved. The pre-script selects work from the project board, the agent scores the issue, and the post-script writes scores back to the board and posts a reasoning comment.

**Tech Stack:** Bash scripts, `gh` CLI (GraphQL API for Projects V2), `jq`, JSON Schema validation

**Spec:** `docs/superpowers/specs/2026-05-01-prioritize-agent-design.md`

## Post-Implementation Changes

The following changes were discovered during functional testing against
the `appdumpster` org and were not in the original plan:

### Bug fixes found during testing

1. **Setup script: GraphQL union type fix.** The `createProjectV2Field`
   mutation returns a `ProjectV2FieldConfiguration` union type.
   Selecting `id` and `name` directly fails — changed to use an inline
   fragment: `... on ProjectV2Field { id name }`.

2. **Post-script: Float coercion fix.** The `gh` CLI's `-F` flag does
   not reliably coerce string values like `"1.0"` to GraphQL `Float`.
   Switched to `gh api graphql --input -` with `jq`-built JSON
   variables to ensure proper numeric typing.

### Features added during testing

3. **Board reranking by RICE Score.** After writing scores, the
   post-script now fetches all project items with their RICE Score
   values, sorts them descending (nulls at bottom), and repositions
   them using `updateProjectV2ItemPosition`. Higher scores float to the
   top of the board. This was not in the original spec or plan but is
   essential for the board to be useful as a prioritized view.

4. **Collapsed comment with `<details>`/`<summary>`.** The RICE
   reasoning comment now uses an HTML details dropdown. Only the score
   headline (**RICE Priority Score: X.XX**) is visible by default.
   Click "Score breakdown" to expand the per-dimension table. Reduces
   comment noise on issues.

5. **Scheduled GitHub Actions workflow.** Added
   `.github/workflows/prioritize.yml` with a `schedule` cron trigger
   running every 10 minutes. This is the first scheduled workflow in
   the project — all other agents are event-driven
   (`workflow_dispatch`). The workflow uses `FULLSEND_PROJECT_NUMBER`
   (Actions variable) and `FULLSEND_PRIORITIZE_CLIENT_ID` /
   `FULLSEND_PRIORITIZE_APP_PRIVATE_KEY` (secret) for auth. The
   `ORG` is derived from `github.repository_owner`. Concurrency is
   set to `cancel-in-progress: false` so overlapping runs queue
   rather than cancel (the pre-script's exit 78 handles the
   nothing-to-do case gracefully).

### Notes for final implementation in fullsend-ai/fullsend

6. **Dedicated GitHub App for prioritize.** The prototype reuses the
   triage app (`FULLSEND_TRIAGE_CLIENT_ID` /
   `FULLSEND_TRIAGE_APP_PRIVATE_KEY`). The final implementation
   should create a dedicated `fullsend-ai-prioritize` GitHub App
   with the minimum required permissions: `Organization projects:
   read/write` (for reading/writing RICE fields and reranking) and
   `Issues: write` (for posting reasoning comments). The triage app
   needs temporary `project` scope added for the prototype to work.

7. **`FULLSEND_PROJECT_NUMBER` Actions variable.** Must be set on the
   `.fullsend` repo (or org-level). Value is the GitHub Projects V2
   board number (e.g., `1`). The scaffold should document this as a
   required setup step.

---

### Task 1: JSON Schema for agent output

**Files:**
- Create: `schemas/prioritize-result.schema.json`

- [ ] **Step 1: Create the schema file**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "prioritize-result.schema.json",
  "title": "Prioritize Agent Result",
  "description": "Structured RICE scores from the prioritize agent, validated by the harness before the post-script runs.",
  "type": "object",
  "additionalProperties": false,
  "required": ["reach", "impact", "confidence", "effort", "reasoning"],
  "properties": {
    "reach": {
      "type": "number",
      "minimum": 0.25,
      "maximum": 3
    },
    "impact": {
      "type": "number",
      "minimum": 0.25,
      "maximum": 3
    },
    "confidence": {
      "type": "number",
      "minimum": 0.1,
      "maximum": 1
    },
    "effort": {
      "type": "number",
      "minimum": 0.25,
      "maximum": 3
    },
    "reasoning": {
      "type": "object",
      "additionalProperties": false,
      "required": ["reach", "impact", "confidence", "effort"],
      "properties": {
        "reach": { "type": "string", "minLength": 1 },
        "impact": { "type": "string", "minLength": 1 },
        "confidence": { "type": "string", "minLength": 1 },
        "effort": { "type": "string", "minLength": 1 }
      }
    }
  }
}
```

- [ ] **Step 2: Validate the schema is valid JSON Schema**

Run: `python3 -c "import json; json.load(open('schemas/prioritize-result.schema.json'))"`
Expected: No output (success)

- [ ] **Step 3: Test with a valid sample**

Run:
```bash
python3 -c "
import json
from jsonschema import validate
with open('schemas/prioritize-result.schema.json') as f:
    schema = json.load(f)
validate(instance={
    'reach': 2.0, 'impact': 1.5, 'confidence': 0.8, 'effort': 1.0,
    'reasoning': {
        'reach': 'Affects all konflux-ci repos',
        'impact': 'Moderate improvement to workflow',
        'confidence': 'Well-understood problem',
        'effort': 'Straightforward change'
    }
}, schema=schema)
print('PASS')
"
```
Expected: `PASS`

- [ ] **Step 4: Test with an invalid sample (reach out of range)**

Run:
```bash
python3 -c "
import json
from jsonschema import validate, ValidationError
with open('schemas/prioritize-result.schema.json') as f:
    schema = json.load(f)
try:
    validate(instance={
        'reach': 0.1, 'impact': 1.5, 'confidence': 0.8, 'effort': 1.0,
        'reasoning': {
            'reach': 'r', 'impact': 'i', 'confidence': 'c', 'effort': 'e'
        }
    }, schema=schema)
    print('FAIL: should have rejected reach=0.1')
except ValidationError:
    print('PASS: correctly rejected')
"
```
Expected: `PASS: correctly rejected`

- [ ] **Step 5: Commit**

```bash
git add schemas/prioritize-result.schema.json
git commit -m "feat(prioritize): add RICE output schema"
```

---

### Task 2: Agent definition

**Files:**
- Create: `agents/prioritize.md`

- [ ] **Step 1: Create the agent definition**

The agent definition uses YAML frontmatter (matching triage.md pattern) followed by the full system prompt. The agent:
- Reads a single issue via `gh issue view`
- Produces RICE scores with per-dimension reasoning
- Writes JSON to `$FULLSEND_OUTPUT_DIR/agent-result.json`
- Uses `customer-research` skill if loaded for Reach scoring
- No codebase access — issue context only

```markdown
---
name: prioritize
description: Score a GitHub issue using the RICE framework (Reach, Impact, Confidence, Effort) and produce structured scores with reasoning.
skills:
  - customer-research
tools: Bash(gh,jq)
model: opus
---

You are a prioritization agent. Your job is to evaluate a single GitHub
issue and produce RICE scores that will be used to rank it on the
project board.

## Inputs

- `GITHUB_ISSUE_URL` — the HTML URL of the issue (e.g., `https://github.com/org/repo/issues/42`).

## Step 1: Fetch the issue

```
gh issue view "$GITHUB_ISSUE_URL" --json number,title,body,labels,assignees,createdAt,updatedAt,author,comments,state,milestone
```

If the command fails, write a JSON error result and stop.

## Step 2: Gather context

Read the issue thoroughly — title, body, all comments, labels, and
milestone. Understand what the issue is about, who filed it, and what
it affects.

If the `customer-research` skill is available, use it to understand
who the strategic customers are and how this issue relates to them.
This is especially important for Reach scoring.

If an architecture or planning skill is available in the future, use
it to inform Effort scoring.

## Step 3: Score each RICE dimension

Rate each dimension on the following scales:

### Reach (0.25–3)

How many users or customers are affected by this issue?

| Score | Meaning |
|-------|---------|
| 0.25 | Single user or edge case |
| 0.5 | A few users in one org |
| 1 | One strategic customer or a moderate number of users |
| 1.5 | Multiple strategic customers |
| 2 | Most active users across orgs |
| 3 | All users / platform-wide |

Use the customer-research skill (if available) to identify whether
strategic customers are affected. An issue filed by or affecting a
strategic customer should score higher on Reach.

### Impact (0.25–3)

How much does this issue move the needle for each affected user?

| Score | Meaning |
|-------|---------|
| 0.25 | Minimal — cosmetic or minor inconvenience |
| 0.5 | Low — workaround exists and is easy |
| 1 | Medium — noticeable improvement to workflow |
| 1.5 | High — significant pain point or efficiency gain |
| 2 | Very high — blocking or severely degrading a workflow |
| 3 | Massive — prevents core functionality or causes data loss |

### Confidence (0.1–1)

How confident are you in your Reach, Impact, and Effort estimates?

| Score | Meaning |
|-------|---------|
| 0.1–0.3 | Low — vague issue, unclear scope, guessing |
| 0.4–0.6 | Medium — reasonable understanding but gaps remain |
| 0.7–0.8 | High — well-described issue, clear scope |
| 0.9–1.0 | Very high — obvious problem with clear boundaries |

Lower your confidence when:
- The issue description is vague or incomplete
- You are unsure who is affected (Reach uncertainty)
- The complexity is hard to gauge (Effort uncertainty)
- You lack context about the project or customers

### Effort (0.25–3)

How complex is this issue to resolve?

| Score | Meaning |
|-------|---------|
| 0.25 | Trivial — typo, config change, one-liner |
| 0.5 | Simple — small, well-scoped change |
| 1 | Medium — requires understanding context, touches a few files |
| 1.5 | Moderate — multiple components or some design work |
| 2 | Complex — significant implementation, testing, or coordination |
| 3 | Very complex — large scope, architectural changes, high risk |

Note: Effort is the denominator — higher effort lowers the priority
score. This is intentional.

## Step 4: Write result

Write the result as JSON to `$FULLSEND_OUTPUT_DIR/agent-result.json`.

```json
{
  "reach": 1.5,
  "impact": 2.0,
  "confidence": 0.8,
  "effort": 1.0,
  "reasoning": {
    "reach": "Explanation of who is affected and why this score",
    "impact": "Explanation of the impact on each affected user",
    "confidence": "Explanation of certainty level and any gaps",
    "effort": "Explanation of complexity and what is involved"
  }
}
```

## Output rules

- Write ONLY the JSON file. No markdown report, no other output files.
- The JSON must be valid and parseable. No markdown fences around it,
  no trailing text.
- Do NOT post comments, apply labels, or modify the issue in any way.
  Your only output is the JSON file. A post-script handles all GitHub
  mutations.
- Use the exact scales defined above. Do not invent intermediate
  values outside the documented ranges.
- Each reasoning field should be 1–3 sentences explaining your
  assessment. Be specific — reference issue content, customer names,
  or labels that informed your score.
```

- [ ] **Step 2: Verify frontmatter parses correctly**

Run:
```bash
head -7 agents/prioritize.md | python3 -c "
import sys, yaml
data = yaml.safe_load(sys.stdin.read().replace('---', '', 1).split('---')[0])
assert data['name'] == 'prioritize'
assert 'customer-research' in data['skills']
print('PASS')
"
```
Expected: `PASS`

- [ ] **Step 3: Commit**

```bash
git add agents/prioritize.md
git commit -m "feat(prioritize): add agent definition with RICE scoring prompt"
```

---

### Task 3: Sandbox policy

**Files:**
- Create: `policies/prioritize.yaml`

- [ ] **Step 1: Create the policy file**

Identical to `policies/triage.yaml` — read-only sandbox with network access to GitHub and Vertex AI only.

```yaml
version: 1

filesystem_policy:
  include_workdir: true
  read_only: [/usr, /lib, /proc, /dev/urandom, /app, /etc, /var/log]
  read_write: [/sandbox, /tmp, /dev/null]
landlock:
  compatibility: best_effort
process:
  run_as_user: sandbox
  run_as_group: sandbox

network_policies:
  vertex_ai:
    name: vertex-ai
    endpoints:
      - host: "*.github.com"
        port: 443
        protocol: tcp
        enforcement: enforce
        access: allow
      - host: "*.googleapis.com"
        port: 443
        protocol: tcp
        enforcement: enforce
        access: allow
    binaries:
      - path: "**/curl"
      - path: "**/claude"
      - path: "**/node"
```

- [ ] **Step 2: Commit**

```bash
git add policies/prioritize.yaml
git commit -m "feat(prioritize): add sandbox policy"
```

---

### Task 4: Environment file

**Files:**
- Create: `env/prioritize.env`

- [ ] **Step 1: Create the env file**

This file is mounted into the sandbox so the agent has access to
the issue URL and GitHub token.

```bash
export GITHUB_ISSUE_URL="${GITHUB_ISSUE_URL}"
export GH_TOKEN=${GH_TOKEN}
```

- [ ] **Step 2: Commit**

```bash
git add env/prioritize.env
git commit -m "feat(prioritize): add sandbox env file"
```

---

### Task 5: Setup script

**Files:**
- Create: `scripts/setup-prioritize.sh`

- [ ] **Step 1: Create the setup script**

This script creates the five RICE number fields on the org's GitHub
Project V2 board. It is idempotent — it checks for existing fields
before creating new ones.

```bash
#!/usr/bin/env bash
# setup-prioritize.sh — Create RICE fields on the org's GitHub Project V2 board.
#
# One-off setup script. Idempotent — safe to re-run.
# In the future, this will be invoked by the repo maintenance job
# (https://github.com/fullsend-ai/fullsend/issues/583).
#
# Required env vars:
#   GH_TOKEN       — GitHub token with project admin scope
#   ORG            — GitHub organization (e.g., fullsend-ai)
#   PROJECT_NUMBER — Project board number (e.g., 1)

set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN must be set}"
: "${ORG:?ORG must be set}"
: "${PROJECT_NUMBER:?PROJECT_NUMBER must be set}"

# Resolve the project node ID.
PROJECT_ID=$(gh project view "${PROJECT_NUMBER}" --owner "${ORG}" --format json | jq -r '.id')
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "null" ]]; then
  echo "ERROR: could not resolve project ${PROJECT_NUMBER} for org ${ORG}"
  exit 1
fi
echo "Project ID: ${PROJECT_ID}"

# Get existing fields.
EXISTING_FIELDS=$(gh project field-list "${PROJECT_NUMBER}" --owner "${ORG}" --format json | jq -r '.fields[].name')

# Create number fields if they don't already exist.
for field_name in "RICE Reach" "RICE Impact" "RICE Confidence" "RICE Effort" "RICE Score"; do
  if echo "${EXISTING_FIELDS}" | grep -qx "${field_name}"; then
    echo "Field '${field_name}' already exists — skipping."
  else
    echo "Creating field '${field_name}'..."
    gh api graphql -f query='
      mutation($projectId: ID!, $name: String!) {
        createProjectV2Field(input: {
          projectId: $projectId
          dataType: NUMBER
          name: $name
        }) {
          projectV2Field { id name }
        }
      }
    ' -f projectId="${PROJECT_ID}" -f name="${field_name}"
    echo "Created '${field_name}'."
  fi
done

echo "Setup complete."
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/setup-prioritize.sh`

- [ ] **Step 3: Commit**

```bash
git add scripts/setup-prioritize.sh
git commit -m "feat(prioritize): add setup script for RICE project fields"
```

---

### Task 6: Pre-script (issue selector)

**Files:**
- Create: `scripts/pre-prioritize.sh`

- [ ] **Step 1: Create the pre-script**

This script selects the next issue to score from the org's GitHub
Project board. It picks unscored items first, then stale items. If
nothing needs scoring, it exits 78 (graceful skip).

```bash
#!/usr/bin/env bash
# pre-prioritize.sh — Select the next issue to RICE-score from the project board.
#
# Runs on the host via the harness pre_script mechanism.
#
# Selection logic:
#   1. Find project items where "RICE Score" field is null → pick first.
#   2. If all scored: find item with oldest "RICE Score" update.
#   3. If oldest is newer than STALE_THRESHOLD → exit 78 (nothing to do).
#   4. Otherwise: export GITHUB_ISSUE_URL for the agent.
#
# Required env vars:
#   GH_TOKEN         — GitHub token with project read scope
#   ORG              — GitHub organization
#   PROJECT_NUMBER   — Project board number
#
# Optional env vars:
#   STALE_THRESHOLD  — Re-score items older than this (default: 7d).
#                      Supports: Nd (days), Nh (hours).

set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN must be set}"
: "${ORG:?ORG must be set}"
: "${PROJECT_NUMBER:?PROJECT_NUMBER must be set}"

STALE_THRESHOLD="${STALE_THRESHOLD:-7d}"

# Parse threshold into seconds.
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

# Fetch all project items with their RICE Score field and content URL.
# We use the GraphQL API because gh project item-list does not expose
# custom field values reliably.
PROJECT_ID=$(gh project view "${PROJECT_NUMBER}" --owner "${ORG}" --format json | jq -r '.id')

# Get the RICE Score field ID.
SCORE_FIELD_ID=$(gh project field-list "${PROJECT_NUMBER}" --owner "${ORG}" --format json \
  | jq -r '.fields[] | select(.name == "RICE Score") | .id')

if [[ -z "${SCORE_FIELD_ID}" ]]; then
  echo "ERROR: 'RICE Score' field not found on project ${PROJECT_NUMBER}."
  echo "Run scripts/setup-prioritize.sh first."
  exit 1
fi

# Fetch items via GraphQL to get field values.
# Paginate up to 100 items (sufficient for early adoption).
ITEMS_JSON=$(gh api graphql -f query='
  query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        items(first: 100) {
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
                state
              }
            }
          }
        }
      }
    }
  }
' -f projectId="${PROJECT_ID}")

# Find the first open issue with no RICE Score.
UNSCORED_URL=$(echo "${ITEMS_JSON}" | jq -r --arg fid "${SCORE_FIELD_ID}" '
  .data.node.items.nodes[]
  | select(.content.state == "OPEN")
  | select(
      [.fieldValues.nodes[]
       | select(.field.id == $fid)
      ] | length == 0
    )
  | .content.url
' | head -1)

if [[ -n "${UNSCORED_URL}" && "${UNSCORED_URL}" != "null" ]]; then
  echo "Found unscored issue: ${UNSCORED_URL}"
  echo "GITHUB_ISSUE_URL=${UNSCORED_URL}" >> "${GITHUB_ENV:-/dev/null}"
  export GITHUB_ISSUE_URL="${UNSCORED_URL}"
  exit 0
fi

echo "All issues are scored. Checking for stale scores..."

# Find the item with the oldest RICE Score update.
OLDEST=$(echo "${ITEMS_JSON}" | jq -r --arg fid "${SCORE_FIELD_ID}" '
  [.data.node.items.nodes[]
   | select(.content.state == "OPEN")
   | {
       url: .content.url,
       updatedAt: ([.fieldValues.nodes[] | select(.field.id == $fid) | .updatedAt] | first)
     }
   | select(.updatedAt != null)
  ]
  | sort_by(.updatedAt)
  | first
  | "\(.updatedAt)\t\(.url)"
')

if [[ -z "${OLDEST}" || "${OLDEST}" == "null" ]]; then
  echo "No scored items found. Nothing to do."
  exit 78
fi

OLDEST_DATE=$(echo "${OLDEST}" | cut -f1)
OLDEST_URL=$(echo "${OLDEST}" | cut -f2)

# Check staleness.
OLDEST_EPOCH=$(date -d "${OLDEST_DATE}" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "${OLDEST_DATE}" +%s 2>/dev/null)
NOW_EPOCH=$(date +%s)
AGE_SECONDS=$(( NOW_EPOCH - OLDEST_EPOCH ))

if [[ ${AGE_SECONDS} -lt ${THRESHOLD_SECONDS} ]]; then
  echo "Oldest score is $(( AGE_SECONDS / 3600 ))h old (threshold: ${STALE_THRESHOLD}). Nothing to do."
  exit 78
fi

echo "Found stale score ($(( AGE_SECONDS / 86400 ))d old): ${OLDEST_URL}"
echo "GITHUB_ISSUE_URL=${OLDEST_URL}" >> "${GITHUB_ENV:-/dev/null}"
export GITHUB_ISSUE_URL="${OLDEST_URL}"
exit 0
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/pre-prioritize.sh`

- [ ] **Step 3: Commit**

```bash
git add scripts/pre-prioritize.sh
git commit -m "feat(prioritize): add pre-script for issue selection"
```

---

### Task 7: Post-script (score writer)

**Files:**
- Create: `scripts/post-prioritize.sh`

- [ ] **Step 1: Create the post-script**

This script reads the agent's RICE output, computes the final score,
writes all five values to the project board, and posts a reasoning
comment on the issue.

```bash
#!/usr/bin/env bash
# post-prioritize.sh — Write RICE scores to the project board and post a reasoning comment.
#
# Runs on the host after sandbox cleanup. Working directory is the fullsend
# run output directory (e.g., /tmp/fullsend/agent-prioritize-<id>/).
#
# Required env vars:
#   GITHUB_ISSUE_URL  — HTML URL of the issue
#   GH_TOKEN          — GitHub token with project write + issues write scope
#   ORG               — GitHub organization
#   PROJECT_NUMBER    — Project board number

set -euo pipefail

: "${GITHUB_ISSUE_URL:?GITHUB_ISSUE_URL must be set}"
: "${GH_TOKEN:?GH_TOKEN must be set}"
: "${ORG:?ORG must be set}"
: "${PROJECT_NUMBER:?PROJECT_NUMBER must be set}"

# Find the result JSON from the last iteration.
RESULT_FILE=""
for dir in iteration-*/output; do
  if [[ -f "${dir}/agent-result.json" ]]; then
    RESULT_FILE="${dir}/agent-result.json"
  fi
done

if [[ -z "${RESULT_FILE}" ]]; then
  echo "ERROR: agent-result.json not found in any iteration output directory"
  exit 1
fi

echo "Reading RICE result from: ${RESULT_FILE}"

if ! jq empty "${RESULT_FILE}" 2>/dev/null; then
  echo "ERROR: ${RESULT_FILE} is not valid JSON"
  exit 1
fi

# Extract scores.
REACH=$(jq -r '.reach' "${RESULT_FILE}")
IMPACT=$(jq -r '.impact' "${RESULT_FILE}")
CONFIDENCE=$(jq -r '.confidence' "${RESULT_FILE}")
EFFORT=$(jq -r '.effort' "${RESULT_FILE}")

# Compute final RICE score: (R * I * C) / E
SCORE=$(python3 -c "
r, i, c, e = ${REACH}, ${IMPACT}, ${CONFIDENCE}, ${EFFORT}
print(round(r * i * c / e, 2))
")

echo "RICE scores: R=${REACH} I=${IMPACT} C=${CONFIDENCE} E=${EFFORT} → Score=${SCORE}"

# Extract reasoning.
REASONING_REACH=$(jq -r '.reasoning.reach' "${RESULT_FILE}")
REASONING_IMPACT=$(jq -r '.reasoning.impact' "${RESULT_FILE}")
REASONING_CONFIDENCE=$(jq -r '.reasoning.confidence' "${RESULT_FILE}")
REASONING_EFFORT=$(jq -r '.reasoning.effort' "${RESULT_FILE}")

# --- Write scores to the project board ---

# Resolve project and item IDs.
PROJECT_ID=$(gh project view "${PROJECT_NUMBER}" --owner "${ORG}" --format json | jq -r '.id')

# Get issue node ID from URL.
REPO=$(echo "${GITHUB_ISSUE_URL}" | sed 's|https://github.com/||; s|/issues/.*||')
ISSUE_NUMBER=$(basename "${GITHUB_ISSUE_URL}")
ISSUE_NODE_ID=$(gh api "repos/${REPO}/issues/${ISSUE_NUMBER}" --jq '.node_id')

# Find the project item ID for this issue.
ITEM_ID=$(gh api graphql -f query='
  query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        items(first: 100) {
          nodes {
            id
            content { ... on Issue { url } }
          }
        }
      }
    }
  }
' -f projectId="${PROJECT_ID}" \
  | jq -r --arg url "${GITHUB_ISSUE_URL}" \
    '.data.node.items.nodes[] | select(.content.url == $url) | .id')

if [[ -z "${ITEM_ID}" || "${ITEM_ID}" == "null" ]]; then
  echo "ERROR: issue ${GITHUB_ISSUE_URL} not found on project board"
  exit 1
fi

# Get field IDs for all RICE fields.
FIELDS_JSON=$(gh project field-list "${PROJECT_NUMBER}" --owner "${ORG}" --format json)

get_field_id() {
  echo "${FIELDS_JSON}" | jq -r --arg name "$1" '.fields[] | select(.name == $name) | .id'
}

REACH_FIELD_ID=$(get_field_id "RICE Reach")
IMPACT_FIELD_ID=$(get_field_id "RICE Impact")
CONFIDENCE_FIELD_ID=$(get_field_id "RICE Confidence")
EFFORT_FIELD_ID=$(get_field_id "RICE Effort")
SCORE_FIELD_ID=$(get_field_id "RICE Score")

# Update each field on the project item.
update_field() {
  local field_id="$1"
  local value="$2"
  gh api graphql -f query='
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $value: Float!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $projectId
        itemId: $itemId
        fieldId: $fieldId
        value: { number: $value }
      }) {
        projectV2Item { id }
      }
    }
  ' -f projectId="${PROJECT_ID}" -f itemId="${ITEM_ID}" -f fieldId="${field_id}" -F value="${value}"
}

echo "Writing scores to project board..."
update_field "${REACH_FIELD_ID}" "${REACH}"
update_field "${IMPACT_FIELD_ID}" "${IMPACT}"
update_field "${CONFIDENCE_FIELD_ID}" "${CONFIDENCE}"
update_field "${EFFORT_FIELD_ID}" "${EFFORT}"
update_field "${SCORE_FIELD_ID}" "${SCORE}"
echo "Project fields updated."

# --- Post reasoning comment ---

COMMENT=$(cat <<COMMENT_EOF
<!-- fullsend:prioritize-agent -->
## RICE Priority Score: ${SCORE}

| Dimension | Score | Reasoning |
|-----------|-------|-----------|
| **Reach** | ${REACH} | ${REASONING_REACH} |
| **Impact** | ${IMPACT} | ${REASONING_IMPACT} |
| **Confidence** | ${CONFIDENCE} | ${REASONING_CONFIDENCE} |
| **Effort** | ${EFFORT} | ${REASONING_EFFORT} |

**Formula:** (${REACH} × ${IMPACT} × ${CONFIDENCE}) / ${EFFORT} = **${SCORE}**
COMMENT_EOF
)

if [[ ! "${GITHUB_ISSUE_URL}" =~ ^https://github\.com/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+/issues/[0-9]+$ ]]; then
  echo "ERROR: GITHUB_ISSUE_URL does not match expected pattern: ${GITHUB_ISSUE_URL}"
  exit 1
fi

echo "Posting RICE comment..."
printf '%s' "${COMMENT}" | fullsend post-comment --repo "${REPO}" --number "${ISSUE_NUMBER}" --marker "<!-- fullsend:prioritize-agent -->" --token "${GH_TOKEN}" --result -
echo "Post-prioritize complete."
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/post-prioritize.sh`

- [ ] **Step 3: Commit**

```bash
git add scripts/post-prioritize.sh
git commit -m "feat(prioritize): add post-script for score writing"
```

---

### Task 8: Harness configuration

**Files:**
- Create: `harness/prioritize.yaml`
- Create: `env/prioritize.env`

- [ ] **Step 1: Create the harness file**

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
  STALE_THRESHOLD: ${STALE_THRESHOLD:-7d}
  FULLSEND_OUTPUT_SCHEMA: ${FULLSEND_DIR}/schemas/prioritize-result.schema.json

timeout_minutes: 10
```

- [ ] **Step 2: Commit**

```bash
git add harness/prioritize.yaml env/prioritize.env
git commit -m "feat(prioritize): add harness config and env file"
```

---

### Task 9: Register the agent in config.yaml

**Files:**
- Modify: `config.yaml:18-30` (agents section)

- [ ] **Step 1: Add the agent registration**

Add after the review agent entry in the `agents:` list:

```yaml
    - role: prioritize
      name: fullsend-ai-prioritize
      slug: fullsend-ai-prioritize
```

And add the role to the `defaults.roles` list:

```yaml
defaults:
    roles:
        - fullsend
        - triage
        - coder
        - review
        - prioritize
```

- [ ] **Step 2: Verify YAML is valid**

Run: `python3 -c "import yaml; yaml.safe_load(open('config.yaml')); print('PASS')"`
Expected: `PASS`

- [ ] **Step 3: Commit**

```bash
git add config.yaml
git commit -m "feat(prioritize): register agent in config.yaml"
```

---

### Task 10: Final integration check

- [ ] **Step 1: Verify all files exist**

Run:
```bash
for f in \
  agents/prioritize.md \
  schemas/prioritize-result.schema.json \
  policies/prioritize.yaml \
  harness/prioritize.yaml \
  env/prioritize.env \
  scripts/setup-prioritize.sh \
  scripts/pre-prioritize.sh \
  scripts/post-prioritize.sh \
; do
  if [[ -f "$f" ]]; then
    echo "OK: $f"
  else
    echo "MISSING: $f"
  fi
done
```

Expected: All `OK`

- [ ] **Step 2: Verify scripts are executable**

Run:
```bash
for f in scripts/setup-prioritize.sh scripts/pre-prioritize.sh scripts/post-prioritize.sh; do
  if [[ -x "$f" ]]; then echo "OK: $f"; else echo "NOT EXECUTABLE: $f"; fi
done
```

Expected: All `OK`

- [ ] **Step 3: Verify schema validates a good sample end-to-end via validate-output-schema.sh**

Run:
```bash
mkdir -p /tmp/test-prioritize/output
cat > /tmp/test-prioritize/output/agent-result.json <<'SAMPLE'
{
  "reach": 1.5,
  "impact": 2.0,
  "confidence": 0.8,
  "effort": 1.0,
  "reasoning": {
    "reach": "Affects all konflux-ci repos currently onboarded",
    "impact": "Significant workflow improvement",
    "confidence": "Well-described issue with clear scope",
    "effort": "Straightforward implementation touching a few files"
  }
}
SAMPLE
cd /tmp/test-prioritize
FULLSEND_OUTPUT_SCHEMA=/home/rbean/code/fullsend-ai-fullsend/schemas/prioritize-result.schema.json \
  bash /home/rbean/code/fullsend-ai-fullsend/scripts/validate-output-schema.sh
```

Expected: `PASS: output validated against schema`

- [ ] **Step 4: Verify harness references are consistent**

Run:
```bash
cd /home/rbean/code/fullsend-ai-fullsend
python3 -c "
import yaml
with open('harness/prioritize.yaml') as f:
    h = yaml.safe_load(f)
errors = []
import os
for key in ['agent', 'policy', 'pre_script', 'post_script']:
    path = h[key]
    if not os.path.exists(path):
        errors.append(f'MISSING: {key} -> {path}')
for skill in h.get('skills', []):
    if not os.path.isdir(skill):
        errors.append(f'MISSING skill: {skill}')
if errors:
    print('\n'.join(errors))
else:
    print('PASS: all harness references resolve')
"
```

Expected: `PASS: all harness references resolve`
