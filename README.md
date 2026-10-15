# platform-workflows

Org-wide reusable CI/CD for Python and Node.js repos: PR contract, PR advisory, workflow linting, code lint/test/build, Docker, environment-gated deploy.

## Publish (one time)

Create an **internal** repository in your organization, push this repository to it, and allow organization repositories to access its workflows in the repository's Actions settings. Push the `v1.0.0` tag to trigger `release.yml`, which moves the floating `v1` tag.

Then: create the teams `platform-team` and `security`, set the production reviewer team id in `policy/env-production.json`, and apply `policy/ruleset.json` (starts in `evaluate` mode).

## Use it in a repo

Copy `callers/node.yml` or `callers/python.yml` to `.github/workflows/ci-cd.yml` to run CI and Docker builds. Deployment is disabled in the templates; to enable it, set `deploy-enabled: true` and provide a repository-specific `deploy-command`. For CI-only checks, call `ci.yml` directly as shown below.

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
| `deploy-enabled`, `deploy-command` | `false`, empty | Deploy on `main` to staging or on `v*` tags to production; set a repository-specific command |
| `required-labels-any`, `allowed-base-branches`, `branch-pattern`, `title-pattern`, `require-reviewer` | see workflow | PR contract |

In CI, test failures emit a warning and the build still runs; lint and build failures remain blocking.

## Secrets and variables

- Optional secrets: `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `SLACK_WEBHOOK_URL` (org level, selected repos).
- Cloud auth uses OIDC. Set environment variables `DEPLOY_ROLE_ARN` and `AWS_REGION` per environment. Swap the auth step for Azure or GCP if needed.

## Deploy frontend and backend separately

Use `deploy-backend.yml` or `deploy-frontend.yml` as separate reusable workflow calls. Both accept `environment`, `runner_label`, and an optional `image_tag`; backend deployment also requires `aws_secret_id`, `image_name_backend`, `frontend_origin`, and `backend_port`; frontend deployment requires `image_name_frontend`, `api_url`, and `frontend_port`.

```yaml
jobs:
  deploy-backend:
    uses: your-org/platform-workflows/.github/workflows/deploy-backend.yml@v1
    with:
      environment: dev
      runner_label: dev-linux
      aws_secret_id: repob/dev
      image_name_backend: repob-backend
      frontend_origin: https://dev.repob.example.com
      backend_port: 8000

  deploy-frontend:
    uses: your-org/platform-workflows/.github/workflows/deploy-frontend.yml@v1
    with:
      environment: dev
      runner_label: dev-linux
      image_name_frontend: repob-frontend
      api_url: https://dev-api.repob.example.com
      frontend_port: 3000
```

Call either job on its own to deploy only that service. The existing `deploy-services.yml` remains available for deploying both services together.

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
| `ci.yml` | Lint GitHub Actions workflows; lint, test, and build Python or Node code |
| `docker.yml` | Buildx build, push (non-PR only), Trivy scan, outputs digest |
| `deploy.yml` | Environment-gated OIDC deploy (`staging` on main, `production` on tags) |
| `deploy-backend.yml`, `deploy-frontend.yml` | Deploy backend or frontend independently |
| `deploy-services.yml` | Deploy backend and frontend together |
| `selftest.yml`, `release.yml` | Repo's own tests and tagging |

Stage workflows can also be called directly, e.g. `uses: your-org/platform-workflows/.github/workflows/ci.yml@v1`, for repos that only want part of the pipeline.

## Notes

- Action versions are illustrative. Pin third-party actions to commit SHAs before production use.
- Reusable workflow permissions are capped by the caller's `permissions:` block, which is why the caller templates grant them.
