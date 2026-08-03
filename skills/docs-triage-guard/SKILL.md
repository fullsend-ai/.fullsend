---
name: docs-triage-guard
description: >-
  Detect ADR and design-doc issues and route them to human review
  instead of auto-coding.
---

# Design Document Detection

When triaging an issue, determine whether it is a design document that
requires human discussion before implementation.

## When to activate

Check every issue — not just those you would categorize as
`documentation`. ADR and design-doc issues sometimes look like feature
requests or bug investigations.

## Classification

**ADR** (Architecture Decision Record):
- Title contains "ADR" or "Architecture Decision Record"
- Body uses ADR template sections: Status, Context, Decision,
  Consequences
- Proposes or records an architectural decision

**Design doc** (RFC, proposal, design document):
- Title contains "RFC", "design doc", "design document", or "proposal"
- Body describes a new system, significant redesign, or architectural
  change that requires discussion
- Proposes alternatives or trade-offs for a technical approach

**Not a design doc** (do NOT apply this guidance):
- Typo or grammar fixes in existing documentation
- Updating docs to match current code behavior
- Broken links, missing pages, README updates
- Adding usage examples or tutorials
- API reference updates

## What to do when you detect a design document

1. Set `category` to `"other"` in your `triage_summary`. Do NOT use
   `"documentation"` — that would auto-promote to `ready-to-code`.

2. Include `label_actions` to apply tracking labels:

```json
{
  "triage_summary": {
    "category": "other",
    ...
  },
  "label_actions": {
    "reason": "Design document requires human review before implementation",
    "actions": [
      {"action": "add", "label": "design-doc"},
      {"action": "add", "label": "documentation"}
    ]
  }
}
```

3. In your `comment`, note that this issue was identified as a design
   document and routed for human review rather than auto-coding.

For regular documentation issues, proceed normally with
`category: "documentation"` — this guidance only applies to ADRs and
design documents.
