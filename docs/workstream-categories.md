# Workstream Categories

Reference document for the [Fullsend-ai Workstream](https://github.com/orgs/fullsend-ai/projects/1) GitHub project. Each section below defines a workstream category used to classify issues in [fullsend-ai/fullsend](https://github.com/fullsend-ai/fullsend).

These descriptions serve two purposes:

1. **For humans** — clarify scope and boundaries so team members place issues in the right column.
2. **For the classification agent** — provide enough semantic detail to classify an issue into one of these categories when it clearly fits, or leave it unclassified when it does not. Labels are unreliable signals — always read the issue content to understand the nature of the work.

Categories are listed in the order established at the June 10 planning session and the [June 2026 roadmap refresh](https://github.com/fullsend-ai/fullsend/pull/1993). The ordering reflects team planning decisions — it does not affect classification. An issue belongs in whichever category matches the nature of the work, regardless of where that category sits in this list.

The valid category names are exactly the seven `##` headings below (without the leading number). No other values are valid.

### Default is unclassified

**If an issue does not obviously belong in one of these categories, it stays unclassified (`null`).** These seven categories do not cover every possible type of work in the fullsend backlog. Many issues are exploratory, cross-cutting, or simply don't fit cleanly. That is expected and acceptable. A wrong classification is worse than no classification — it misleads the team about what work exists in a workstream and pollutes the board. When in doubt, leave it out.

### Classification decision guide

When classifying an issue, read the full issue content (title, body, and comments) and ask yourself: **what is the nature of this work?** Consider all of the following questions — assign a category only when one is a clear and obvious fit:

1. **Is this about how teams adopt, set up, configure, or extend fullsend?** Work that changes the platform surface admins and teams interact with — installation, onboarding, authorization, harness architecture, per-repo deployment, selective agent enablement, or building custom agents → **BYOA & Customizability**.

2. **Is this about what agents do when they run, or the runtime they execute in?** Work that changes agent behavior during execution — how they triage, code, review, fix, or produce output — or changes the sandbox, dispatch, orchestration, or runtime infrastructure → **Agent Capabilities & Runtime**.

3. **Is this about proving agents work correctly, measuring their quality, or improving the fullsend developer experience?** Work that measures, tests, evaluates, or constrains agent behavior — eval frameworks, behavioral tests, staging environments, security hardening, CI infrastructure, or repo developer tooling → **Testing, Staging Infra & Evals**.

4. **Is this about version management, pinning, or upgrade mechanisms?** Work that controls how fullsend versions, pins, distributes, or upgrades its artifacts — workflows, agents, schemas, or the CLI binary → **Upgrades & Versioning**.

5. **Is this about making fullsend understandable, discoverable, or publicly visible?** Work on documentation content, docs delivery systems, community engagement, team growth models, or external partnerships → **Docs & Public Alignment**.

6. **Is this about supporting non-GitHub forges?** Work that extends fullsend to GitLab, Tekton, Forgejo, or abstracts the forge layer for portability → **New Forges**.

7. **Is this about connecting fullsend to project management or feature refinement?** Work that integrates with Jira, enables feature refinement workflows, or extends the trigger model beyond forge events → **Jira Integration & Refinement**.

8. **If no category is an obvious fit, leave unclassified** (`null`). Do not force an issue into a category because it vaguely relates — the issue must clearly belong there. A `null` classification is a correct classification when the issue doesn't fit.

### Important: labels are not categories

An issue labeled `agent/code` might belong in any category depending on the content:
- "Code agent should receive triage output as context" → **Agent Capabilities & Runtime** (changes what the code agent does)
- "Allow orgs to disable the code agent" → **BYOA & Customizability** (changes how teams configure the platform)
- "Add behavioral test for code agent post-script" → **Testing, Staging Infra & Evals** (tests the code agent)
- "Code agent should pin its workflow to the installed version" → **Upgrades & Versioning** (changes versioning behavior)

Always classify by the **nature of the work**, not the component it touches.

---

## 1. BYOA & Customizability

Making fullsend a platform teams can adopt incrementally and extend freely.

**Scope:** Everything about the platform surface that org admins and teams interact with when adopting, setting up, configuring, extending, or customizing fullsend.

**What belongs here:**

- **Bring Your Own Agent** — the custom agent interface and harness definition architecture that lets teams create, configure, and deploy their own agents. Re-platforming default agents as harness-driven configs so custom agents get the same treatment. Making it straightforward for external teams to replatform existing agents onto fullsend without a rewrite.
- **Gradual adoption** — enabling teams to onboard with only the agents they want (e.g., triage only) without committing to the full workflow. Selective agent enablement per org or repo. Reducing the infrastructure requirements for getting started (e.g., eliminating GCP project barriers).
- **Authorization model** — rules that prevent non-maintainers from triggering agent workloads without team approval. Per-user and per-repo rate limiting. Access control for slash commands.
- **Installer CLI and admin web UI** — the Go CLI (`cmd/fullsend/`) commands (install, uninstall, enroll, unenroll, sync, analyze), the browser-based admin SPA, and the overall onboarding user experience. Enrollment workflows, shim deployment, config repo setup.
- **Harness and skills architecture** — the schema, inheritance, and loading mechanisms that define how agents receive configuration. Protected vs. overridable fields. Skills loading policy (explicit list vs. org+repo union). Third-party skill libraries. Per-repo config overrides.
- **Secretless deployment** — Workload Identity Federation, public and private mint infrastructure, credential management strategies that reduce onboarding friction. Standalone dev mint servers that remove GCP dependencies.
- **Configuration and customization** — bot names, auto-triage settings, configurable model fields, and other settings that teams have been requesting to tailor the platform to their workflows.

**Distinguishing from Agent Capabilities & Runtime:** The dividing line is *who interacts with the change*. If the change affects what an admin or team does during setup, configuration, or extension → here. If the change affects what the agent does during a run (how it triages, codes, reviews, or produces output) → Agent Capabilities & Runtime. An issue about "allow orgs to disable auto-triggered review" is about configuration → here. An issue about "review agent should check CI status before approving" is about agent behavior → Agent Capabilities & Runtime.

**What does NOT belong here:**

- Changes to agent behavior during execution → [Agent Capabilities & Runtime](#2-agent-capabilities--runtime)
- Test infrastructure or evaluation frameworks → [Testing, Staging Infra & Evals](#3-testing-staging-infra--evals)
- Version pinning and upgrade mechanisms → [Upgrades & Versioning](#4-upgrades--versioning)
- GitLab/Tekton forge support → [New Forges](#6-new-forges)

---

## 2. Agent Capabilities & Runtime

Improving what agents can do and the runtime they operate in.

**Scope:** Everything about agent behavior during execution, the runtime environment agents run in, and the dispatch/orchestration infrastructure that connects triggers to agent runs.

**What belongs here:**

- **Agent behavior changes** — any issue that changes how an existing agent (triage, code, review, fix, retro, scribe, prioritize) behaves when it runs. This includes both bug fixes (agent does something wrong) and enhancements (agent should do something new or better). Examples: improving duplicate detection in triage, adding regression tests to code agent output, stabilizing review verdicts across iterations, teaching the fix agent to address all findings, having the retro agent search for related issues before proposing changes.
- **New agent types** — wholly new agents that don't exist yet: DevOps agent for CI failures, backlog ranker, strategic advisor, external research tracker, user feedback tracker.
- **Multi-repo workflows** — issues spanning multiple repositories. Cross-repo context loading, cross-repo issue creation, flagging cross-repo workflow chains.
- **Better context for agents** — providing more information before coding, making agents aware of repo contents, skills, related issues, and existing PRs. Context that helps agents produce better output.
- **Runtime enhancements** — OpenShell integration (new capabilities, credential delivery, skill bridging), OpenCode as an alternative runtime, sandbox improvements (startup time, dev environment discovery, file handling, toolchain issues), and the standalone local runtime for offline/local execution.
- **Dispatch and orchestration** — dispatch plumbing, concurrency groups, deduplication, multi-agent pipelines (code→review→code loops), circuit breakers, retry logic, and the label/event state machine that triggers agent runs. Fixing race conditions, silent failures, and duplicate dispatches.
- **Agent output quality** — pre/post-script behavior that affects what users see (PR descriptions, review comments, status updates, error notifications). Schema enforcement for agent output.
- **OpenShell using fullsend** — partnership with the OpenShell team to use fullsend for their own agentic SDLC process.

**Distinguishing from BYOA & Customizability:** If the issue changes *what the agent does during a run* → here. If the issue changes *how teams configure, adopt, or extend* the platform → BYOA & Customizability.

**Distinguishing from Testing, Staging Infra & Evals:** If the issue is about the agent *doing something differently* → here. If the issue is about *measuring or testing whether agents behave correctly* → Testing, Staging Infra & Evals. "Improve review agent detection of shell script bugs" = here. "Add behavioral test suite for review post-scripts" = Testing.

**What does NOT belong here:**

- Platform adoption and extension mechanisms → [BYOA & Customizability](#1-byoa--customizability)
- Evaluation frameworks and test infrastructure → [Testing, Staging Infra & Evals](#3-testing-staging-infra--evals)
- Version pinning and upgrade tooling → [Upgrades & Versioning](#4-upgrades--versioning)
- Feature refinement and Jira integration → [Jira Integration & Refinement](#7-jira-integration--refinement)

---

## 3. Testing, Staging Infra & Evals

How we gain confidence in what we ship. This covers the infrastructure and processes for validating, measuring, and hardening agent behavior — distinct from the agent behavior changes themselves.

**Scope:** Evaluation frameworks, behavioral tests, dedicated staging environments, CI test infrastructure, security hardening, measurement and insights, prompt/eval versioning, trustworthiness evidence, and the developer tooling that keeps the fullsend codebase itself healthy.

**What belongs here:**

- **Evaluation frameworks** — benchmarks, metrics, and eval harnesses that measure agent output quality. SWE-bench or custom benchmarks for the code agent. RAGAS-based knowledge assessment. Evolutionary algorithm optimization of agent configs. Quality metrics for the autonomous software factory. Agent drift detection with measurable thresholds.
- **Behavioral and functional tests** — test suites that validate deterministic code paths without running LLMs. Functional tests using local sandbox. Behavioral test coverage for pre/post scripts. Tests with dummy runtimes. Dispatch smoke tests. Static analysis layers.
- **Staging and CI infrastructure** — dedicated staging environments for testing changes before production. E2E test frameworks, browser-based test suites, session refresh automation, test flakiness reduction, configurable test orgs.
- **Security hardening** — policies, penetration testing, credential isolation, attack surface reduction. Prompt injection defense, reasoning monitors, emergency halt mechanisms, secret redaction bypasses, supply chain hardening, SSRF defenses, workflow security scanning, output pipeline sanitization.
- **Trustworthiness evidence** — accumulating data to inform future auto-merge decisions. Rework rate tracking, review outcome analysis (accepted vs. discarded), qualitative feedback collection from pilot teams. Gating decisions about ready-for-merge labels. Evidence that agents behave correctly and produce trustworthy output.
- **Fullsend repo developer tooling** — chores and CI fixes that affect contributors to the fullsend codebase itself (not users). Pre-commit hooks, lint rules, type checking, gofmt checks, shadow analyzers, ADR collision checks, frontmatter validation, `__pycache__` cleanup, GCP model enablement. Migrating pre-scripts from bash to Python for testability.
- **Operational observability and metrics** — monitoring, tracing, cost measurement. Langfuse vs structured logging decisions. Trace granularity and retention. Token usage and cost tracking. SDLC measurement integration. Weekly activity summaries, auto-labeling PRs, changelog generation.
- **Prompt and eval versioning** — tracking how prompt changes affect agent output quality. Versioning of evaluation configurations and baselines.

**Distinguishing from Agent Capabilities & Runtime:** If the work *changes what agents do* → Agent Capabilities. If it *measures, tests, or constrains agent behavior* without changing the agent itself → here. "Sandbox startup takes 90 seconds" = Agent Capabilities (runtime improvement). "Penetration testing the sandbox" = here. "Review agent should flag shell script bugs" = Agent Capabilities. "Benchmark review agent finding accuracy" = here.

**What does NOT belong here:**

- Agent behavior changes → [Agent Capabilities & Runtime](#2-agent-capabilities--runtime)
- Install/onboarding flow → [BYOA & Customizability](#1-byoa--customizability)
- User-facing documentation → [Docs & Public Alignment](#5-docs--public-alignment)

---

## 4. Upgrades & Versioning

Version management, dependency pinning, automatic upgrades, and release tooling.

**Scope:** How fullsend versions, pins, upgrades, and distributes its artifacts — workflows, agents, harness definitions, the CLI binary, and dependencies.

**What belongs here:**

- **Workflow and agent versioning** — pinning workflows and agents to specific versions at install time. Preventing drift between what's installed and what's released. Schema versioning for harness definition files. Config schema validation and versioned migration. Plugin repository approaches for independent agent versioning.
- **Automatic upgrades** — managing version upgrades for all onboarded organizations. Renovate automation for dependency pins. Go version pin alignment. npm dedup. Sync-scaffold upgrade paths. Keeping enrolled repos current with new releases.
- **Version pinning for users** — ensuring users can pin to a known-good version and upgrade intentionally. Enrollment checks that compare content not just existence. Closing stale onboard PRs when shims are already current.
- **Release tooling** — release creation, changelogs, distribution, title formatting, tag management. Build-from-source fallbacks when no published release exists.

**Distinguishing from BYOA & Customizability:** If the issue is about *how a version is managed, pinned, or upgraded* → here. If the issue is about *how teams install or configure fullsend* (even if version selection is involved) → BYOA & Customizability. "Pin workflows to the version being installed" = here. "Simplify the install command" = BYOA.

**What does NOT belong here:**

- Per-repo deployment (adoption mechanism) → [BYOA & Customizability](#1-byoa--customizability)
- Agent runtime changes → [Agent Capabilities & Runtime](#2-agent-capabilities--runtime)
- CI infrastructure → [Testing, Staging Infra & Evals](#3-testing-staging-infra--evals)

---

## 5. Docs & Public Alignment

Making fullsend understandable, discoverable, and navigable.

**Scope:** Documentation content, delivery systems, community engagement patterns, team growth models, and external partnerships that make fullsend visible and understandable.

**What belongs here:**

- **User-facing guides and documentation** — practical docs for administrators and developers. Installation guides, bugfix workflow docs, power-user config guides, agent definition development guides. README improvements. AGENTS.md and CLAUDE.md maintenance.
- **Discoverability and docs site** — making docs findable, not just writable. Docs site with embedded navigation, markdown image rendering, product landing pages. `@ship-help` LLM-powered help bot using docs as knowledge base.
- **ADRs and architecture documentation** — maintaining the decision record. Architecture doc updates. ADR filing and status tracking.
- **Community engagement and team growth** — how fullsend scales beyond the core team. Fullsend SIGs (team growth model) for incorporating additional engineering support. Experimenting with different human-to-human patterns for contributor engagement. Agentic generation of demos within guides. Branding guidelines. GitHub issue templates.
- **Problem documents** — the exploratory docs in `docs/problems/` covering intent, security, architecture, governance, and other design concerns.

**Distinguishing from other categories:** Documentation changes that are *about* another category's work should go in that category if the doc change is incidental to the main work (e.g., updating a guide as part of a feature implementation). Standalone documentation efforts — improving discoverability, writing new guides, maintaining the docs site — belong here.

**What does NOT belong here:**

- Admin web UI development → [BYOA & Customizability](#1-byoa--customizability)
- Inline code documentation → belongs with the code change itself
- ADR proposals that are primarily technical decisions → the category of the technical area

---

## 6. New Forges

Extending fullsend beyond GitHub to other forge platforms.

The [forge abstraction layer](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0005-forge-abstraction-layer.md) (ADR 0005) and the [forge-portable harness schema](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0045-forge-portable-harness-schema.md) (ADR 0045) provide the architectural foundation.

**Scope:** Making fullsend work on non-GitHub forges — GitLab, Tekton, Forgejo — and abstracting the forge layer for cross-platform portability.

**What belongs here:**

- **GitLab support** — webhook bridge implementation, GitLab CI as trigger/coordination/compute layer, `forge.Client` implementation, cross-forge identity challenges, MR-event security models. Related: [gitlab-implementation](https://github.com/fullsend-ai/fullsend/blob/main/docs/problems/gitlab-implementation.md).
- **Forge-portable harness schema** — making harness definitions work across forges. Schema changes that abstract away GitHub-specific assumptions.
- **Tekton / Kubernetes** — pipeline-based execution, OpenShift Pipelines support, running fullsend on Kubernetes as a compute substrate.
- **Cross-forge orchestration** — coordinating agent work across multiple forges when a single logical change spans organizational boundaries.
- **Forgejo** — community forge alternative support.

**Distinguishing from BYOA & Customizability:** If the issue is about making fullsend work on *a non-GitHub forge* → here. If the forge-portable schema work is primarily about *harness architecture* that benefits GitHub users too → BYOA & Customizability.

**What does NOT belong here:**

- GitHub-specific feature depth → [BYOA & Customizability](#1-byoa--customizability) or [Agent Capabilities & Runtime](#2-agent-capabilities--runtime)
- Agent capabilities → [Agent Capabilities & Runtime](#2-agent-capabilities--runtime)

---

## 7. Jira Integration & Refinement

Connecting fullsend to project management systems and extending the SDLC footprint beyond bug triage and code production into feature work.

**Scope:** Feature refinement workflows, Jira integration, and extending the trigger model beyond forge events into project management systems.

**What belongs here:**

- **Feature refinement agents** — agents that participate in feature definition, not just bugfixes. Producing feature definitions autonomously. Confidence-driven presentation. "Definition of Ready" templates. Re-running refinement with user-provided answers. Work-in-progress limits.
- **Jira integration** — connecting fullsend workflows to Jira. Mint for Jira (workload identity federation for Jira service accounts). Starting with public Jira projects to avoid private data exposure. Engaging community members already building Jira integration.
- **Downstream-upstream linking** — connecting feature specs to implementable units. Intent representation. Definition of done modeling. Linking implementation back to project tracking.
- **JIRA-driven agent workflows** — agents picking up Jira stories, refining acceptance criteria, and linking implementation back to tracking. Extending fullsend's trigger model beyond forge events.
- **Meeting notes as context** — using meeting notes and transcripts as input for refinement workflows.

**Distinguishing from Agent Capabilities & Runtime:** If the issue is about an agent's *general behavior* during a standard triage/code/review run → Agent Capabilities & Runtime. If the issue is specifically about *feature refinement workflows* or *Jira integration* → here. An issue about `/fs-refine` slash commands belongs here. An issue about `/fs-code` slash commands belongs in Agent Capabilities.

**What does NOT belong here:**

- General agent behavior improvements → [Agent Capabilities & Runtime](#2-agent-capabilities--runtime)
- GitHub-only workflow improvements → [Agent Capabilities & Runtime](#2-agent-capabilities--runtime)
- Forge abstraction layer → [New Forges](#6-new-forges)

---

### Routing guidance for cross-cutting concerns

### Research & landscape evaluation

Research issues don't form a separate workstream. Classify them by what they inform:

- Research that directly informs a security hardening effort → Testing, Staging Infra & Evals
- Research that evaluates an alternative agent runtime or tool → Agent Capabilities & Runtime
- Research that is primarily a landscape survey or literature review → Docs & Public Alignment
- Research that informs a new agent type → Agent Capabilities & Runtime
- If the research doesn't clearly and obviously inform any active workstream → leave unclassified. Most research issues should be unclassified.

### Chores and housekeeping

`type/chore` issues don't form a separate workstream. Classify them by the nature of the work:

- A chore that cleans up install/config code → BYOA & Customizability
- A chore that fixes agent pre/post-script behavior → Agent Capabilities & Runtime
- A chore that improves CI pipelines, lint rules, or pre-commit hooks → Testing, Staging Infra & Evals
- A chore that aligns dependency versions or fixes release tooling → Upgrades & Versioning
- A chore that updates documentation → Docs & Public Alignment
- If the chore doesn't clearly belong to one of the above → leave unclassified

---

**Remember:** These seven categories are not exhaustive. Many valid issues in the fullsend backlog will not fit any of them. Unclassified is the correct answer whenever the fit is not obvious.
