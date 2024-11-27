#!/bin/bash

set -e

# Debugging information
echo "Current working directory: $(pwd)"
echo "Contents of workspace:"
ls -al

set -e

# Get inputs
GITHUB_TOKEN=$1
CHANGED_FILES=$2

# Validate inputs
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN is not set."
  exit 1
fi

if [ -z "$CHANGED_FILES" ]; then
  echo "No changed files provided."
  exit 0
fi

# Analyze files with Ollama CodeGemma
RESULTS=""
while IFS= read -r FILE; do
  echo "Analyzing $FILE..."
  if [ -f "$FILE" ]; then
    OUTPUT=$(ollama codegemma --file "$FILE" || echo "Error processing $FILE")
    RESULTS="$RESULTS\n### Recommendations for $FILE\n$OUTPUT\n"
  else
    echo "File $FILE does not exist. Skipping."
  fi
done <<< "$CHANGED_FILES"

# Exit if no results
if [ -z "$RESULTS" ]; then
  echo "No recommendations generated."
  exit 0
fi

# Create a GitHub issue with recommendations
ISSUE_TITLE="Ollama CodeGemma Recommendations"
ISSUE_BODY="## Recommendations\n\n${RESULTS}"

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
