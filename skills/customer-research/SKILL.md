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
early-stage and actively onboarding its first users.

> **Staleness warning:** The customer details below are a point-in-time
> snapshot. Where possible, commands are provided to fetch live data.
> Static content should be periodically reviewed and updated.

## Strategic customers

There are three strategic external customers listed below. The
fullsend-ai org itself is also a user (dogfooding), but the external
customers are the ones that matter for prioritization.

All three are high priority. Issues and feedback from these customers
are direct signals of the new-user onboarding experience and should be
treated with urgency. Other users are welcome and should be supported,
but these three take precedence when prioritizing work.

### 1. konflux-ci

Several repositories in the `konflux-ci` GitHub org are onboarded. To
get the current list of enrolled repositories, run:

```bash
gh api repos/konflux-ci/.fullsend/contents/config.yaml \
  --jq '.content' | base64 -d | yq .
```

We expect a few dozen more konflux-ci repositories to onboard during
May 2026.

### 2. openkaiden (via @deboer-tim)

@deboer-tim is evaluating fullsend-ai for the openkaiden project. He
created a personal fork org —
[openkaiden-fullsend](https://github.com/openkaiden-fullsend) — so he
can test the integration without disrupting the real openkaiden org's
development workflow while fullsend-ai is still young.

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

As of April 2026, guacsec has not yet onboarded (no `.fullsend` repo
exists). @mrizzi has not filed issues directly but is mentioned in
issues [#457](https://github.com/fullsend-ai/fullsend/issues/457) and
[#459](https://github.com/fullsend-ai/fullsend/issues/459), which
relate to local execution and pre-adoption evaluation — likely driven
by his need to demo the platform safely.
