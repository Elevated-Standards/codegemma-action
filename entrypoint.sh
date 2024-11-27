#!/bin/bash

set -e

# Get inputs
GITHUB_TOKEN=$1
GITHUB_REPOSITORY=$(jq -r '.repository.full_name' < "${GITHUB_EVENT_PATH}")
PR_NUMBER=$(jq -r '.pull_request.number' < "${GITHUB_EVENT_PATH}")
PR_URL=$(jq -r '.pull_request.html_url' < "${GITHUB_EVENT_PATH}")

# Get changed files in the PR
CHANGED_FILES=$(git diff --name-only "${GITHUB_SHA}"^)

# Analyze files with Ollama CodeGemma
RESULTS=""
for FILE in $CHANGED_FILES; do
  echo "Analyzing $FILE..."
  OUTPUT=$(ollama codegemma --file "$FILE" || echo "Error processing $FILE")
  RESULTS="$RESULTS\n### Recommendations for $FILE\n$OUTPUT\n"
done

# Create a GitHub issue with recommendations
ISSUE_TITLE="Ollama CodeGemma Recommendations for PR #${PR_NUMBER}"
ISSUE_BODY="## Recommendations\n\n${RESULTS}\n\n### Pull Request Link\n[View Pull Request](${PR_URL})"

EXISTING_ISSUE=$(curl -s \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues" | \
  jq -r ".[] | select(.title == \"$ISSUE_TITLE\") | .number")

if [ -z "$EXISTING_ISSUE" ]; then
  curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -d "$(jq -n --arg title "$ISSUE_TITLE" --arg body "$ISSUE_BODY" '{title: $title, body: $body, labels: ["ollama-codegemma"]}')" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues"
  echo "Created new issue: $ISSUE_TITLE"
else
  echo "Issue already exists: $EXISTING_ISSUE"
fi
