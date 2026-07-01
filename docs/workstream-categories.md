# Workstream Categories

Reference document for the [Fullsend-ai Workstream](https://github.com/orgs/fullsend-ai/projects/1) GitHub project. Each section below defines a workstream category used to classify issues in [fullsend-ai/fullsend](https://github.com/fullsend-ai/fullsend).

These descriptions serve two purposes:

1. **For humans** — clarify scope and boundaries so team members place issues in the right column.
2. **For the classification agent** — provide enough semantic detail to classify an issue into one of these categories when it clearly fits, or leave it unclassified when it does not. Labels are unreliable signals — always read the issue content to understand the nature of the work.

Categories are listed in the priority order established at the July 1 planning session and the [July 2026 roadmap refresh](https://github.com/fullsend-ai/fullsend/pull/2850). The ordering reflects team dot-voting decisions — it does not affect classification. An issue belongs in whichever category matches the nature of the work, regardless of where that category sits in this list.

The valid category names are exactly the nine `##` headings below (without the leading number). No other values are valid.

### Default is unclassified

**If an issue does not obviously belong in one of these categories, it stays unclassified (`null`).** These nine categories do not cover every possible type of work in the fullsend backlog. Many issues are exploratory, cross-cutting, or simply don't fit cleanly. That is expected and acceptable. A wrong classification is worse than no classification — it misleads the team about what work exists in a workstream and pollutes the board. When in doubt, leave it out.

### Classification decision guide

When classifying an issue, read the full issue content (title, body, and comments) and ask yourself: **what is the nature of this work?** Consider all of the following questions — assign a category only when one is a clear and obvious fit:

1. **Is this about how teams adopt, set up, configure, or extend fullsend?** Work that changes the platform surface admins and teams interact with — custom agent interface, agent catalog, harness triggers, configuration knobs, shareable config profiles, skills architecture, agent registration, selective enablement, or authorization → **BYOA**.

2. **Is this about platform infrastructure, runtime plumbing, technical debt, version management, or forge portability?** Work on install consolidation, per-org deprecation, version pinning, automatic upgrades, OpenShell integration, running outside GitHub Actions, GitLab support, OpenCode alignment, sandbox improvements, or dispatch infrastructure → **Infrastructure**.

3. **Is this about understanding what agents cost, how they perform, or where they silently fail?** Work on cost measurement, token tracking, telemetry, tracing, observability tooling, surfacing hidden agent failures, or error visibility → **Observability**.

4. **Is this about proving agents work correctly or measuring their quality?** Work that measures, tests, evaluates, or constrains agent behavior — behavioral tests, functional tests, evaluation frameworks, staging environments, stage tests, e2e infrastructure, trustworthiness evidence, or statistical significance for evals → **Testing**.

5. **Is this about making fullsend visible, understandable, or usable by external teams?** Work on documentation improvements, docs site, community building, user onboarding experience, partnership engagement (OpenShell, Ansible, TektonCD, etc.), or contributor growth → **External Partnerships**.

6. **Is this specifically about JIRA integration and JIRA-driven agent workflows?** Work on JIRA trigger models, per-agent JIRA support, mint for JIRA, JIRA identity management, or JIRA-specific credential plumbing → **JIRA**.

7. **Is this about the token mint service itself?** Work on mint extraction, mint testing, public mint deployment, mint infrastructure migration, mint credential management, or mint operational tooling → **mint**.

8. **Is this about giving agents access to external data sources?** Work on data connectors (JIRA data, GitLab data, Slack, Google Drive), multi-repo context loading, agent environment planning for external access, network policies for data access, or permission models for cross-boundary data → **Agent Data Access**.

9. **Is this exploratory work not yet committed to a delivery timeline?** Work on persistent agent memory systems, auto-merge readiness criteria, or other forward-looking capabilities the team is actively thinking about but not building → **Exploration**.

10. **If no category is an obvious fit, leave unclassified** (`null`). Do not force an issue into a category because it vaguely relates — the issue must clearly belong there. A `null` classification is a correct classification when the issue doesn't fit.

### Important: labels are not categories

An issue labeled `agent/code` might belong in any category depending on the content:
- "Code agent should receive triage output as context" → **Infrastructure** (changes runtime behavior)
- "Allow orgs to disable the code agent" → **BYOA** (changes how teams configure the platform)
- "Add behavioral test for code agent post-script" → **Testing** (tests the code agent)
- "Code agent cost per run exceeds budget" → **Observability** (cost tracking)
- "Code agent JIRA integration" → **JIRA** (JIRA-specific workflow)

Always classify by the **nature of the work**, not the component it touches.

---

## 1. BYOA

Making fullsend a platform teams can adopt incrementally and extend freely. This is the team's highest priority for July.

**Scope:** Everything about the platform surface that org admins and teams interact with when adopting, setting up, configuring, extending, or customizing fullsend.

**What belongs here:**

- **Bring Your Own Agent** — the custom agent interface and harness definition architecture that lets teams create, configure, and deploy their own agents. Re-platforming default agents as harness-driven configs so custom agents get the same treatment. Making it straightforward for external teams to replatform existing agents onto fullsend without a rewrite.
- **Agent catalog** — a repository for discovering, registering, and sharing agent definitions. Default agents promoted alongside community-contributed agents. Shareable config profiles that let teams preconfigure a deployment with a single URL.
- **Harness triggers and dynamic dispatching** — configuring how and when agents are triggered, beyond the current label/event state machine.
- **Configuration knobs** — making agents more adaptable to user preferences. Bot names, auto-triage settings, configurable model fields, severity thresholds, and other settings teams have been requesting.
- **Scribe agent enhancements** — multiple user-requested improvements, migration to the agents repo as part of the re-platforming effort.
- **RFE-creator** — automating feature request creation workflows.
- **Gradual adoption** — enabling teams to onboard with only the agents they want without committing to the full workflow. Selective agent enablement per org or repo.
- **Authorization model** — rules that prevent non-maintainers from triggering agent workloads without team approval. Per-user and per-repo rate limiting.
- **Installer CLI and admin web UI** — the Go CLI commands, the browser-based admin SPA, and the overall onboarding user experience.
- **Harness and skills architecture** — the schema, inheritance, and loading mechanisms that define how agents receive configuration. Skills loading policy. Third-party skill libraries.

**Distinguishing from Infrastructure:** The dividing line is *who interacts with the change*. If the change affects what an admin or team does during setup, configuration, or extension → here. If the change affects platform plumbing, runtime infrastructure, or technical debt → Infrastructure.

**What does NOT belong here:**

- Platform infrastructure and technical debt → [Infrastructure](#2-infrastructure)
- Test infrastructure or evaluation frameworks → [Testing](#4-testing)
- Documentation and community engagement → [External Partnerships](#5-external-partnerships)
- JIRA-specific workflows → [JIRA](#6-jira)

---

## 2. Infrastructure

Platform infrastructure, technical debt reduction, runtime improvements, version management, and forge portability.

**Scope:** Everything about the platform plumbing that keeps fullsend running, upgradable, and portable across forges. This consolidates what was previously split across "Agent Capabilities & Runtime", "Upgrades & Versioning", and "New Forges" in the June plan.

**What belongs here:**

- **Install consolidation** — deprecating per-org installs, unifying install paths, reducing technical debt in the install flow.
- **Version pinning and automatic upgrades** — pinning workflows and agents to specific versions, Renovate automation, schema versioning, upgrade paths for enrolled repos.
- **OpenShell improvements** — Go SDK migration (replacing CLI-based operations), API extensibility, Vertex API authorization fixes, sandbox startup improvements.
- **Running outside GitHub Actions** — enabling agents to run on Tekton, other CI infrastructure, or standalone runtimes to address GitHub Actions resource limits.
- **GitLab support** — webhook bridge, GitLab CI as trigger/coordination/compute layer, forge interface abstraction. Related: [gitlab-implementation](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/gitlab-implementation.md).
- **Forge-portable harness schema** — making harness definitions work across forges.
- **OpenCode alignment** — aligning with the global engineering working group on OpenCode as an alternative agent runtime.
- **Dispatch infrastructure** — concurrency groups, deduplication, dispatch plumbing, retry logic, race condition fixes.
- **Staging migration** — migrating users from dev to the staging product (end of July deadline).
- **Standalone local runtime** — running agents locally, standalone dev mint server, self-hosted support.

**Distinguishing from BYOA:** If the issue changes *platform plumbing or runtime infrastructure* → here. If the issue changes *how teams configure, adopt, or extend* the platform → BYOA.

**What does NOT belong here:**

- Agent configuration and adoption → [BYOA](#1-byoa)
- Cost measurement and telemetry → [Observability](#3-observability)
- Test infrastructure → [Testing](#4-testing)
- Mint-specific work → [mint](#7-mint)

---

## 3. Observability

Understanding what agents cost, how they perform, and where they silently fail.

**Scope:** Cost measurement, telemetry, tracing, error visibility, and operational insight into agent behavior. This is a new category for July — elevated because users are increasingly asking for visibility.

**What belongs here:**

- **Cost measurement and aggregation** — per-repo and per-agent token usage and cost tracking. Budget caps.
- **Telemetry phase 2 & 3** — OpenTelemetry Go SDK integration, trace export, trace chain integrity, retention policies.
- **Hidden agent failures** — surfacing information from failed runs so retries don't repeat the same mistakes. Improving error reporting so humans can see what went wrong.
- **Agent error visibility** — handling silent failures, `is_error:true` responses, OIDC token staleness.
- **Release summary and changelog** — automated visibility into what shipped and when.
- **Operational metrics** — monitoring, structured logging, Langfuse evaluation.

**Distinguishing from Testing:** If the work is about *seeing what agents are doing in production* → here. If it's about *proving agents behave correctly before shipping* → Testing.

**What does NOT belong here:**

- Evaluation frameworks and test suites → [Testing](#4-testing)
- Agent behavior changes → [Infrastructure](#2-infrastructure)
- Platform configuration → [BYOA](#1-byoa)

---

## 4. Testing

How we gain confidence in what we ship. Covers the infrastructure and processes for validating, measuring, and hardening agent behavior — distinct from the agent behavior changes themselves.

**Scope:** Behavioral tests, functional tests, evaluation frameworks, staging environments, stage tests, e2e infrastructure, trustworthiness evidence, and the developer tooling that keeps the fullsend codebase healthy.

**What belongs here:**

- **Behavior tests for deterministic code** — test suites that validate deterministic code paths without running LLMs.
- **Functional tests for all default agents** — comprehensive test coverage using dummy runtimes, local sandbox, and behavioral assertions.
- **Evaluation frameworks** — SWE-bench pilots, Harbor for code-agent outcome eval, RAGAS-based assessments, statistical significance layers for non-deterministic evals.
- **Stage tests** — post-merge testing in a staging environment that mirrors real user deployments. Addresses the gap between how e2e tests work and how users actually use fullsend.
- **E2e test improvements** — bot authorization fixes, auth alignment, test flakiness reduction.
- **Trustworthiness evidence** — rework rate tracking, review outcome analysis, qualitative feedback collection. Data that informs future auto-merge decisions.
- **Security hardening** — penetration testing, credential isolation, prompt injection defense, secret redaction, supply chain hardening.
- **Fullsend repo developer tooling** — pre-commit hooks, lint rules, type checking, CI fixes, ADR collision checks.

**Distinguishing from Observability:** If the work *measures or tests agent behavior before shipping* → here. If it's about *seeing what agents do in production* → Observability.

**What does NOT belong here:**

- Production monitoring and telemetry → [Observability](#3-observability)
- Agent behavior changes → [Infrastructure](#2-infrastructure)
- User-facing documentation → [External Partnerships](#5-external-partnerships)

---

## 5. External Partnerships

Making fullsend visible, understandable, and usable by teams outside the core group.

**Scope:** Documentation improvements, community engagement, partnership management, and user experience for teams adopting fullsend. This combines what was previously "Docs & Public Alignment" with active partnership tracking.

**What belongs here:**

- **Partnership engagement** — OpenShell, Ansible, TektonCD, and other teams using or evaluating fullsend. Supporting their adoption, tracking blockers, and ensuring they succeed.
- **Community building** — experimenting with engagement patterns. Fullsend SIGs for incorporating additional engineering support. User forum engagement.
- **Documentation improvements** — practical guides, getting-started simplification, docs site content, public mint documentation. Direct response to user feedback about docs quality.
- **User experience observation** — screen-share sessions with users to observe how they interpret documentation and onboarding flows.
- **ADRs and architecture docs** — maintaining the decision record, architecture documentation updates.
- **Branding and discoverability** — docs site navigation, product landing pages, README improvements.

**Distinguishing from BYOA:** If the work changes *the platform itself* → BYOA. If the work helps *people understand, find, or start using* the platform → here.

**What does NOT belong here:**

- Platform configuration changes → [BYOA](#1-byoa)
- Agent behavior changes → [Infrastructure](#2-infrastructure)
- JIRA integration → [JIRA](#6-jira)

---

## 6. JIRA

Connecting fullsend to JIRA — extending the trigger model beyond forge events into project management.

**Scope:** JIRA-specific agent workflows, JIRA trigger models, per-agent JIRA support, and JIRA credential management. This is the JIRA-workflow-focused counterpart to the broader Agent Data Access category.

**What belongs here:**

- **JIRA support for all default agents** — extending triage, code, review, fix, retro, and refine agents to work with JIRA data and workflows.
- **JIRA trigger model** — agents picking up JIRA stories, refining acceptance criteria, and linking implementation back to JIRA tracking.
- **Mint for JIRA** — Workload Identity Federation for JIRA service accounts. Starting with public JIRA projects to avoid private data exposure.
- **Feature refinement agents** — agents that participate in feature definition through JIRA, producing feature definitions autonomously with confidence-driven presentation.
- **Meeting notes as context** — using meeting notes and transcripts as input for JIRA-connected refinement workflows.

**Distinguishing from Agent Data Access:** If the issue is specifically about *JIRA workflows, JIRA triggers, or JIRA credential management* → here. If it's about *generic data access patterns* that happen to include JIRA as one of several data sources → Agent Data Access.

**What does NOT belong here:**

- Generic data connector patterns → [Agent Data Access](#8-agent-data-access)
- General agent behavior improvements → [Infrastructure](#2-infrastructure)
- Mint infrastructure (not JIRA-specific) → [mint](#7-mint)

---

## 7. mint

Extracting, hardening, and operationalizing the token mint as a standalone service.

**Scope:** Work specific to the mint service itself — its extraction from the fullsend monorepo, testing, deployment, and operational tooling.

**What belongs here:**

- **mint tests in e2e** — adding mint-specific coverage to the end-to-end test suite.
- **Finish public mint work** — implementing ADR 0059 public mint mode.
- **Extract mint to its own repository** — simplifying the fullsend codebase by separating the mint into a standalone Go module/repo.
- **Move mint to prod GCP project** — separating mint infrastructure from dev/inference projects for better isolation and operational clarity.
- **Mint operational tooling** — `mint delete` for teardown, deployment suggestions, health checks, token caching.
- **Mint identity and permissions** — consolidating role lists, evaluating database-backed persistence, permission adjustments.
- **Service decomposition** — criteria for splitting mint into multiple instances.

**Distinguishing from JIRA:** If the mint work is specifically *for JIRA credential management* → JIRA. If it's about *the mint service itself* regardless of what uses it → here.

**Distinguishing from Infrastructure:** The mint has enough dedicated scope and team attention to warrant its own category. Generic infrastructure work that happens to touch mint code belongs here only if the mint is the primary subject.

**What does NOT belong here:**

- JIRA-specific mint work → [JIRA](#6-jira)
- General platform infrastructure → [Infrastructure](#2-infrastructure)
- Secretless deployment patterns (broader than mint) → [BYOA](#1-byoa)

---

## 8. Agent Data Access

Giving agents access to data beyond the repository — securely and systematically.

**Scope:** Data connectors, multi-repo context, external data source integration, and the credential/policy infrastructure required to enable them.

**What belongs here:**

- **Data connectors** — skills and credential plumbing for accessing JIRA data, GitLab repositories, Slack, Google Drive, and other external sources.
- **Multi-repo context** — loading context from multiple repositories to improve agent output quality. Cross-repo changes and issue creation.
- **Agent environment planning** — designing how agents discover and access external data, including context-aware loading and skill selection.
- **Credential and policy infrastructure** — service accounts, network policies, permission models, and security boundaries for cross-system data access. This goes beyond simple API keys — it includes workload identity, minting patterns, and policy opening.
- **Least-privilege data access** — human-gated permission adjustments, authorization gates for data access beyond the repository.

**Distinguishing from JIRA:** If the work is about *a generic data access pattern* or *multiple data sources* → here. If it's specifically about *JIRA workflows and JIRA triggers* → JIRA.

**Distinguishing from BYOA:** If the work is about *how agents get data from external sources* → here. If it's about *how teams configure which agents run* → BYOA.

**What does NOT belong here:**

- JIRA-specific workflows → [JIRA](#6-jira)
- Platform configuration → [BYOA](#1-byoa)
- Mint service changes → [mint](#7-mint)

---

## 9. Exploration

Ideas the team is actively thinking about but not yet committed to building.

**Scope:** Forward-looking capabilities that received no votes in the July planning session. These are tracked to maintain visibility and will be re-evaluated in future planning cycles.

**What belongs here:**

- **Persistent agent memories** — agents retaining context and history across sessions. Must be traceable and transparent to humans — hidden memory is rejected. Security concerns around persistent threats through memory injection need resolution.
- **Auto-merge (tiny percentage)** — reasoning about where auto-merge is safe, starting with a very small scope where trustworthiness evidence supports it. Defining thresholds and criteria.
- Other exploratory ideas that don't fit active categories but the team wants to track.

**Important:** Exploration is not a dumping ground. Issues that fit another category should go there, even if the work is speculative. Exploration is for ideas that are genuinely new territory without a clear home.

**What does NOT belong here:**

- Speculative work within an active category → the relevant active category
- Research that informs an active workstream → the relevant active category

---

### Routing guidance for cross-cutting concerns

### Research & landscape evaluation

Research issues don't form a separate workstream. Classify them by what they inform:

- Research that directly informs a security hardening effort → Testing
- Research that evaluates an alternative agent runtime or tool → Infrastructure
- Research that is primarily a landscape survey or literature review → External Partnerships
- Research that informs a new agent type → BYOA
- Research about cost modeling or usage patterns → Observability
- If the research doesn't clearly and obviously inform any active workstream → leave unclassified. Most research issues should be unclassified.

### Chores and housekeeping

`type/chore` issues don't form a separate workstream. Classify them by the nature of the work:

- A chore that cleans up install/config code → BYOA
- A chore that fixes dispatch or runtime plumbing → Infrastructure
- A chore that improves CI pipelines, lint rules, or pre-commit hooks → Testing
- A chore that updates documentation → External Partnerships
- A chore that affects mint infrastructure → mint
- A chore that affects telemetry or cost tracking → Observability
- If the chore doesn't clearly belong to one of the above → leave unclassified

---

**Remember:** These nine categories are not exhaustive. Many valid issues in the fullsend backlog will not fit any of them. Unclassified is the correct answer whenever the fit is not obvious.
