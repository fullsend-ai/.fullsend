---
name: docs-triage-guard
description: >-
  Detect ADR and design-doc issues within the documentation category and
  set sub_category in triage_summary to prevent auto-coding.
---

# Design Document Detection

When triaging an issue with `category: "documentation"`, determine
whether it is a design document that requires human discussion before
implementation.

## Classification

**ADR** (`sub_category: "adr"`):
- Title contains "ADR" or "Architecture Decision Record"
- Body uses ADR template sections: Status, Context, Decision,
  Consequences
- Proposes or records an architectural decision

**Design doc** (`sub_category: "design-doc"`):
- Title contains "RFC", "design doc", "design document", or "proposal"
- Body describes a new system, significant redesign, or architectural
  change that requires discussion
- Proposes alternatives or trade-offs for a technical approach

**Neither** (omit `sub_category`):
- Typo or grammar fixes in existing documentation
- Updating docs to match current code behavior
- Broken links, missing pages, README updates
- Adding usage examples or tutorials
- API reference updates

## Output

When you detect an ADR or design document, include `sub_category` in
your `triage_summary`:

```json
{
  "triage_summary": {
    "category": "documentation",
    "sub_category": "adr",
    ...
  }
}
```

For regular documentation issues, omit `sub_category` entirely.
