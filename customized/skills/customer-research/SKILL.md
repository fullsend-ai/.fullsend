---
name: customer-research
description: >-
  Use when triaging issues, prioritizing work, making product decisions, or
  needing to understand who is using fullsend-ai, which customers are
  strategic, and what their current onboarding status is. Also inspect
  custom/dev-blocker and custom/tsd-blocker labels on the issue under
  consideration to identify which customer cohorts are blocked.
---

# Customer Research

## When to use

Use this skill when you need customer context to inform decisions:
prioritizing issues, scoping features, evaluating urgency, or
understanding who a GitHub user is in relation to fullsend-ai adoption.

Do NOT use for purely technical questions that don't involve
prioritization or customer impact.

## Issue adoption blocker labels

When evaluating a specific issue, **check its labels first**. Use labels
already returned by `gh issue view` (or fetch them if only an issue
number/repo is known). Do not infer blocker status from title or body
alone when labels are present.

These are `custom/*` team labels — not triage pipeline control labels.

| Label | Blocks | Maps to strategic customer |
|-------|--------|----------------------------|
| `custom/dev-blocker` | `redhat-developer` GitHub org adoption | §2 — redhat-developer (via @deboer-tim) |
| `custom/tsd-blocker` | TSD (Trusted Software Delivery) adoption | §5 — TSD (Trusted Software Delivery) |

**When either label is present:**

- Treat the issue as an **adoption blocker** for that cohort — not
  merely feedback or a nice-to-have.
- For RICE scoring (prioritize agent): bias **Reach** toward at least
  **1** (one strategic customer) and **Impact** toward at least **2**
  (blocking or severely degrading a workflow), unless issue content
  clearly contradicts that.
- Mention the label and blocked cohort explicitly in Reach/Impact
  reasoning.
- An issue may carry **both** labels; in that case both cohorts are
  blocked and Reach should reflect multiple strategic customers (≥
  **1.5**).

## Project status

fullsend-ai passed its MVP milestone on April 23, 2026. The project is
in active adoption, executing against revised 90-day goals (target: June
30, 2026) focused on bug-fix workflow adoption, feature refinement
capabilities, and evaluating trustworthiness of agent behaviors.

A key near-term focus is multi-platform support (especially GitLab),
driven by demand from multiple customers and use cases.

All agentic workflows are hybrid — teams use fullsend alongside manual
and locally-driven methods. Auto-merge is not an expectation at this
phase; agent-produced code is reviewed by humans before merging.

> **Staleness warning:** The customer details below are a point-in-time
> snapshot (last updated June 2026). Where possible, commands are
> provided to fetch live data. Static content should be periodically
> reviewed and updated.

## Roadmap

Consult [docs/roadmap.md](https://github.com/fullsend-ai/fullsend/blob/main/docs/roadmap.md)
for context about what topics, areas, and outcomes we are pursuing as strategic
next steps, independent of target user cohort considerations.

## Strategic customers

The strategic customers are listed below. The fullsend-ai org itself is
also a user (dogfooding), but the external customers are the ones that
matter for prioritization.

Issues and feedback from these customers are direct signals of the
onboarding experience and should be treated with urgency. Other users
are welcome and should be supported, but strategic customers take
precedence when prioritizing work.

### 1. konflux-ci

Many repositories in the `konflux-ci` GitHub org are onboarded — the
number has expanded significantly since initial onboarding. To get the
current list of enrolled repositories, run:

```bash
gh api repos/konflux-ci/.fullsend/contents/config.yaml \
  --jq '.content' | base64 -d | yq .
```

The 90-day goal is to continue scaling usage across konflux-ci and to
incorporate feature refinement into the existing process.

### 2. redhat-developer (via @deboer-tim)

@deboer-tim is the primary contact for the Developer teams. The goal
has shifted from openkaiden to onboarding 2 or more repos from the
`redhat-developer` GitHub org. He previously used a personal fork org —
[openkaiden-fullsend](https://github.com/openkaiden-fullsend) — for
early testing.

Issues he has filed:
[fullsend-ai/fullsend issues by deboer-tim](https://github.com/fullsend-ai/fullsend/issues?q=is%3Aissue+author%3Adeboer-tim).
His feedback is a direct signal of what a new org onboarding experience
looks like from the outside.

Issues labeled `custom/dev-blocker` are confirmed adoption blockers for
this org.

### 3. guacsec (via @mrizzi)

@mrizzi is evaluating fullsend-ai for potential use in the
[guacsec](https://github.com/guacsec) GitHub org. His goal is to
demonstrate to other guacsec maintainers what the workflow looks like
and whether the platform should be considered safe. Trust and
transparency are key concerns for this customer.

Onboarding guacsec upstream is a 90-day goal (target: June 30, 2026).
The plan is for fullsend to be installed in at least one guacsec repo,
with Red Hat P&D paying for inference, and upstream maintainers agreeing
to try it.

@mrizzi has not filed issues directly but is mentioned in issues
[#457](https://github.com/fullsend-ai/fullsend/issues/457) and
[#459](https://github.com/fullsend-ai/fullsend/issues/459), which
relate to local execution and pre-adoption evaluation — likely driven
by his need to demo the platform safely.

### 4. RHDH / Developer teams (via @durandom)

@durandom and the RHDH (Red Hat Developer Hub) team have started using
fullsend. The Developer teams are a 90-day goal for bug-fix workflow
adoption, though onboarding is currently blocked on reducing install
overhead and simplifying customization options. Unblocking these teams
is a priority for the fullsend team in June 2026.

### 5. TSD (Trusted Software Delivery)

The **TSD** (Trusted Software Delivery) team maintains developer-facing
Red Hat products focused on secure software supply chains, notably
**RHTPA** (Red Hat Trusted Profile Analyzer) and **RHTAS** (Red Hat
Trusted Artifact Signer). RHTPA automates SBOM management, risk
profiling, and compliance checking; RHTAS provides cryptographic signing
and verification for software artifacts (Sigstore-based).

**Contacts:** @Roming22 (TSD portfolio PM), @mrizzi (RHTPA PM). Note:
@mrizzi also appears in the guacsec evaluation context (§3) — both
roles are relevant.

Relevant GitHub orgs include
[`securesign`](https://github.com/securesign) (RHTAS midstream) and
[`trustification`](https://github.com/trustification) (RHTPA-related
tooling). These products sit in the Red Hat Trusted Software Supply
Chain portfolio alongside RHDH and Konflux.

Issues labeled `custom/tsd-blocker` are confirmed adoption blockers for
TSD customers — treat them with the same urgency as `custom/dev-blocker`
issues for redhat-developer.
