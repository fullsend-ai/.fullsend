---
name: customer-research
description: >-
  Use when triaging issues, prioritizing work, making product decisions, or
  needing to understand who is using fullsend-ai, which customers are
  strategic, and what their current onboarding status is.
---

# Customer Research

## When to use

Use this skill when you need customer context to inform decisions:
prioritizing issues, scoping features, evaluating urgency, or
understanding who a GitHub user is in relation to fullsend-ai adoption.

Do NOT use for purely technical questions that don't involve
prioritization or customer impact.

## Project status

fullsend-ai passed its MVP milestone on April 23, 2026. The project is
in active adoption, executing against revised 90-day goals (target: June
30, 2026) focused on bug-fix workflow adoption, feature refinement
capabilities, and evaluating trustworthiness of agent behaviors. See
the P&D Agentic SDLC 30/60/90 Day Goals doc for the full plan.

All agentic workflows are hybrid — teams use fullsend alongside manual
and locally-driven methods. Auto-merge is not an expectation at this
phase; agent-produced code is reviewed by humans before merging.

> **Staleness warning:** The customer details below are a point-in-time
> snapshot (last updated June 2026). Where possible, commands are
> provided to fetch live data. Static content should be periodically
> reviewed and updated.

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

### 5. fullsend-playground (new interest via @ascerra's demo)

@ascerra ran a demo on June 3, 2026 inviting people to try fullsend
via the `fullsend-playground` GitHub org. This has generated a large
number of new interested users checking out the project. These are
early explorers — not yet strategic customers — but their feedback is
valuable signal on the out-of-box experience and should be monitored.
