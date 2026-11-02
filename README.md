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
installer or scaffold-template changes. Release notifications still request a
sync, but they use this reviewed revision rather than building a moving
`main`. The manifest's `github.fullsend_ref` independently controls the
reference embedded in runtime shims; this change does not pin agent runtimes.

`hack/build-fullsend.sh OUTPUT_DIRECTORY` builds both commands and runs the
regression tests. The small validation command is copied into the pinned
Fullsend checkout to call `internal/repos.LoadManifest` and `Manifest.Validate`
directly. It contains no duplicate validation rules. Tests cover the #209
enablement-only failure, the #210 correction, and invalid entries elsewhere
in the manifest. Sync repeats this check before requesting fleet credentials.

## Activate the required merge check

**Merging the workflow does not require the check in GitHub.** A repository
administrator must activate that setting after the first successful
`validate-manifest` run on `main`. Until then, the job can fail while a PR
remains mergeable.

The reviewed policy is in `.github/manifest-validation-ruleset.json`. It adds
a separate active ruleset for the default branch, requires `validate-manifest`
from the GitHub Actions app, requires an up-to-date branch, and grants no
bypasses. It does not replace existing organization or repository rulesets.

An administrator can review and activate it with:

```sh
gh auth status
gh api repos/fullsend-ai/.fullsend/rulesets --jq '.[] | {id, name, source}'
cat .github/manifest-validation-ruleset.json
# Create once, after confirming that a repository-owned rule with this name
# does not already exist. This is a live GitHub administration change.
gh api --method POST repos/fullsend-ai/.fullsend/rulesets \
  --input .github/manifest-validation-ruleset.json
# Read back the effective rules and confirm the required check is present.
gh api repos/fullsend-ai/.fullsend/rules/branches/main
```

If `manifest-validation` already exists, inspect it rather than creating
another copy or overwriting it. Source control reviews the proposed policy;
GitHub's live ruleset supplies enforcement. Require `validate-manifest`, not
the advisory preview job. See the [GitHub rulesets API](https://docs.github.com/en/rest/repos/rules).

## Other automations in this repository

- `prioritize-scheduler.yml` (disabled), `qualityflow.yml`, `scribe.yml`
  (disabled), `sync-agent-digests.yml`: org-level jobs unrelated to the fleet
  manifest. See `docs/` for the scribe agent and workstream categories.
