# Prioritize Agent — Design Spec

## Purpose

A scheduled, org-scoped agent that scores GitHub issues (and eventually
Jira items) using RICE methodology. Runs on a cron trigger from the
`org/.fullsend` repo, picks one issue per invocation, produces
structured RICE scores, and stores them as project board fields for
ranking.

## RICE Scales

| Dimension | Range | Meaning |
|-----------|-------|---------|
| Reach | 0.25--3 | How many users/customers affected |
| Impact | 0.25--3 | How much it moves the needle per affected user |
| Confidence | 0.1--1 | How sure we are about R, I, and E estimates |
| Effort | 0.25--3 | Complexity (not person-months) |
| Score | computed | `(R * I * C) / E` — higher is better |

## Files

### Platform-agnostic core

#### `agents/prioritize.md`

Agent definition and system prompt. The agent:

- Receives `GITHUB_ISSUE_URL` as input (selected by the pre-script).
- Reads the issue (title, body, comments, labels) via `gh issue view`.
  No codebase access — issue context only.
- Produces RICE scores with per-dimension reasoning.
- Writes structured JSON to `$FULLSEND_OUTPUT_DIR/agent-result.json`.
- Uses the `customer-research` skill if available to inform Reach
  scoring. Works without it.
- Leaves hooks for future skills: an architecture or planning skill
  for Effort estimation, etc.
- Tools: `Bash(gh,jq)` only.
- Model: opus.

#### `schemas/prioritize-result.schema.json`

JSON Schema for agent output:

```json
{
  "type": "object",
  "required": ["reach", "impact", "confidence", "effort", "reasoning"],
  "properties": {
    "reach": { "type": "number", "minimum": 0.25, "maximum": 3 },
    "impact": { "type": "number", "minimum": 0.25, "maximum": 3 },
    "confidence": { "type": "number", "minimum": 0.1, "maximum": 1 },
    "effort": { "type": "number", "minimum": 0.25, "maximum": 3 },
    "reasoning": {
      "type": "object",
      "required": ["reach", "impact", "confidence", "effort"],
      "properties": {
        "reach": { "type": "string", "minLength": 1 },
        "impact": { "type": "string", "minLength": 1 },
        "confidence": { "type": "string", "minLength": 1 },
        "effort": { "type": "string", "minLength": 1 }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
```

### Platform-specific (GitHub — first implementation)

#### `scripts/setup-prioritize.sh`

One-off setup script. Creates five number fields on the org's GitHub
Project V2 board via the GraphQL API:

- Reach, Impact, Confidence, Effort, RICE Score.

