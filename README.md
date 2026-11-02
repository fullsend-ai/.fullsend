# fullsend-ai/.fullsend

Fleet manifest and org automations for the fullsend-ai organization. This is
not a per-org configuration repository (that mode is deprecated, see
[ADR 0044](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0044-deprecate-per-org-installation-mode.md));
it holds the `repos.yaml` manifest described in
[ADR 0057](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0057-repos-management.md)
and [ADR 0122](https://github.com/fullsend-ai/fullsend/blob/main/docs/ADRs/0122-declarative-repo-configuration.md).

## How fleet configuration is managed

1. **Edit `repos.yaml` in a pull request.** The fleet-wide configuration lives
   in `defaults.config`; a repository entry carries only what differs for that
   repository. `Manifest Check` runs the strict `validate-manifest` job on
   every PR, merge group, and push to `main`. It uses the installer's production
   loader and validator, including validation of merged managed configuration.
   Invalid manifests fail the job; validation does not contact the fleet or
   request the sync App's credentials.
   A separate advisory job reports `repos status` and `repos install --dry-run`
   for internal PRs whose CLI pin is unchanged. Adoption and drift errors in
   that preview remain informational. Privileged previews execute tooling from
   the reviewed base branch, not proposed PR scripts. CLI pin changes require
   a manual Sync Scaffold dry run after merge for a privileged preview.
2. **Merge.** Nothing is pushed to any repository at merge time.
3. **Sync Scaffold applies the manifest** on every fullsend release, weekly,
   and on manual dispatch (dry-run by default). Apply runs push drift fixes
   directly to each listed repository's default branch using the sync App;
   manual dry runs preview the changes without writing. These pushes bypass
   per-repository PR gates, so review the manifest plan before merging.

Repositories not listed in `repos.yaml` are never touched. A listed
repository's `.fullsend/config.yaml` is owned by the manifest: it begins with
the `repos-config-v1` marker and is rewritten on every converge, so change the
manifest, not the file.

Reference: [Repo Management guide](https://github.com/fullsend-ai/fullsend/blob/main/docs/guides/getting-started/repo-management.md),
[`fullsend repos` CLI](https://github.com/fullsend-ai/fullsend/blob/main/docs/cli/repos.md).

## Reviewed CLI revision

`fullsend-cli-revision` pins the full commit SHA used to build both the
validator and the Sync Scaffold installer. Update it in a PR to adopt new
CLI implementation or embedded-template fallback changes. Release
notifications still request a sync using this reviewed CLI revision.

Remote scaffold templates and runtime references follow the manifest's
`github.fullsend_ref`, currently `main`. They can advance without a CLI-pin
update. If a remote GitHub scaffold fetch fails, the installer can fall back
to the embedded templates from the pinned CLI. The CLI pin therefore does
not pin remote scaffold templates or agent runtimes.

`hack/build-fullsend.sh OUTPUT_DIRECTORY` builds both commands and runs the
regression tests. The small validation command is copied into the pinned
Fullsend checkout to call `internal/repos.LoadManifest` and `Manifest.Validate`
directly. It contains no duplicate validation rules. Tests cover the #209
enablement-only failure, the #210 correction, and invalid entries elsewhere
in the manifest. Sync repeats this check before requesting fleet credentials.

## Require the merge check through organization governance

The required check is managed centrally in
[`fullsend-ai/org/repos/.fullsend.yml`](https://github.com/fullsend-ai/org/blob/main/repos/.fullsend.yml),
which owns this repository's existing `main` ruleset. The companion
[org PR #37](https://github.com/fullsend-ai/org/pull/37) adds `validate-manifest`
from GitHub Actions and requires an up-to-date branch while preserving the
existing rules. Do not create a separate manually managed ruleset here.

Merge [the validator PR #211](https://github.com/fullsend-ai/.fullsend/pull/211)
first and confirm `validate-manifest` succeeds on `main`. Then merge the
companion org PR after reviewing its safe-settings dry-run output for
unexpected changes. The normal safe-settings apply activates the rule;
confirm the effective default-branch rules require `validate-manifest` after
that apply succeeds. Merging the validator workflow alone does not make the
check mandatory. The advisory preview is not a required check.

## Other automations in this repository

- `prioritize-scheduler.yml` (disabled), `qualityflow.yml`, `scribe.yml`
  (disabled), `sync-agent-digests.yml`: org-level jobs unrelated to the fleet
  manifest. See `docs/` for the scribe agent and workstream categories.
