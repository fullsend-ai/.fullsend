#!/usr/bin/env bash
# setup-prioritize.sh — Create RICE fields on the org's GitHub Project V2 board.
#
# One-off setup script. Idempotent — safe to re-run.
# In the future, this will be invoked by the repo maintenance job
# (https://github.com/fullsend-ai/fullsend/issues/583).
#
# Required env vars:
#   GH_TOKEN       — GitHub token with project admin scope
#   ORG            — GitHub organization (e.g., fullsend-ai)
#   PROJECT_NUMBER — Project board number (e.g., 1)

set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN must be set}"
: "${ORG:?ORG must be set}"
: "${PROJECT_NUMBER:?PROJECT_NUMBER must be set}"

# Resolve the project node ID.
PROJECT_ID=$(gh project view "${PROJECT_NUMBER}" --owner "${ORG}" --format json | jq -r '.id')
if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "null" ]]; then
  echo "ERROR: could not resolve project ${PROJECT_NUMBER} for org ${ORG}"
  exit 1
fi
echo "Project ID: ${PROJECT_ID}"

# Get existing fields.
EXISTING_FIELDS=$(gh project field-list "${PROJECT_NUMBER}" --owner "${ORG}" --format json | jq -r '.fields[].name')

# Create number fields if they don't already exist.
for field_name in "RICE Reach" "RICE Impact" "RICE Confidence" "RICE Effort" "RICE Score"; do
  if echo "${EXISTING_FIELDS}" | grep -qx "${field_name}"; then
    echo "Field '${field_name}' already exists — skipping."
  else
    echo "Creating field '${field_name}'..."
    gh api graphql -f query='
      mutation($projectId: ID!, $name: String!) {
        createProjectV2Field(input: {
          projectId: $projectId
          dataType: NUMBER
          name: $name
        }) {
          projectV2Field { id name }
        }
      }
    ' -f projectId="${PROJECT_ID}" -f name="${field_name}"
    echo "Created '${field_name}'."
  fi
done

echo "Setup complete."
