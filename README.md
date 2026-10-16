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
   repository. The `Manifest Check` workflow runs `fullsend repos status` and
   `fullsend repos install --dry-run` against the proposed manifest and posts
   both to the job summary. Read them before merging.
2. **Merge.** Nothing is pushed to any repository at merge time.
3. **Sync Scaffold applies the manifest** on every fullsend release, weekly,
   and on manual dispatch (dry-run by default). It opens or updates one pull
   request per drifted repository on the `fullsend/scaffold-install` branch.
   Repository owners merge those on their own schedule.

Repositories not listed in `repos.yaml` are never touched. A listed
repository's `.fullsend/config.yaml` is owned by the manifest: it begins with
the `repos-config-v1` marker and is rewritten on every converge, so change the
manifest, not the file.

Reference: [Repo Management guide](https://github.com/fullsend-ai/fullsend/blob/main/docs/guides/getting-started/repo-management.md),
[`fullsend repos` CLI](https://github.com/fullsend-ai/fullsend/blob/main/docs/cli/repos.md).

## Other automations in this repository

- `prioritize-scheduler.yml` (disabled), `qualityflow.yml`, `scribe.yml`
  (disabled), `sync-agent-digests.yml`: org-level jobs unrelated to the fleet
  manifest. See `docs/` for the scribe agent and workstream categories.
