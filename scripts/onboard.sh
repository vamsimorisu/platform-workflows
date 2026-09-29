#!/usr/bin/env bash
# Add the caller workflow, environments and secret access to an existing repo.
# usage: ORG=acme ./scripts/onboard.sh <repo> <node|python>
set -euo pipefail
: "${ORG:?set ORG=<your-github-org>}"
REPO=${1:?repo}; LANG=${2:?node|python}
BRANCH=ci/adopt-org-pipeline
HERE="$(cd "$(dirname "$0")/.." && pwd)"

BASE=$(gh api "repos/$ORG/$REPO" --jq .default_branch)
SHA=$(gh api "repos/$ORG/$REPO/git/ref/heads/$BASE" --jq .object.sha)
gh api -X POST "repos/$ORG/$REPO/git/refs" -f ref="refs/heads/$BRANCH" -f sha="$SHA"

CONTENT=$(sed "s/__ORG__/$ORG/g" "$HERE/callers/$LANG.yml" | base64 | tr -d '\n')
gh api -X PUT "repos/$ORG/$REPO/contents/.github/workflows/ci-cd.yml" \
  -f message="ci: adopt org CI/CD pipeline" -f content="$CONTENT" -f branch="$BRANCH"

gh pr create -R "$ORG/$REPO" --head "$BRANCH" --base "$BASE" --label chore \
  --title "ci: adopt org CI/CD pipeline" \
  --body "Adds the standard caller workflow (see platform-workflows README)."

# environments (edit the reviewer team id in policy/env-production.json first)
for ENVN in staging production; do
  gh api -X PUT "repos/$ORG/$REPO/environments/$ENVN" --input "$HERE/policy/env-$ENVN.json"
done

# grant access to selected org-level secrets
REPO_ID=$(gh api "repos/$ORG/$REPO" --jq .id)
for S in SLACK_WEBHOOK_URL; do
  gh api -X PUT "/orgs/$ORG/actions/secrets/$S/repositories/$REPO_ID" || true
done
echo "Set per-environment variables: gh variable set DEPLOY_ROLE_ARN --env production -R $ORG/$REPO --body <arn>"
