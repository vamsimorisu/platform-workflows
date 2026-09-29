#!/usr/bin/env bash
# Publish this repo to a GitHub org and make it callable org-wide.
# usage: ORG=acme ./scripts/bootstrap.sh
# needs: gh CLI authenticated with admin rights on the org
set -euo pipefail
: "${ORG:?set ORG=<your-github-org>}"
REPO=platform-workflows
cd "$(dirname "$0")/.."

# 1. replace the __ORG__ placeholder everywhere
grep -rl '__ORG__' --exclude-dir=.git . | xargs -r sed -i "s/__ORG__/$ORG/g"

# 2. commit
git add -A
git -c user.name="${GIT_AUTHOR_NAME:-platform}" -c user.email="${GIT_AUTHOR_EMAIL:-platform@$ORG.invalid}" \
  commit -q -m "feat: initial org CI/CD reusable workflows" || true

# 3. create repo (internal visibility) and push
gh repo create "$ORG/$REPO" --internal --source=. --remote=origin --push

# 4. allow every repo in the org to call the workflows
gh api -X PUT "repos/$ORG/$REPO/actions/permissions/access" -f access_level=organization

# 5. first release: the v1.0.0 tag triggers release.yml, which moves the floating v1 tag
git tag v1.0.0
git push origin v1.0.0

echo "Done. Callers can now use: $ORG/$REPO/.github/workflows/ci-cd.yml@v1"
echo "Next: create teams @$ORG/platform-team and @$ORG/security, then apply policy/ruleset.json."