Idempotent — checks for existing fields before creating. Run manually
for now. In the future, invoked by the repo maintenance job (see
[#583](https://github.com/fullsend-ai/fullsend/issues/583)).

#### `scripts/pre-prioritize.sh`

Issue selection logic, runs on the runner before sandbox creation:

1. Query the org's GitHub Project board for items where the RICE Score
   field is null/empty. Pick the first one found.
2. If all items are scored: find the item whose RICE Score was set the
   longest ago.
3. If that item was scored more recently than `$STALE_THRESHOLD`
   (env var, default `7d`): `exit 78` — nothing to do, skip the LLM.
4. Otherwise: resolve the item to a `GITHUB_ISSUE_URL` and export it.

`exit 78` signals a graceful skip. Until the runtime supports this
natively ([#582](https://github.com/fullsend-ai/fullsend/issues/582)),
it will surface as an error.

#### `scripts/post-prioritize.sh`

Runs on the runner after sandbox cleanup:

1. Reads `agent-result.json` from iteration output.
2. Computes `score = (reach * impact * confidence) / effort`.
3. Sets all five project fields (Reach, Impact, Confidence, Effort,
   RICE Score) on the item via `gh project item-edit`.
4. Posts a comment on the issue with the RICE breakdown, reasoning, and
   the `<!-- fullsend:prioritize-agent -->` marker.

### Harness and policy

#### `harness/prioritize.yaml`

```yaml
agent: agents/prioritize.md
model: opus
image: ghcr.io/fullsend-ai/fullsend-sandbox:latest
policy: policies/prioritize.yaml

skills:
  - skills/customer-research

pre_script: scripts/pre-prioritize.sh

validation_loop:
  script: scripts/validate-output-schema.sh
  max_iterations: 2

post_script: scripts/post-prioritize.sh

runner_env:
  GH_TOKEN: ${GH_TOKEN}
  GITHUB_ISSUE_URL: ${GITHUB_ISSUE_URL}
  FULLSEND_OUTPUT_SCHEMA: ${FULLSEND_DIR}/schemas/prioritize-result.schema.json
  STALE_THRESHOLD: "7d"

timeout_minutes: 10
```

#### `policies/prioritize.yaml`

Read-only sandbox, modeled after `policies/triage.yaml`. Network access
to Vertex AI (inference) and GitHub API only. No filesystem write access
beyond the output directory.

### Registration

#### `config.yaml`

Add the agent:

```yaml
- role: prioritize
  name: fullsend-ai-prioritize
  slug: fullsend-ai-prioritize
```

## Execution pattern: org-scoped, no shim

This agent introduces a new execution pattern. Existing agents are
event-driven and repo-scoped — they flow through per-repo shim
workflows into `dispatch.yml`. The prioritize agent is different:

- **Scheduled**, not event-driven (cron trigger).
- **Org-scoped**, not repo-scoped (operates on a project board that
  spans all repos in the org).

Running this through the per-repo shim would fire N times per cron tick
(once per enrolled repo), all racing to score the same org-wide board.

Instead, the prioritize agent runs directly from a scheduled workflow in
the `org/.fullsend` repo, bypassing the shim entirely. The `.fullsend`
repo is already the orchestration hub — it has the agent definitions,
the harness, and the tokens.

### Future ADRs needed

If this pattern is built into fullsend as a first-class capability,
three ADRs are needed:

1. **Scheduled agent jobs** — When to use the per-repo shim schedule
   vs. an org-level schedule in `.fullsend`. Defines the boundary
   between repo-scoped and org-scoped scheduling.
2. **Org-scoped agents** — Agents that operate across repos (project
   boards, cross-repo metrics, org-level reporting). How they differ
   from repo-scoped agents in terms of inputs, permissions, and
   dispatch.
3. **Agent setup scripts** — How agents declare and provision their
   prerequisites (project fields, labels, etc.). Tied to
   [#583](https://github.com/fullsend-ai/fullsend/issues/583).

## Platform abstraction (GitHub vs Jira)

The agent definition, schema, and skills are platform-agnostic. Only
the pre/post/setup scripts change:

| Component | GitHub | Jira |
|-----------|--------|------|
| `agents/prioritize.md` | Same | Same |
| `schemas/prioritize-result.schema.json` | Same | Same |
| `scripts/setup-prioritize.sh` | GH Project GraphQL API | Jira custom fields API |
| `scripts/pre-prioritize.sh` | `gh project item-list` | Jira JQL query |
| `scripts/post-prioritize.sh` | `gh project item-edit` | Jira API set fields |

A Jira implementation would use a separate harness file
(`harness/prioritize-jira.yaml`) pointing to the same agent but
different scripts.

## Known limitations

- `exit 78` for graceful skip will surface as a pipeline error until
  [#582](https://github.com/fullsend-ai/fullsend/issues/582) lands.
- No codebase access — Effort scoring relies on issue context only.
  A future architecture/planning skill can enhance this.
- Setup script must be run manually until
  [#583](https://github.com/fullsend-ai/fullsend/issues/583) lands.
- Staleness detection for re-scoring relies on querying when the
  project field was last set. If the GitHub Projects API does not
  expose field-level timestamps, the post-script comment marker
  timestamp is the fallback.
