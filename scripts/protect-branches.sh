#!/usr/bin/env bash
# Lo ejecuta P1 UNA vez, después de crear el repo y las ramas main y develop.
# Requiere: gh auth login  (con permisos de admin sobre el repo)
# Uso: ./scripts/protect-branches.sh <owner>/<repo>
# Nota: branch protection en repos PRIVADOS requiere plan de pago de GitHub; en repos públicos es gratis.
set -euo pipefail

REPO="${1:?Uso: $0 <owner>/<repo>}"

# Solo squash merge + borrar ramas al mergear
gh api -X PATCH "repos/${REPO}" \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true >/dev/null

for BRANCH in main develop; do
  echo ">> protegiendo ${BRANCH}"
  gh api -X PUT "repos/${REPO}/branches/${BRANCH}/protection" --input - >/dev/null <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["fmt", "validate (dev)", "validate (qa)", "validate (prod)"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "required_conversation_resolution": true
}
JSON
done

echo "OK: main y develop protegidas (PR + 1 aprobación + CI)."
