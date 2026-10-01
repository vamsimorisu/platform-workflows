# platform-workflows

Org-wide reusable CI/CD for Python and Node.js repos: PR contract, PR advisory, lint/test/build, Docker, environment-gated deploy.

## Publish (one time)

```bash
ORG=your-org ./scripts/bootstrap.sh
```

This replaces `__ORG__`, creates an **internal** repo, allows org-wide workflow access, and tags `v1.0.0` (which moves the floating `v1` tag).

Then: create the teams `platform-team` and `security`, set the production reviewer team id in `policy/env-production.json`, and apply `policy/ruleset.json` (starts in `evaluate` mode).

## Use it in a repo

Copy `callers/node.yml` or `callers/python.yml` to `.github/workflows/ci-cd.yml` to run the full pipeline. The templates enable Docker and deploy; set either input to `false` to skip that stage. For CI-only checks, call `ci.yml` directly as shown below, or run `ORG=your-org ./scripts/onboard.sh <repo> <node|python>`.

```yaml
jobs:
  pipeline:
    uses: your-org/platform-workflows/.github/workflows/ci-cd.yml@v1
    with:
      language: node
    secrets: inherit
```

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `language` | required | `python` or `node` |
| `working-directory` | `.` | monorepo subfolder |
| `package-manager` | `npm` | `npm`, `pnpm`, `yarn` |
| `lint-command` / `test-command` / `build-command` | org default | escape hatches |
| `docker-enabled`, `dockerfile`, `docker-context` | `false`, `Dockerfile`, `.` | image build (push only on main/tags) |
| `deploy-enabled`, `deploy-command` | `false`, `./scripts/deploy.sh` | staging on `main`, production on `v*` tags |
| `required-labels-any`, `allowed-base-branches`, `branch-pattern`, `title-pattern`, `require-reviewer` | see workflow | PR contract |

## Secrets and variables

- Optional secrets: `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `SLACK_WEBHOOK_URL` (org level, selected repos).
- Cloud auth uses OIDC. Set environment variables `DEPLOY_ROLE_ARN` and `AWS_REGION` per environment. Swap the auth step for Azure or GCP if needed.

## Versioning

Semver tags plus a floating `vN`. Callers use `@v1`, or a full SHA for regulated repos. Breaking input changes need a new major. `selftest.yml` exercises the workflow against `fixtures/` on every PR.

## Required status check names

`pipeline / pr-contract / run` and `pipeline / ci / run` (caller job id `pipeline`, orchestrator job id, then the stage's `run` job). If you rename the caller job, update `policy/ruleset.json`. Confirm the exact names in the checks list of the first real PR before switching the ruleset from `evaluate` to `active`.

## Layout

| File | Role |
|---|---|
| `ci-cd.yml` | Orchestrator, the only entrypoint callers reference |
| `pr-contract.yml` | Blocking: title, branch, base, labels, description, reviewer |
| `pr-advisory.yml` | Non-blocking PR guidance and dependency review |
| `ci.yml` | Lint, test, build for Python or Node |
| `docker.yml` | Buildx build, push (non-PR only), Trivy scan, outputs digest |
| `deploy.yml` | Environment-gated OIDC deploy (`staging` on main, `production` on tags) |
| `selftest.yml`, `release.yml` | Repo's own tests and tagging |

Stage workflows can also be called directly, e.g. `uses: your-org/platform-workflows/.github/workflows/ci.yml@v1`, for repos that only want part of the pipeline.

## Notes

- Action versions are illustrative. Pin third-party actions to commit SHAs before production use.
- Reusable workflow permissions are capped by the caller's `permissions:` block, which is why the caller templates grant them.
